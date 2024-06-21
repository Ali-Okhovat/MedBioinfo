#!/bin/bash -l

#SBATCH -A naiss2024-22-540
#SBATCH -N 1
#SBATCH --mem=96GB
#SBATCH -t 00:30:00
#SBATCH -J kraken2
#SBATCH -o ./outputs/slurm.%j.out
#SBATCH -e ./outputs/slurm.%j.err
#SBATCH --mail-user ali.okhovat@ki.se
#SBATCH --mail-type=BEGIN,END,FAIL,TIME_LIMIT_80

# Define paths
sra_fastq='/proj/applied_bioinformatics/users/x_aliok/MedBioinfo/data/sra_fastq'
result_dir='/proj/applied_bioinformatics/users/x_aliok/MedBioinfo/analyses/kraken2'

# Go to working directory
cd $sra_fastq

# List of samples
sample_list=($(ls | grep "ERR" | sed 's/_.*//' | sort | uniq))

# Make needed directories
mkdir -p $result_dir/kraken2

# Run kraken2 on defined number of samples
# Define start and number of samples in {sample_list[@]:s:n} which retrieves n elements starting at index s
COUNTER=0
for i in ${sample_list[@]}
do

printf "\n  Working on: $i \n\n"

sample=$i

R1=${i}_1
R2=${i}_2

singularity exec -B /proj:/proj /proj/applied_bioinformatics/common_data/kraken2.sif \
    kraken2 --db /proj/applied_bioinformatics/common_data/kraken_database/ \
    --threads 1 \
    --gzip-compressed \
    --paired \
    $sra_fastq/$R1.fastq.gz \
    $sra_fastq/$R2.fastq.gz \
    --report $result_dir/kraken2/${sample}.kraken2.report \
    --output $result_dir/kraken2/${sample}.kraken2.out

COUNTER=$((COUNTER+1))

printf "\n  Done successfully! \n\n"

done

wait

printf "\n  Total number of $COUNTER samples are analysed with kraken2 and results are produced successfully! \n\n"
