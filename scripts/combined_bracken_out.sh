#!/bin/bash -l

#SBATCH -A naiss2024-22-540
#SBATCH -n 1
#SBATCH -t 00:05:00
#SBATCH -J combined_bracken_out
#SBATCH -o ./outputs/combined_bracken.%j.out
#SBATCH -e ./outputs/combined_bracken.%j.err
#SBATCH --mail-user ali.okhovat@ki.se
#SBATCH --mail-type=BEGIN,END,FAIL,TIME_LIMIT_80

# Define paths
bracken_out_dir="/proj/applied_bioinformatics/users/x_aliok/MedBioinfo/analyses/kraken2/bracken" ## path to directory with bracken output files
accnum_file="/proj/applied_bioinformatics/users/x_aliok/MedBioinfo/analyses/x_aliok_run_accessions.txt" ## path to file with the list of accessions

# go to the directory with bracken output files
cd $bracken_out_dir

# rename all bracken output files to have the format {accession_number}.braken.out
cd $bracken_out_dir
for file in bracken.*.out; do
    if [[ $file =~ bracken\.([0-9]+)\.(ERR[0-9]+)\.out ]]; then
        new_name="${BASH_REMATCH[2]}.bracken.out"
        mv "$file" "$new_name"
    fi
done

# add header
echo -e "accession_number\tname\ttaxonomy_id\ttaxonomy_lvl\tkraken_assigned_reads\tadded_reads\tnew_est_reads\tfraction_total_reads" > ${bracken_out_dir}/combined_bracken.out
# append all files with column accession number (Out files should be: {accession_number}.braken.out)
srun xargs -I{} -a $accnum_file awk -v id={} 'NR > 1 {print id "\t" $0}' ${bracken_out_dir}/{}.bracken.out >> ${bracken_out_dir}/combined_bracken.out
