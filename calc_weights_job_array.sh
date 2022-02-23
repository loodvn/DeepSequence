#!/bin/bash
#SBATCH -c 2                              # Request one core
#SBATCH -N 1                              # Request one node (if you request more than one core with -c, also using
                                          # -N 1 means all cores will be on the same node)
#SBATCH -t 0-23:59                         # Runtime in D-HH:MM format
#SBATCH -p medium                          # Partition to run in
#SBATCH --mem=30G                          # Memory total in MB (for all cores)

#SBATCH --mail-type=TIME_LIMIT_80,TIME_LIMIT,FAIL,ARRAY_TASKS
#SBATCH --mail-user="lodevicus_vanniekerk@hms.harvard.edu"

#SBATCH --job-name="deepseq_calcweights"
# Job array-specific
#SBATCH --output=slurm_files/slurm-lvn-%A_%a-%x.out  # File to which STDOUT + STDERR will be written, %A: jobID, %a: array task ID, %x: jobname
##SBATCH --array=0-41%10  		  # Job arrays (e.g. 1-100 with a maximum of 5 jobs at once)
#SBATCH --array=28			      # Resubmitting / testing only first job

hostname
pwd
module load gcc/6.2.0 cuda/9.0
export THEANO_FLAGS='floatX=float32,device=cuda,force_device=True' # Otherwise will only raise a warning and carry on with CPU

# To generate this file from a directory, just do e.g. 'ls -1 /n/groups/marks/projects/marks_lab_and_oatml/protein_transformer/MSA/deepsequence/*.a2m > msas_original.txt' and trim to just filename
lines=( $(cat "msas_original.txt") ) # Old alignments, in /n/groups/marks/projects/marks_lab_and_oatml/protein_transformer/MSA/deepsequence/
dataset_name=${lines[$SLURM_ARRAY_TASK_ID]}
echo $dataset_name

# Monitor GPU usage (store outputs in ./gpu_logs/)
#/home/lov701/job_gpu_monitor.sh gpu_logs &

srun stdbuf -oL -eL /n/groups/marks/users/aaron/deep_seqs/deep_seqs_env/bin/python \
  /n/groups/marks/users/lood/DeepSequence_runs/calc_weights.py \
  --dataset $dataset_name \
  --weights_dir_out /n/groups/marks/users/lood/DeepSequence_runs/weights_2020_02_15/ \
  --alignments_dir pascal_deepseq_alignments_dir/
#  --theta-override 0.9
