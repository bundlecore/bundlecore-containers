#!/bin/bash

# Script to create folders for each tool in the bfx directory
# This is used when onboarding new tools to ensure each has its own folder to store lua files and release.json

tools_list="plink2 gatk4 strelka2 busco falco fastqc macs3 snpeff phyml minfi samtools mafft deseq2 kallisto star bedtools bcftools bwa-mem2 scanpy-scripts sopa bowtie2 deepvariant"
for tool in $tools_list
do
    echo "Making folder for $tool"
    if [ -d "bfx/$tool" ]; then
        echo "Folder bfx/$tool already exists, skipping."
    else
        mkdir -p bfx/$tool
    fi
done
