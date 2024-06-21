!/bin/bash -l

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

# Load necessary modules
module load buildtool-easybuild/4.8.0-hpce082752a2 GCCcore/12.3.0 SQLite/3.42.0
module load R/4.2.2-hpc1-gcc-11.3.0-bare
module list

# Set up R environment
echo 'R_LIBS_USER="/proj/applied_bioinformatics/users/x_aliok/R/library"' > .Renviron
install.packages("RSQLite", repos="https://cloud.r-project.org/", lib="/proj/applied_bioinformatics/users/x_aliok/R/library")
install.packages("DBI", repos="https://cloud.r-project.org/", lib="/proj/applied_bioinformatics/users/x_aliok/R/library")

# Run R script
R 
# Load necessary libraries
library(DBI)
# Connect to the database
gwasdb <- dbConnect(RSQLite::SQLite(), "bds-files/chapter-13-out-of-memory/gwascat.db")
# List tables in the database
dbListTables(gwasdb)
# List fields in the table
dbListFields(gwasdb, "gwascat")
# Query the table
dbGetQuery(gwasdb, 'SELECT * FROM gwascat')
# Query the table with a limit
df <- dbGetQuery(gwasdb, 'SELECT * FROM gwascat limit 10')
df[3,"author"]
# Filtering which rows with WHERE
dbGetQuery(gwasdb, 'SELECT chrom, position, trait, strongest_risk_snp, pvalue FROM gwascat WHERE strongest_risk_snp = "rs429358"')
dbGetQuery(gwasdb, 'SELECT chrom, position, trait, strongest_risk_snp, pvalue FROM gwascat WHERE lower(strongest_risk_snp) = "rs429358"')
dbGetQuery(gwasdb, 'SELECT chrom, position, trait, strongest_risk_snp, pvalue FROM gwascat WHERE chrom = "22" AND pvalue < 10e-15')
dbGetQuery(gwasdb, 'SELECT chrom, position, trait, strongest_risk_snp, pvalue FROM gwascat WHERE pvalue IS NOT NULL ORDER BY pvalue LIMIT 5')
dbGetQuery(gwasdb, 'SELECT chrom, position, strongest_risk_snp, pvalue FROM gwascat WHERE (chrom = "1" OR chrom = "2" OR chrom = "3") AND pvalue < 10e-11 ORDER BY pvalue LIMIT 5')
dbGetQuery(gwasdb, 'SELECT chrom, position, strongest_risk_snp, pvalue FROM gwascat WHERE chrom IN ("1", "2", "3") AND pvalue < 10e-11 ORDER BY pvalue LIMIT 5')
dbGetQuery(gwasdb, 'SELECT chrom, position, strongest_risk_snp, pvalue FROM gwascat WHERE chrom = "22" AND position BETWEEN 24000000 AND 25000000 AND pvalue IS NOT NULL ORDER BY pvalue LIMIT 5')

# SQLite Functions
dbGetQuery(gwasdb, 'SELECT lower(trait) AS trait, "chr" || chrom || ":" || position AS region FROM gwascat LIMIT 5')
dbGetQuery(gwasdb, 'SELECT ifnull(chrom, "NA") AS chrom, ifnull(position, "NA") AS position, strongest_risk_snp, ifnull(pvalue, "NA") AS pvalue FROM gwascat WHERE strongest_risk_snp = "rs429358"')

# SQLite Aggregate Functions
dbGetQuery(gwasdb, 'SELECT count(*) FROM gwascat')
dbGetQuery(gwasdb, 'SELECT count(pvalue) FROM gwascat')
dbGetQuery(gwasdb, 'SELECT count(*) - count(pvalue) AS number_of_null_pvalues FROM gwascat')
dbGetQuery(gwasdb, 'SELECT "2007" AS year, count(*) AS number_entries FROM gwascat WHERE date BETWEEN "2007-01-01" AND "2008-01-01"')
dbGetQuery(gwasdb, 'SELECT count(DISTINCT strongest_risk_snp) AS unique_rs FROM gwascat')

