#!/bin/bash
#SBATCH -A naiss2024-22-540
#SBATCH --ntasks=1                              # number of tasks to be run in parallel (usually 1), this task can be multithreaded (see cpus-per-task)
#SBATCH --nodes=1                               # number of nodes to reserve for each task (usually 1)
#SBATCH --cpus-per-task=2                       # number of CPU cores to reserve for each task /!\ job killed if commands below use more cores
#SBATCH --mem=96GB                              # amount of RAM to reserve for the tasks /!\ job killed if commands below use more RAM
#SBATCH --time=0-0:20                           # maximal wall clock duration (D-HH:MM) /!\ job killed if commands below take more time than reservation
#SBATCH -o ./outputs/slurm.%A.%a.out            # standard output (STDOUT) redirected to these files (with Job ID and array ID in file names)
#SBATCH -e ./outputs/slurm.%A.%a.err            # standard error (STDERR) redirected to these files (with Job ID and array ID in file names)
#SBATCH --array=1-12                            # 1-N: clone this script in an array of N tasks: $SLURM_ARRAY_TASK_ID will take the value of 1,2,...,N
#SBATCH --mail-type=BEGIN,END,FAIL              # when to send an email notification (END = when the whole sbatch array is finished)
#SBATCH --mail-user ali.okhovat@ki.se

#################################################################
# Preparing work (cd to working dir, get hold of input data, convert/un-compress input data when needed etc.)
# Define paths
sra_fastq='/proj/applied_bioinformatics/users/x_aliok/MedBioinfo/data/sra_fastq'
result_dir='/proj/applied_bioinformatics/users/x_aliok/MedBioinfo/analyses/kraken2'
accnum_file='/proj/applied_bioinformatics/users/x_aliok/MedBioinfo/analyses/x_aliok_run_accessions.txt'

echo START: `date`

# Go to working directory
cd $sra_fastq || { echo "Failed to change directory to $sra_fastq"; exit 1; }

# Make needed directories
mkdir -p $result_dir/kraken2
mkdir -p $result_dir/bracken

# This extracts the item number $SLURM_ARRAY_TASK_ID from the file of accnums
accnum=$(sed -n "${SLURM_ARRAY_TASK_ID}p" ${accnum_file})
input_file_1="${sra_fastq}/${accnum}_1.fastq.gz"
input_file_2="${sra_fastq}/${accnum}_2.fastq.gz"

# Ensure input files exist
if [[ ! -f $input_file_1 || ! -f $input_file_2 ]]; then
    echo "Input files for $accnum not found!"
    exit 1
fi

# Each output file needs to be unique by post-fixing with $SLURM_ARRAY_TASK_ID and/or $accnum
kraken2_report_file="${result_dir}/kraken2/kraken2.${SLURM_ARRAY_TASK_ID}.${accnum}.report"
kraken2_out_file="${result_dir}/kraken2/kraken2.${SLURM_ARRAY_TASK_ID}.${accnum}.out"
bracken_report_file="${result_dir}/bracken/bracken.${SLURM_ARRAY_TASK_ID}.${accnum}.report"
bracken_out_file="${result_dir}/bracken/bracken.${SLURM_ARRAY_TASK_ID}.${accnum}.out"

#################################################################
# Start work
srun --job-name="kraken2_${accnum}" singularity exec -B /proj:/proj /proj/applied_bioinformatics/common_data/kraken2.sif \
    kraken2 --db /proj/applied_bioinformatics/common_data/kraken_database/ \
    --threads 1 \
    --gzip-compressed \
    --paired \
    $input_file_1 \
    $input_file_2 \
    --report $kraken2_report_file \
    --output $kraken2_out_file

# Check if kraken2 completed successfully
if [ $? -ne 0 ]; then
    echo "kraken2 failed for $accnum"
    exit 1
fi

srun --job-name="bracken_${accnum}" singularity exec -B /proj:/proj /proj/applied_bioinformatics/common_data/kraken2.sif \
    bracken -d /proj/applied_bioinformatics/common_data/kraken_database/ \
    -i $kraken2_report_file \
    -w $bracken_report_file \
    -o $bracken_out_file

#################################################################
echo END: `date`
