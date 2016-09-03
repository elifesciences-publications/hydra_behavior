#!/bin/sh

# Derictives

#PBS -N assign_mbhx

#PBS -W group_list=yetibrain

#PBS -l nodes=1:ppn=1,walltime=12:00:00,mem=8gb

#PBS -M sh3276@columbia.edu

#PBS -m a

#PBS -V

#PBS -o localhost:/u/10/s/sh3276/eo/

#PBS -e localhost:/u/10/s/sh3276/eo/

#PBS -t 1-13

echo "starting job"

date

m=3
n=2

matlab -nosplash -nodisplay -nodesktop -r "assign_mbhx_yeti($PBS_ARRAYID,$m,$n);exit"

echo "done with job"

date

# End of script
