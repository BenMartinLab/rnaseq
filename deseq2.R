library(GetoptLong)

VERSION = "0.1.0"

deseq <- "deseq2.dds.RData"
outdir <- '.'
experiment <- NULL
control <- NULL
spike_gtf <- NULL
spike_size_factors <- FALSE
pre_filtering <- FALSE
group_size <- 3
minimum_count <- 10

GetoptLong(
  "deseq=s", "File containing DESeq2 counts - output from RNA-seq nf-core pipeline",
  "outdir=s", "Output directory",
  "experiment=s", "Experimental condition or condition of interest",
  "control=s", "Control condition",
  "spike_gtf=s", "GTF of spike-in genome, if applicable - genes from spike-in will be removed from the analysis",
  "spike_size_factors!", "Use spike-in genes for size estimation - requires spike_gtf parameter",
  "pre_filtering!", "Pre-filter data by removing genes with low counts",
  "group_size=i", "Smallest sample group size, only used for pre-filtering",
  "minimum_count=i", "Minimum read count to keep gene, only used for pre-filtering"
)

stopifnot(!is.null(experiment), !is.null(control), !is.null(spike_gtf) || !spike_size_factors)


library(rtracklayer)
library(tidyr)
library(tibble)
library(dplyr)
library(DESeq2)
library(pheatmap)
library(RColorBrewer)
library(ggrepel)


#### Load DESeq2 object from nf-core pipeline ####
load(deseq)


#### Creation of metadata starting from the dds colData ####
condition_columns <- colnames(colData(dds))[-1]
condition_columns <- head(condition_columns, length(condition_columns) - 2)
replica_column <- colnames(colData(dds))[length(condition_columns) + 2]
metadata <- as.data.frame(colData(dds))
metadata <- metadata |>
  unite(condition, all_of(condition_columns), sep = "_")
colnames(metadata)[3] <- 'replica'
metadata <- DataFrame(
  sample = metadata$sample,
  condition = metadata$condition,
  replica = metadata$replica
)
rownames(metadata) <- colnames(counts(dds))
colData(dds) <- metadata


#### Check that sample names match in both files ####
stopifnot(all(colnames(dds$counts) %in% rownames(metadata)), all(colnames(dds$counts) == rownames(metadata)))


#### Creation of a new dds ####
dds  <- DESeqDataSet(dds, design = ~ condition)


#### Remove spike-in genes ####
if (!is.null(spike_gtf)) {
  dds_gene_count_before <- dim(dds)[1]
  spike_gtf_import <- import(spike_gtf)
  spike_df <- as.data.frame(spike_gtf_import)
  if (spike_size_factors) {
    spike_genes <- rownames(dds) %in% spike_df[["gene_id"]]
    dds <- estimateSizeFactors(dds, controlGenes=spike_genes)
  }
  dds <- dds[!(rownames(dds) %in% spike_df[["gene_id"]]), ]
  print(paste0("Removed ", dds_gene_count_before - dim(dds)[1], " spike-in genes from DESeq2 object"))
  print(paste0(dim(dds)[1], " genes left in DESeq2 object"))
}


#### Pre-filtering ####
if (pre_filtering) {
  # Select genes with a sum counts of at least 10 in required number of samples
  keep <- rowSums(counts(dds) >= minimum_count) >= group_size
  # Keep only the genes that pass the threshold
  dds <- dds[keep,]
}


#### Run the DESeq2 analysis ####
if (!spike_size_factors) {
  dds <- estimateSizeFactors(dds)
}
dds <- estimateDispersions(dds)
dds <- nbinomWaldTest(dds)
write.csv(colData(dds), file = paste0(outdir, "/deseq_samples.csv"))


#### Transform normalised counts for data visualisation ####
# A user can choose among vst and rlog. In this tutorial we will work with rlog transformed data.
rld <- rlog(dds, blind = TRUE)


#### Plot PCA ####
pca_plot <- plotPCA(rld, intgroup = "condition")
# Save the plot
ggsave(paste0(outdir, "/pca_plot.png"), plot = pca_plot, width = 6, height = 5, dpi = 300)


#### Plot sample to sample distance (hierarchical clustering) ####
# Extract the matrix of rlog-transformed counts from the rld object
sampleDists <- dist(t(assay(rld)))  # Calculate pairwise distances between samples using the dist() function with Euclidean distance as the default method. By transposing the matrix with t(), we ensure that samples become rows and genes become columns, so that the dist function computes pairwise distances between samples.
# Convert distances to a matrix
sampleDistMatrix <- as.matrix(sampleDists)
# Set the row and column names of the distance matrix
rownames(sampleDistMatrix) <- paste(rld$condition, rld$replica, sep = "_")
colnames(sampleDistMatrix) <- paste(rld$condition, rld$replica, sep = "_")
# Define a color palette for the heatmap
colors <- colorRampPalette(rev(brewer.pal(9, "Greens")))(255) # function from RColorBrewer package
# Create the heatmap
clustering_plot <- pheatmap(sampleDistMatrix,
                            clustering_distance_rows = sampleDists,
                            clustering_distance_cols = sampleDists,
                            col = colors,
                            fontsize_col = 8,
                            fontsize_row = 8)
# Save the plot
ggsave(paste0(outdir, "/clustering_plot.png"), plot = clustering_plot, width = 6, height = 5, dpi = 300)


