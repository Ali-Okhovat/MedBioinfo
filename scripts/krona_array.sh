#!/bin/bash
#SBATCH -A naiss2024-22-540
#SBATCH --ntasks=1                              # number of tasks to be run in parallel (usually 1), this task can be multithreaded (see cpus-per-task)
#SBATCH --nodes=1                               # number of nodes to reserve for each task (usually 1)
#SBATCH --cpus-per-task=2                       # number of CPU cores to reserve for each task /!\ job killed if commands below use more cores
#SBATCH --mem=96GB                              # amount of RAM to reserve for the tasks /!\ job killed if commands below use more RAM
#SBATCH --time=0-0:10                           # maximal wall clock duration (D-HH:MM) /!\ job killed if commands below take more time than reservation
#SBATCH -o ./outputs/slurm.%A.%a.out            # standard output (STDOUT) redirected to these files (with Job ID and array ID in file names)
#SBATCH -e ./outputs/slurm.%A.%a.err            # standard error (STDERR) redirected to these files (with Job ID and array ID in file names)
#SBATCH --array=1-12                            # 1-N: clone this script in an array of N tasks: $SLURM_ARRAY_TASK_ID will take the value of 1,2,...,N
#SBATCH --mail-type=BEGIN,END,FAIL              # when to send an email notification (END = when the whole sbatch array is finished)
#SBATCH --mail-user ali.okhovat@ki.se

#################################################################
# Preparing work (cd to working dir, get hold of input data, convert/un-compress input data when needed etc.)
# Define paths
wd='/proj/applied_bioinformatics/users/x_aliok/MedBioinfo/analyses/kraken2'
result_dir='/proj/applied_bioinformatics/users/x_aliok/MedBioinfo/analyses/krona'
accnum_file='/proj/applied_bioinformatics/users/x_aliok/MedBioinfo/analyses/x_aliok_run_accessions.txt'

echo START: `date`

# Go to working directory
cd $wd || { echo "Failed to change directory to $wd"; exit 1; }

# Make needed directories
mkdir -p $result_dir

# This extracts the item number $SLURM_ARRAY_TASK_ID from the file of accnums
accnum=$(sed -n "${SLURM_ARRAY_TASK_ID}p" ${accnum_file})
input_file_pattern="${wd}/kraken2/kraken2.*.${accnum}.report"

# Ensure input files exist
input_file=$(ls $input_file_pattern 2>/dev/null)
if [[ -z $input_file ]]; then
    echo "Input files for $accnum not found!"
    exit 1
fi

# Each output file needs to be unique by post-fixing with $SLURM_ARRAY_TASK_ID and/or $accnum
krona_file="${result_dir}/krona.${SLURM_ARRAY_TASK_ID}.${accnum}.krona"
krona_html_file="${result_dir}/krona.${SLURM_ARRAY_TASK_ID}.${accnum}.krona.html"

#################################################################
# Start work

srun --job-name="krona_${accnum}" /proj/applied_bioinformatics/tools/KrakenTools/kreport2krona.py \
    -r $input_file \
    -o $krona_file

# Check if krona completed successfully
if [ $? -ne 0 ]; then
    echo "krona failed for $accnum"
    exit 1
fi

# Correct sed command to remove prefixes
sed -i 's/\(k__\|p__\|o__\|f__\|g__\|s__\)//g' $krona_file

srun --job-name="krona_html_${accnum}" singularity exec -B /proj:/proj \
    /proj/applied_bioinformatics/common_data/kraken2.sif ktImportText \
    $krona_file \
    -o $krona_html_file

#################################################################
echo END: `date`
