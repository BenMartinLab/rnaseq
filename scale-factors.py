#!/usr/bin/env python3

import argparse
import os.path
import re
import statistics
from sys import stdout, stderr
from typing import TextIO

import pysam


class BamScale:
    def __init__(self, label: str, read_count: int, scale_factor: float):
        self.label = label
        self.read_count = read_count
        self.scale_factor = scale_factor
        self.spike_read_count = 0
        self.spike_scale_factor = None

    def set_spike_scale(self, spike_read_count: int, spike_scale_factor: float):
        self.spike_read_count = spike_read_count
        self.spike_scale_factor = spike_scale_factor


BASE_SCALE = 1000000


def main(argv: list[str] = None):
    parser = argparse.ArgumentParser(description="Compute scale factors based on reads aligning to "
                                                 "main genome and spike-in genome.")
    parser.add_argument("--samplesheet", type=argparse.FileType('r'), default=None,
                        help="Sample sheet file where sample names will be used as labels")
    parser.add_argument("-o", "--output", type=argparse.FileType('w'), default=stdout,
                        help="Tab delimited file containing multiple scale factor options  (default: standard output)")
    parser.add_argument("-b", "--bam", default="output/star_salmon",
                        help="Folder where BAM files are located  (default: %(default)s)")
    parser.add_argument("-s", "--spike_fasta", type=argparse.FileType('r'), default=None,
                        help="FASTA file containing spike-in genome")
    parser.add_argument("-S", "--scale", type=int, default=BASE_SCALE,
                        help="Base scale to use to compute scale factors  (default: %(default)s)")
    parser.add_argument("-m", "--mean", action="store_true",
                        help="Divide scale factors by the mean of all scale factors  (default: false)")

    args = parser.parse_args(argv)

    bam_files = get_bam_files(args.samplesheet, args.bam)
    scale_factors(bam_files=bam_files, output_file=args.output, spike_fasta_file=args.spike_fasta,
                  scale=args.scale, mean=args.mean)


def get_bam_files(samplesheet_file: TextIO, bam_folder: str = "output/star_salmon") -> dict[str, str]:
    """
    Finds BAM file associated with each sample.

    :param samplesheet_file: sample sheet file
    :param bam_folder: folder where BAM files are located
    :return: list of BAM file associated with each sample
    """
    bam_files = {}
    headers = samplesheet_file.readline().rstrip("\r\n").split(",")
    headers = [header.strip("\"") for header in headers]
    replicate_index = headers.index("replicate") if "replicate" in headers else 0
    for line in samplesheet_file:
        columns = line.rstrip("\r\n").split(",")
        columns = [column.strip("\"") for column in columns]
        sample = columns[0]
        if replicate_index:
            # Assume chipseq nf-core pipeline.
            sample=f"{sample}_REP{columns[replicate_index]}"
        bam_file = os.path.join(bam_folder, sample + ".umi_dedup.sorted.bam")
        if not os.path.exists(bam_file):
            bam_file = os.path.join(bam_folder, sample + ".markdup.sorted.bam")
        if not os.path.exists(bam_file):
            print(f"Error: no BAM file could be found in folder {bam_folder} for sample {sample}", file=stderr)
            exit(1)
        bam_files[sample] = bam_file
    return bam_files


def scale_factors(bam_files: dict[str, str], output_file: TextIO, spike_fasta_file: TextIO,
    scale: int = BASE_SCALE, mean: bool = False):
    """
    Compute scale factors based on reads aligning to main genome and spike-in genome.

    :param bam_files: BAM files associated with each sample
    :param output_file: Tab delimited file containing multiple scale factor options
    :param spike_fasta_file: FASTA file containing spike-in genome
    :param scale: Base scale to use to compute scale factors
    :param mean: Divide scale factors by the mean of all scale factors
    """
    spike_chromosomes = parse_chromosomes(spike_fasta_file) if spike_fasta_file else None

    # Header
    output_file.write(f"BAM\tMain genome reads count\t"
                      f"Sequencing depth scale factors - {scale:.2e} / main genome reads count")
    if spike_fasta_file:
        output_file.write(f"\tSpike-in reads count\tSpike-in scale factors - {scale:.2e} / spike-in reads count"
                          f"\tSpike-in reads ratio")
    output_file.write("\n")

    bam_scales = {}
    for sample in bam_files:
        bam_file = bam_files[sample]
        align = pysam.AlignmentFile(bam_file, "rb")
        read_filter = lambda read : (((read.is_paired and read.is_proper_pair) or not read.is_paired)
                                     and not read.is_qcfail and not read.is_secondary and not read.is_supplementary)
        read_count = align.count(read_callback=read_filter)
        spike_read_count = 0
        for chromosome in spike_chromosomes:
            try:
                spike_read_count += align.count(contig=chromosome, read_callback=read_filter)
            except ValueError:
                print(f"Warning: BAM file {bam_file} does not contain chromosome {chromosome} "
                      f"from spike-in FASTA", file=stderr)
        read_count -= spike_read_count
        bam_scales[sample] = BamScale(sample, read_count, scale/read_count if read_count else None)
        if spike_fasta_file:
            bam_scales[sample].set_spike_scale(spike_read_count,
                                                      scale/spike_read_count if spike_read_count else None)
    scale_factor_mean = statistics.mean(
        [bam_scale.scale_factor for bam_scale in bam_scales.values() if bam_scale.scale_factor])
    try:
        spike_scale_factor_mean = statistics.mean(
            [bam_scale.spike_scale_factor for bam_scale in bam_scales.values() if bam_scale.spike_scale_factor])
    except statistics.StatisticsError:
        spike_scale_factor_mean = 1.0
    for bam_scale in bam_scales.values():
        scale_factor = bam_scale.scale_factor
        if mean and scale_factor:
            scale_factor = scale_factor / scale_factor_mean
        output_file.write(f"{bam_scale.label}\t{bam_scale.read_count}\t{scale_factor if scale_factor else 'NA'}")
        if spike_fasta_file:
            spike_scale_factor = bam_scale.spike_scale_factor
            spike_reads_ratio = (bam_scale.spike_read_count/(bam_scale.spike_read_count+bam_scale.read_count)
                                 if bam_scale.spike_read_count and bam_scale.read_count else None)
            if mean and spike_scale_factor:
                spike_scale_factor = spike_scale_factor / spike_scale_factor_mean
            output_file.write(f"\t{bam_scale.spike_read_count}\t{spike_scale_factor if spike_scale_factor else 'NA'}"
                              f"\t{spike_reads_ratio if spike_reads_ratio else 'NA'}")
        output_file.write("\n")


def parse_chromosomes(fasta_file: TextIO) -> list[str]:
    """
    Parses chromosome names present in FASTA file.

    :param fasta_file: FASTA file
    :return: chromosome names present in FASTA file
    """
    chromosomes = []
    chromosome_regex = re.compile(r"^>(\S*)(\s?)(.*)")
    for line in fasta_file:
        match = chromosome_regex.match(line)
        if match:
            chromosome = match.group(1)
            chromosomes.append(chromosome)
    return chromosomes


if __name__ == '__main__':
    main()
