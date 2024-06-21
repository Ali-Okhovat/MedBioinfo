#!/bin/bash -l

#SBATCH -A naiss2024-22-540
#SBATCH -n 4
#SBATCH -t 01:00:00
#SBATCH -J blastp
#SBATCH -o blastp.%j.out
#SBATCH -e blastp.%j.err
#SBATCH --mail-user ali.okhovat@ki.se
#SBATCH --mail-type=BEGIN,END,FAIL,TIME_LIMIT_80

cat $0 #copy code to output

# Which node?
echo "Hello from" $HOSTNAME
date

# Define paths
db='/proj/applied_bioinformatics/common_data/proteomes'
exex='/proj/applied_bioinformatics/tools/ncbi-blast-2.15.0+-src'
fasta='/proj/applied_bioinformatics/users/x_aliok/blastp/fasta'
results='/proj/applied_bioinformatics/users/x_aliok/blastp/results'

# Run blastp
for i in $(ls $fasta); do

    name=$(basename "$i" .fasta)

    srun -n 1 --cpu_bind=cores $exex/blastp -num_threads 1 -query $fasta/$i -db $db/UP000000589 -out $results/${name}.UP000000589.blastp.out &
    sleep 15
    srun -n 1 --cpu_bind=cores $exex/blastp -num_threads 1 -query $fasta/$i -db $db/UP000000625 -out $results/${name}.UP000000625.blastp.out &
    sleep 15
    srun -n 1 --cpu_bind=cores $exex/blastp -num_threads 1 -query $fasta/$i -db $db/UP000000803 -out $results/${name}.UP000000803.blastp.out &
    sleep 15
    srun -n 1 --cpu_bind=cores $exex/blastp -num_threads 1 -query $fasta/$i -db $db/UP000006548 -out $results/${name}.UP000006548.blastp.out &

    wait

done

date
