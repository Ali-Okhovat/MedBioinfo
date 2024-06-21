#!/bin/bash
#SBATCH -A naiss2024-22-540
#SBATCH --ntasks=1                              # nb of *tasks* to be run in // (usually 1), this task can be multithreaded (see cpus-per-task)
#SBATCH --nodes=1                               # nb of nodes to reserve for each task (usually 1)
#SBATCH --cpus-per-task=2                       # nb of cpu (in fact cores) to reserve for each task /!\ job killed if commands below use more cores
#SBATCH --mem=96GB                              # amount of RAM to reserve for the tasks /!\ job killed if commands below use more RAM
#SBATCH --time=0-01:00                          # maximal wall clock duration (D-HH:MM) /!\ job killed if commands below take more time than reservation
#SBATCH -o ./outputs/slurm.%A.%a.out            # standard output (STDOUT) redirected to these files (with Job ID and array ID in file names)
#SBATCH -e ./outputs/slurm.%A.%a.err            # standard error  (STDERR) redirected to these files (with Job ID and array ID in file names)
#SBATCH --array=1-3                             # 1-N: clone this script in an array of N tasks: $SLURM_ARRAY_TASK_ID will take the value of 1,2,...,N
#SBATCH --job-name=MedBioinfo                   # name of the task as displayed in squeue & sacc, also encouraged as srun optional parameter
#SBATCH --mail-type=BEGIN,END                   # when to send an email notiification (END = when the whole sbatch array is finished)
#SBATCH --mail-user ali.okhovat@ki.se

#################################################################
# Preparing work (cd to working dir, get hold of input data, convert/un-compress input data when needed etc.)
workdir="/proj/applied_bioinformatics/users/x_aliok/MedBioinfo/analyses"
datadir="/proj/applied_bioinformatics/users/x_aliok/MedBioinfo/data/merged_pairs"
accnum_file="/proj/applied_bioinformatics/users/x_aliok/MedBioinfo/analyses/file_of_acc_nums.txt"

echo START: `date`

cd ${workdir}

# this extracts the item number $SLURM_ARRAY_TASK_ID from the file of accnums
accnum=$(sed -n "$SLURM_ARRAY_TASK_ID"p ${accnum_file})
input_file="${datadir}/${accnum}.fa"
# alternatively, just extract the input file as the item number $SLURM_ARRAY_TASK_ID in the data dir listing
# this alternative is less handy since we don't get hold of the isolated "accnum", which is very handy to name the srun step below :)
# input_file=$(ls "${datadir}/*.fastq.gz" | sed -n ${SLURM_ARRAY_TASK_ID}p)

# if the command below can't cope with compressed input
srun gunzip "${input_file}.gz"

# because there are mutliple jobs running in // each output file needs to be made unique by post-fixing with $SLURM_ARRAY_TASK_ID and/or $accnum
output_file="${workdir}/blastn.${SLURM_ARRAY_TASK_ID}.${accnum}.out"

#################################################################
# Start work
srun --job-name=${accnum} /proj/applied_bioinformatics/tools/ncbi-blast-2.15.0+-src/blastn -num_threads ${SLURM_CPUS_PER_TASK} \
-db /proj/applied_bioinformatics/users/x_aliok/MedBioinfo/data/blast_db/refseq_viral_genomic \
-query ${input_file} \
-out ${output_file} \
-outfmt 6
#################################################################
echo END: `date`
