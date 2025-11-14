#!/bin/bash

script_path=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
source "${script_path}/nfcore-modules.sh"
source "${script_path}/nfcore-env/bin/activate"
export RNASEQ_SCRIPTS="$script_path"
