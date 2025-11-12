#!/bin/bash

script_path=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
cd "$script_path" || { echo "Folder $script_path does not exists"; exit 1; }
source nfcore-modules.sh
source nfcore-env/bin/activate
export RNASEQ_SCRIPTS="$script_path"
