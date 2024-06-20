#!/bin/bash
echo "script start: download and initial sequencing read quality control"
date

# Load necessary modules
module load buildtool-easybuild/4.8.0-hpce082752a2 GCCcore/12.3.0 SQLite/3.42.0
module load R/4.2.2-hpc1-gcc-11.3.0-bare
module list


# Data setup
# check that the database is there
sqlite3 -batch /proj/applied_bioinformatics/common_data/sample_collab.db "select * from sample_annot limit 10;"
sqlite3 -batch /proj/applied_bioinformatics/common_data/sample_collab.db "select * from sample2bioinformatician;"
# order the LEFT JOIN by increasing username, this should show rows that have no user name assigned on top
sqlite3 -batch /proj/applied_bioinformatics/common_data/sample_collab.db "select * from sample_annot spl left join sample2bioinformatician s2b using(patient_code) order by username;"
# use four INSERT statements to associate your username with each patient_code (again you may use the above two staged approach to experiment with INSERT)
sqlite3 -batch /proj/applied_bioinformatics/common_data/sample_collab.db "insert into sample2bioinformatician values('x_aliok','P37');"  
sqlite3 -batch /proj/applied_bioinformatics/common_data/sample_collab.db "insert into sample2bioinformatician values('x_aliok','P7');"
sqlite3 -batch /proj/applied_bioinformatics/common_data/sample_collab.db "insert into sample2bioinformatician values('x_aliok','P299');"
sqlite3 -batch /proj/applied_bioinformatics/common_data/sample_collab.db "insert into sample2bioinformatician values('x_aliok','P133');"
sqlite3 -batch /proj/applied_bioinformatics/common_data/sample_collab.db "insert into sample2bioinformatician values('x_aliok','P276');"
sqlite3 -batch /proj/applied_bioinformatics/common_data/sample_collab.db "insert into sample2bioinformatician values('x_aliok','P9');"
# check that the insert worked
sqlite3 -batch /proj/applied_bioinformatics/common_data/sample_collab.db "select * from sample2bioinformatician where patient_code='P7';"
# check that the join worked
sqlite3 -batch /proj/applied_bioinformatics/common_data/sample_collab.db "select * from sample_annot spl left join sample2bioinformatician s2b using(patient_code) where username='x_aliok';"


# Environment setup
cp /proj/applied_bioinformatics/common_data/meta_definition_file /proj/applied_bioinformatics/users/x_aliok
mv meta_definition_file meta.def
apptainer build --fakeroot meta.sif meta.def
apptainer exec meta.sif fastq-dump


# Create a sample run accession list
sqlite3 -batch -noheader -csv /proj/applied_bioinformatics/common_data/sample_collab.db \
    "select run_accession from sample_annot spl left join sample2bioinformatician s2b using(patient_code) where username='x_aliok';" \
    > /proj/applied_bioinformatics/users/x_aliok/MedBioinfo/analyses/x_aliok_run_accessions.txt


# Download the fastq files with sra-toolkit
mkdir -p /proj/applied_bioinformatics/users/x_aliok/MedBioinfo/data/sra_fastq/
srun --cpus-per-task=6 --time=00:30:00 singularity exec -B /proj:/proj /proj/applied_bioinformatics/users/x_aliok/meta.sif bash \
    -c "xargs -a /proj/applied_bioinformatics/users/x_aliok/MedBioinfo/analyses/x_aliok_run_accessions.txt \
    fastq-dump --split-files --gzip --defline-seq '@$ac.$si.$ri' \
    --outdir /proj/applied_bioinformatics/users/x_aliok/MedBioinfo/data/sra_fastq/ --disable-multithreading"
sacct --format=JobID,JobName%20,ReqCPUS,ReqMem,Timelimit,State,ExitCode,Start,elapsed,MaxRSS,NodeList,Account%15 


