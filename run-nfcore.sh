#!/bin/bash

script_path=$(dirname "$(readlink -f "$0")")
source "${script_path}/nfcore-init.sh"
source "${script_path}/nfcore-env/bin/activate"

nextflow run "${script_path}/nf-core-rnaseq_3.19.0/3_19_0/" \
    "$@"
