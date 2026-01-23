#!/usr/bin/env python3

import argparse
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
    parser.add_argument("-b", "--bam", nargs="+", type=argparse.FileType('r'),
                        help="BAM files")
    parser.add_argument("-o", "--output", type=argparse.FileType('w'), default=stdout,
                        help="Tab delimited file containing multiple scale factor options  (default: standard output)")
    parser.add_argument("-s", "--spike_fasta", type=argparse.FileType('r'), default=None,
                        help="FASTA file containing spike-in genome")
    parser.add_argument("-l", "--labels", nargs="*", default=None,
                        help="Labels to use instead of BAM filename in BAM output column")
    parser.add_argument("--samplesheet", type=argparse.FileType('r'), default=None,
                        help="Sample sheet file where sample names will be used as labels")
    parser.add_argument("-S", "--scale", type=int, default=BASE_SCALE,
                        help="Base scale to use to compute scale factors  (default: %(default)s)")
    parser.add_argument("-m", "--mean", action="store_true",
                        help="Divide scale factors by the mean of all scale factors  (default: false)")

    args = parser.parse_args(argv)

    if not args.labels and args.samplesheet:
        args.labels = samplesheet_to_labels(args.samplesheet)

    labels = bam_labels(bam_files=args.bam, labels=args.labels)
    scale_factors(bam_files=args.bam, output_file=args.output, spike_fasta_file=args.spike_fasta,
                  labels=labels, scale=args.scale, mean=args.mean)


def samplesheet_to_labels(samplesheet_file: TextIO) -> list[str]:
    """
    Returns a list of BAM file labels based on sample sheet file.

    :param samplesheet_file: sample sheet file
    :return: list of BAM file labels based on sample sheet file
    """
    labels = []
    if samplesheet_file.name.endswith(".csv"):
        headers = samplesheet_file.readline().rstrip("\r\n").split(",")
        headers = [header.strip("\"") for header in headers]
        replicate_index = headers.index("replicate") if "replicate" in headers else 0
        for line in samplesheet_file:
            columns = line.rstrip("\r\n").split(",")
            columns = [column.strip("\"") for column in columns]
            label = columns[0]
            if replicate_index:
                # Assume chipseq nf-core pipeline.
                label=f"{label}_REP{columns[replicate_index]}"
            labels.append(label)
    elif samplesheet_file.name.endswith(".txt") or samplesheet_file.name.endswith(".tsv"):
        for line in samplesheet_file:
            if line.startswith("#"):
                continue # Skip header.
            columns = line.rstrip("\r\n").split("\t")
            labels.append(columns[0])
    else:
        print(f"Warning: sample sheet file format {samplesheet_file.name} not supported", file=stderr)
    return labels


def bam_labels(bam_files: list[TextIO], labels: list[str]) -> dict[str, str]:
    """
    Finds label for each BAM file.

    :param bam_files: BAM files
    :param labels: Labels to use instead of BAM filename in BAM output column
    :return: Dictionary of labels mapped by BAM filename
    """
    bam_filenames = [bam_file.name for bam_file in bam_files]

    labels_by_filename = {}
    for label in labels:
        bam_filenames_with_label = [bam_filename for bam_filename in bam_filenames if label in bam_filename]
        if not bam_filenames_with_label:
            print(f"Warning: label {label} not found in any BAM filenames", file=stderr)
        elif len(bam_filenames_with_label) == 1:
            labels_by_filename[bam_filenames_with_label[0]] = label
        else:
            print(f"Warning: label {label} found multiple BAM filenames ({bam_filenames_with_label})", file=stderr)
            for filename in bam_filenames_with_label:
                labels_by_filename[filename] = label
    for bam_filename in bam_filenames:
        if bam_filename not in labels_by_filename:
            print(f"Warning: BAM file {bam_filename} does not have a label", file=stderr)
    return labels_by_filename


def scale_factors(bam_files: list[TextIO], output_file: TextIO, spike_fasta_file: TextIO, labels: dict[str, str],
    scale: int = BASE_SCALE, mean: bool = False):
    """
    Compute scale factors based on reads aligning to main genome and spike-in genome.

    :param bam_files: BAM files
    :param output_file: Tab delimited file containing multiple scale factor options
    :param spike_fasta_file: FASTA file containing spike-in genome
    :param labels: Labels to use instead of BAM filename in BAM output column
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
    for i in range(0, len(bam_files)):
        bam_file = bam_files[i]
        align = pysam.AlignmentFile(bam_file, "rb")
        read_filter = lambda read : (((read.is_paired and read.is_proper_pair) or not read.is_paired)
                                     and not read.is_qcfail and not read.is_secondary and not read.is_supplementary)
        read_count = align.count(read_callback=read_filter)
        spike_read_count = 0
        for chromosome in spike_chromosomes:
            try:
                spike_read_count += align.count(contig=chromosome, read_callback=read_filter)
            except ValueError:
                print(f"Warning: BAM file {bam_file.name} does not contain chromosome {chromosome} "
                      f"from spike-in FASTA", file=stderr)
        read_count -= spike_read_count
        label = labels[bam_file.name] if bam_file.name in labels else bam_file.name
        bam_scales[bam_file.name] = BamScale(label, read_count, scale/read_count if read_count else None)
        if spike_fasta_file:
            bam_scales[bam_file.name].set_spike_scale(spike_read_count,
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