## Grouping rows with GROUP BY  
dbGetQuery(gwasdb, 'SELECT chrom, count(*) FROM gwascat GROUP BY chrom')
dbGetQuery(gwasdb, 'SELECT chrom, count(*) as nhits FROM gwascat GROUP BY chrom ORDER BY nhits DESC')
dbGetQuery(gwasdb, 'select strongest_risk_snp, count(*) AS count FROM gwascat GROUP BY strongest_risk_snp ORDER BY count DESC LIMIT 5')
dbGetQuery(gwasdb, 'select strongest_risk_snp, strongest_risk_allele, count(*) AS count FROM gwascat GROUP BY strongest_risk_snp, strongest_risk_allele ORDER BY count DESC LIMIT 10')
dbGetQuery(gwasdb, 'SELECT substr(date, 1, 4) AS year FROM gwascat GROUP BY year')
dbGetQuery(gwasdb, 'SELECT substr(date, 1, 4) AS year, round(avg(pvalue_mlog), 4) AS mean_log_pvalue, count(pvalue_mlog) AS n FROM gwascat GROUP BY year')
dbGetQuery(gwasdb, 'SELECT substr(date, 1, 4) AS year, round(avg(pvalue_mlog), 4) AS mean_log_pvalue, count(pvalue_mlog) AS n FROM gwascat GROUP BY year HAVING count(pvalue_mlog) > 10')

# Subqueries
dbGetQuery(gwasdb, 'SELECT substr(date, 1, 4) AS year, author, pubmedid, count(*) AS num_assoc FROM gwascat GROUP BY pubmedid LIMIT 5')
dbGetQuery(gwasdb, 'SELECT year, avg(num_assoc) FROM (SELECT substr(date, 1, 4) AS year, author, count(*) AS num_assoc FROM gwascat GROUP BY pubmedid) GROUP BY year')

# Organizing Relational Databases and Joins
## Organizing relational databases
dbGetQuery(gwasdb, 'SELECT date, pubmedid, author, strongest_risk_snp FROM gwascat WHERE pubmedid = "24388013" LIMIT 5')
## Inner joins
joinsdb <- dbConnect(RSQLite::SQLite(), "bds-files/chapter-13-out-of-memory/joins.db")
dbListTables(joinsdb)
dbGetQuery(joinsdb, 'SELECT * FROM assocs')
dbGetQuery(joinsdb, 'SELECT * FROM studies')
dbGetQuery(joinsdb, 'SELECT * FROM assocs INNER JOIN studies ON assocs.study_id = studies.id')
dbGetQuery(joinsdb, 'SELECT studies.id, assocs.id, trait, year FROM assocs INNER JOIN studies ON assocs.study_id = studies.id')
dbGetQuery(joinsdb, 'SELECT studies.id AS study_id, assocs.id AS assoc_id, trait, year FROM assocs INNER JOIN studies ON assocs.study_id = studies.id')
dbGetQuery(joinsdb, 'SELECT count(*) FROM assocs INNER JOIN studies ON assocs.study_id = studies.id')
dbGetQuery(joinsdb, 'SELECT count(*) FROM assocs')
dbGetQuery(joinsdb, 'SELECT * FROM assocs WHERE study_id NOT IN (SELECT id FROM studies)')
dbGetQuery(joinsdb, 'SELECT * FROM studies WHERE id NOT IN (SELECT study_id FROM assocs)')
## Left outer joins
dbGetQuery(joinsdb, 'SELECT * FROM assocs LEFT OUTER JOIN studies ON assocs.study_id = studies.id')
dbGetQuery(joinsdb, 'SELECT * FROM studies LEFT OUTER JOIN assocs ON assocs.study_id = studies.id')

# Writing to Databases
## Creating tables
practicedb <- dbConnect(RSQLite::SQLite(), "bds-files/chapter-13-out-of-memory/practice.db")
dbListTables(practicedb)
dbExecute(practicedb, 'CREATE TABLE variants(id integer primary key, chrom text, start integer, end integer, strand text, name text)')
dbListTables(practicedb)
## Inserting records into tables
dbExecute(practicedb, 'INSERT INTO variants(id, chrom, start, end, strand, name) VALUES(NULL, "16", 48224287, 48224287, "+", "rs17822931")')
dbGetQuery(practicedb, 'SELECT * FROM variants')
## Indexing
gwascat2tabledb <- dbConnect(RSQLite::SQLite(), "bds-files/chapter-13-out-of-memory/gwascat2table.db")
dbListTables(gwascat2tabledb)
dbExecute(gwascat2tabledb, 'CREATE INDEX snp_idx ON assocs(strongest_risk_snp)')
dbGetQuery(gwascat2tabledb, "PRAGMA index_list('assocs')")
dbExecute(gwascat2tabledb, 'DROP INDEX snp_idx')
dbGetQuery(gwascat2tabledb, "PRAGMA index_list('assocs')")

