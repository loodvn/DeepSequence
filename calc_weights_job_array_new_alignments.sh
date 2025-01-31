#!/bin/bash
#SBATCH -c 2                              # Request one core
#SBATCH -N 1                              # Request one node (if you request more than one core with -c, also using
                                          # -N 1 means all cores will be on the same node)
#SBATCH -t 0-5:59                         # Runtime in D-HH:MM format
#SBATCH -p short                          # Partition to run in
#SBATCH --mem=10G                          # Memory total in MB (for all cores)

#SBATCH --mail-type=TIME_LIMIT_80,TIME_LIMIT,FAIL,ARRAY_TASKS
#SBATCH --mail-user="lodevicus_vanniekerk@hms.harvard.edu"

#SBATCH --job-name="deepseq_calcweights_11_26_2021"
# Job array-specific
# Nice tip: using %3a to pad job array number to 3 digits (23 -> 023)
#SBATCH --output=slurm_files/slurm-lvn-%A_%3a-%x.out  # File to which STDOUT + STDERR will be written, %A: jobID, %a: array task ID, %x: jobname
#SBATCH --array=0-41%10  		  # Job arrays (e.g. 1-100 with a maximum of 5 jobs at once)
##SBATCH --array=0,1			      # Resubmitting / testing only first job

echo "hostname: $(hostname)"
echo "Running from: $(pwd)"
echo "GPU available: $(nvidia-smi)"
echo "Git branch: $(git rev-parse --abbrev-ref HEAD)"
#echo "Git commit: $(git rev-parse HEAD)"
echo "Git last commit: $(git log -1)"

# To generate this file from a directory, just do e.g. 'ls -1 /n/groups/marks/projects/marks_lab_and_oatml/protein_transformer/MSA/deepsequence/*.a2m > msas_original.txt'
#lines=( $(cat "msas_original.txt") ) # Old alignments, in /n/groups/marks/projects/marks_lab_and_oatml/protein_transformer/MSA/deepsequence/
lines=( $(cat "msas_new_11_26_2021.txt") )  # New alignments, in datasets/alignments/ REMEMBER TO RENAME WEIGHTS OUT AND ALIGNMENTS_DIR
dataset_name=${lines[$SLURM_ARRAY_TASK_ID]}
echo $dataset_name

# Monitor GPU usage (store outputs in ./gpu_logs/)
/home/lov701/job_gpu_monitor.sh gpu_logs &

srun stdbuf -oL -eL /n/groups/marks/users/aaron/deep_seqs/deep_seqs_env/bin/python \
  /n/groups/marks/users/lood/DeepSequence_runs/calc_weights.py \
  --dataset $dataset_name \
  --weights_dir_out /n/groups/marks/users/lood/DeepSequence_runs/weights_2021_11_16/ \
  --alignments_dir datasets/alignments/
#  --theta-override 0.9