# Manipulate raw sequencing FASTQ files with seqkit
## Use seqkit stats to check the basic statistics of the FASTQ files
srun --cpus-per-task=6 --time=00:10:00 singularity exec -B /proj:/proj \
    /proj/applied_bioinformatics/users/x_aliok/meta.sif seqkit --threads 6 \
    stats -T /proj/applied_bioinformatics/users/x_aliok/MedBioinfo/data/sra_fastq/*.fastq.gz > \
    /proj/applied_bioinformatics/users/x_aliok/MedBioinfo/analyses/x_aliok_fastq_stats.txt
## Use seqkit rmdup to check if the FASTQ files have been de-replicated (duplicate identical reads removed)
### check on Read1
srun --cpus-per-task=6 --time=00:05:00 singularity exec -B /proj:/proj /proj/applied_bioinformatics/users/x_aliok/meta.sif \
    bash -c 'xargs -I{} -a /proj/applied_bioinformatics/users/x_aliok/MedBioinfo/analyses/x_aliok_run_accessions.txt bash -c "
    seqkit --threads 6 rmdup \
    /proj/applied_bioinformatics/users/x_aliok/MedBioinfo/data/sra_fastq/{}_1.fastq.gz \
    -o /proj/applied_bioinformatics/users/x_aliok/MedBioinfo/data/sra_fastq/{}_1_rmdup.fastq.gz"'
### check on Read2
srun --cpus-per-task=6 --time=00:05:00 singularity exec -B /proj:/proj /proj/applied_bioinformatics/users/x_aliok/meta.sif \
    bash -c 'xargs -I{} -a /proj/applied_bioinformatics/users/x_aliok/MedBioinfo/analyses/x_aliok_run_accessions.txt bash -c "
    seqkit --threads 6 rmdup \
    /proj/applied_bioinformatics/users/x_aliok/MedBioinfo/data/sra_fastq/{}_2.fastq.gz \
    -o /proj/applied_bioinformatics/users/x_aliok/MedBioinfo/data/sra_fastq/{}_2_rmdup.fastq.gz"'
## Use seqkit sub-command grep to guess if the FASTQ files have already been trimmed of their sequencing kit adapters
srun --cpus-per-task=6 --time=00:10:00 singularity exec -B /proj:/proj \
    /proj/applied_bioinformatics/users/x_aliok/meta.sif seqkit --threads 6 \
    locate -p 'AGATCGGAAGAGCACACGTCTGAACTCCAGTCA' -p 'AGATCGGAAGAGCGTCGTGTAGGGAAAGAGTGT' \
    /proj/applied_bioinformatics/users/x_aliok/MedBioinfo/data/sra_fastq/*.fastq.gz > \
    /proj/applied_bioinformatics/users/x_aliok/MedBioinfo/analyses/x_aliok_fastq_adapter_stats.txt


# Quality control the raw sequencing FASTQ files with fastQC
mkdir -p /proj/applied_bioinformatics/users/x_aliok/MedBioinfo/analyses/fastqc
srun --cpus-per-task=2 --time=00:30:00 singularity exec -B /proj:/proj /proj/applied_bioinformatics/users/x_aliok/meta.sif \
    bash -c "xargs -I{} -a /proj/applied_bioinformatics/users/x_aliok/MedBioinfo/analyses/x_aliok_run_accessions.txt \
    fastqc /proj/applied_bioinformatics/users/x_aliok/MedBioinfo/data/sra_fastq/{}_1.fastq.gz \
           /proj/applied_bioinformatics/users/x_aliok/MedBioinfo/data/sra_fastq/{}_2.fastq.gz \
    --outdir /proj/applied_bioinformatics/users/x_aliok/MedBioinfo/analyses/fastqc"


# Moving files from remote server to local laptop hard disk
scp x_aliok@tetralith.nsc.liu.se:/proj/applied_bioinformatics/users/x_aliok/Medbioinfo/analyses/fastqc/*.html  ~/


# Merging paired end reads
mkdir -p /proj/applied_bioinformatics/users/x_aliok/MedBioinfo/data/merged_pairs
srun --cpus-per-task=4 --time=00:30:00 singularity exec -B /proj:/proj /proj/applied_bioinformatics/users/x_aliok/meta.sif \
bash -c "xargs -I{} -a /proj/applied_bioinformatics/users/x_aliok/MedBioinfo/analyses/x_aliok_run_accessions.txt \
flash --threads 4 --compress --output-prefix {}.flash \
--output-directory /proj/applied_bioinformatics/users/x_aliok/MedBioinfo/data/merged_pairs \
/proj/applied_bioinformatics/users/x_aliok/MedBioinfo/data/sra_fastq/{}_1.fastq.gz \
/proj/applied_bioinformatics/users/x_aliok/MedBioinfo/data/sra_fastq/{}_2.fastq.gz \
2>&1 | tee -a /proj/applied_bioinformatics/users/x_aliok/MedBioinfo/analyses/x_aliok_flash.log"


# Use read mapping to check for PhiX contamination
mkdir -p /proj/applied_bioinformatics/users/x_aliok/MedBioinfo/data/reference_seqs
singularity exec -B /proj:/proj /proj/applied_bioinformatics/users/x_aliok/meta.sif efetch -db nuccore -id NC_001422 -format fasta > /proj/applied_bioinformatics/users/x_aliok/MedBioinfo/data/reference_seqs/PhiX_NC_001422.fna
mkdir -p /proj/applied_bioinformatics/users/x_aliok/MedBioinfo/data/bowtie2_DBs/PhiX_bowtie2_DB
singularity exec -B /proj:/proj /proj/applied_bioinformatics/users/x_aliok/meta.sif bowtie2-build -f /proj/applied_bioinformatics/users/x_aliok/MedBioinfo/data/reference_seqs/PhiX_NC_001422.fna /proj/applied_bioinformatics/users/x_aliok/MedBioinfo/data/bowtie2_DBs/PhiX_bowtie2_DB/PhiX_bowtie2_DB
mkdir -p /proj/applied_bioinformatics/users/x_aliok/MedBioinfo/analyses/bowtie
srun --cpus-per-task=8 singularity exec -B /proj:/proj /proj/applied_bioinformatics/users/x_aliok/meta.sif bowtie2 \
 -x /proj/applied_bioinformatics/users/x_aliok/MedBioinfo/data/bowtie2_DBs/PhiX_bowtie2_DB/PhiX_bowtie2_DB \
 -U /proj/applied_bioinformatics/users/x_aliok/MedBioinfo/data/merged_pairs/ERR*.extendedFrags.fastq.gz \
 -S /proj/applied_bioinformatics/users/x_aliok/MedBioinfo/analyses/bowtie/x_aliok_merged2PhiX.sam \
 --threads 8 \
 --no-unal 2>&1 | tee /proj/applied_bioinformatics/users/x_aliok/MedBioinfo/analyses/bowtie/x_aliok_bowtie_merged2PhiX.log


# Use read mapping to check for SARS-CoV-2
mkdir -p /proj/applied_bioinformatics/users/x_aliok/MedBioinfo/data/reference_seqs
singularity exec -B /proj:/proj /proj/applied_bioinformatics/users/x_aliok/meta.sif efetch -db nuccore -id NC_045512 -format fasta > /proj/applied_bioinformatics/users/x_aliok/MedBioinfo/data/reference_seqs/NC_045512.fna
mkdir -p /proj/applied_bioinformatics/users/x_aliok/MedBioinfo/data/bowtie2_DBs/SARS-CoV-2_bowtie2_DB
singularity exec -B /proj:/proj /proj/applied_bioinformatics/users/x_aliok/meta.sif bowtie2-build -f /proj/applied_bioinformatics/users/x_aliok/MedBioinfo/data/reference_seqs/NC_045512.fna /proj/applied_bioinformatics/users/x_aliok/MedBioinfo/data/bowtie2_DBs/SARS-CoV-2_bowtie2_DB/SARS-CoV-2_bowtie2_DB
mkdir -p /proj/applied_bioinformatics/users/x_aliok/MedBioinfo/analyses/bowtie
srun --cpus-per-task=8 singularity exec -B /proj:/proj /proj/applied_bioinformatics/users/x_aliok/meta.sif bowtie2 \
 -x /proj/applied_bioinformatics/users/x_aliok/MedBioinfo/data/bowtie2_DBs/SARS-CoV-2_bowtie2_DB/SARS-CoV-2_bowtie2_DB \
 -U /proj/applied_bioinformatics/users/x_aliok/MedBioinfo/data/merged_pairs/ERR*.extendedFrags.fastq.gz \
 -S /proj/applied_bioinformatics/users/x_aliok/MedBioinfo/analyses/bowtie/x_aliok_merged2SARS-CoV-2.sam \
 --threads 8 \
 --no-unal 2>&1 | tee /proj/applied_bioinformatics/users/x_aliok/MedBioinfo/analyses/bowtie/x_aliok_bowtie_merged2SARS-CoV-2.log


# Look in the SAM output file to check out how alignments look in SAM format with samtools view
#singularity exec -B /proj:/proj /proj/applied_bioinformatics/users/x_aliok/meta.sif samtools view -S /proj/applied_bioinformatics/users/x_aliok/MedBioinfo/analyses/bowtie/x_aliok_merged2SARS-CoV-2.sam | head


# Combine quality control results into one unique report for all samples analysed
mkdir -p /proj/applied_bioinformatics/users/x_aliok/MedBioinfo/analyses/multiqc
srun singularity exec -B /proj:/proj /proj/applied_bioinformatics/users/x_aliok/meta.sif multiqc --force --title "x_aliok sample sub-set" \
    /proj/applied_bioinformatics/users/x_aliok/MedBioinfo/data/merged_pairs/ \
    /proj/applied_bioinformatics/users/x_aliok/MedBioinfo/analyses/fastqc/ \
    /proj/applied_bioinformatics/users/x_aliok/MedBioinfo/analyses/x_aliok_flash.log \
    /proj/applied_bioinformatics/users/x_aliok/MedBioinfo/analyses/x_aliok_fastq_stats.txt \
    /proj/applied_bioinformatics/users/x_aliok/MedBioinfo/analyses/bowtie/ \
    -o /proj/applied_bioinformatics/users/x_aliok/MedBioinfo/analyses/multiqc


# Check out your SLURM usage so far with the slightly modified sacct command:
sacct  --format=JobID,JobName%20,ReqCPUS,ReqMem,Timelimit,State,ExitCode,Start,elapsed,MaxRSS,NodeList,Account%15 -S 2022-05-28 -u x_aliok

date
echo "script end."