#### Inspect the normalised counts ####
# Convert the normalised counts from the DESeq2 object to a tibble
normalised_counts <- as_tibble(counts(dds, normalized = TRUE))
# Add a column for gene names to the normalised counts tibble
normalised_counts$gene <- rownames(counts(dds))
# Relocate the gene column to the first position
normalised_counts <- normalised_counts %>%
  relocate(gene, .before = colnames(normalised_counts)[1])
# Save the normalised counts
write.csv(normalised_counts, file = paste0(outdir, "/normalised_counts.csv"))


#### Extract results table from the dds object ####
res <- results(dds)
# Summarise the results showing the number of tested genes (genes with non-zero total read count), the genes up- and down-regulated at the selected threshold (alpha) and the number of genes excluded by the multiple testing due to a low mean count
summary(res)
# DESeq2 function to extract the name of the contrast
resultsNames(dds)
# Command to set the contrast, if necessary
res <- results(dds, contrast = c("condition", experiment, control))
# Store the res object inside another variable because the original res file will be required for other functions
res_viz <- res
# Add gene names as a new column to the results table
res_viz$gene <- rownames(res)
# Convert the results to a tibble for easier manipulation and relocate the gene column to the first position
res_viz <- as_tibble(res_viz) %>%
  relocate(gene, .before = baseMean)
# Save the results table
write.csv(res_viz, file = paste0(outdir, "/", experiment, "_vs_", control, "_de_result_table.csv"))


#### Extract significant DE genes from the results ####
# Filter the results to include only significantly DE genes with a padj less than 0.05 and a log2FoldChange of at least 1 or -1
resSig <- subset(res_viz, padj < 0.05 & abs(log2FoldChange) > 1)
# Convert the results to a tibble for easier manipulation and relocate the gene column to the first position
resSig <- as_tibble(resSig) %>%
  relocate(gene, .before = baseMean)
# Order the significant genes by their adjusted p-value (padj) in ascending order
resSig <- resSig[order(resSig$padj),]
# Save the significant DE genes
write.csv(resSig, file = paste0(outdir, "/", experiment, "_vs_", control, "_sig_de_genes.csv"))


#### MA plot ####
# The MA plot is not a ggplot, so we have to save it in a different way
# Open a graphics device to save the plot as a PNG file
png(paste0(outdir, "/", experiment, "_vs_", control, "_MA_plot.png"), width = 1500, height = 1500, res = 300)
# Generate the MA plot (it will be saved to the file instead of displayed on screen)
plotMA(res, ylim = c(-2, 2))
# Close the device to save the file
dev.off()


#### Heatmap ####
# Extract only the first column (gene names) from the result object containing the significant genes
significant_genes <- resSig[, 1]
# Extract normalised counts for significant genes from the normalised counts matrix and convert the gene column to row names
significant_counts <- inner_join(normalised_counts, significant_genes, by = "gene") %>%
  column_to_rownames("gene")
# Create the heatmap using pheatmap
heatmap <- pheatmap(significant_counts,
                    cluster_rows = TRUE,
                    fontsize = 8,
                    scale = "row",
                    fontsize_row = 8,
                    height = 10)
# Save the plot
ggsave(paste0(outdir, "/", experiment, "_vs_", control, "_heatmap.png"), plot = heatmap, width = 6, height = 5, dpi = 300)


#### Volcano plot ####
# Convert the results to a tibble and add a column indicating differential expression status
res_tb <- as_tibble(res) %>%
  mutate(diffexpressed = case_when(
    log2FoldChange > 1 & padj < 0.05 ~ 'upregulated',
    log2FoldChange < -1 & padj < 0.05 ~ 'downregulated',
    TRUE ~ 'not_de'))
# Add a new column with gene names
res_tb$gene <- rownames(res)
# Relocate the gene column to the first position
res_tb <-  res_tb %>%
  relocate(gene, .before = baseMean)
# Order the table by padj and add a new column for gene labels
res_tb <- res_tb %>% arrange(padj) %>%
  mutate(genelabels = "")
# Label the top 5 most significant genes
res_tb$genelabels[1:5] <- res_tb$gene[1:5]
# Create a volcano plot using ggplot2
volcano_plot <- ggplot(data = res_tb, aes(x = log2FoldChange, y = -log10(padj), col = diffexpressed)) +
  geom_point(size = 0.6) +
  geom_text_repel(aes(label = genelabels), size = 2.5, max.overlaps = Inf) +
  ggtitle("DE genes treatment versus control") +
  geom_vline(xintercept = c(-1, 1), col = "black", linetype = 'dashed', linewidth = 0.2) +
  geom_hline(yintercept = -log10(0.05), col = "black", linetype = 'dashed', linewidth = 0.2) +
  theme(plot.title = element_text(size = rel(1.25), hjust = 0.5),
        axis.title = element_text(size = rel(1))) +
  scale_color_manual(values = c("upregulated" = "red",
                                "downregulated" = "blue",
                                "not_de" = "grey")) +
  labs(color = 'DE genes') +
  xlim(-3,5)
# Save the plot
ggsave(paste0(outdir, "/", experiment, "_vs_", control, "_volcano_plot.png"), plot = volcano_plot, width = 6, height = 5, dpi = 300)
