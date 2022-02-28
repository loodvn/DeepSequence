#!/bin/bash
#SBATCH -c 2                               # Request two cores
#SBATCH -N 1                               # Request one node (if you request more than one core with -c, also using
                                           # -N 1 means all cores will be on the same node)
#SBATCH -t 0-23:59                         # Runtime in D-HH:MM format
#SBATCH -p gpu_quad,gpu #,gpu_requeue        # Partition to run in
# If on gpu_quad, use teslaV100s
# If on gpu_requeue, use teslaM40 or a100?
# If on gpu, any of them are fine (teslaV100, teslaM40, teslaK80) although K80 sometimes is too slow
#SBATCH --gres=gpu:1
#SBATCH --constraint=gpu_doublep
#SBATCH --qos=gpuquad_qos
#SBATCH --mem=40G                          # Memory total in MB (for all cores)

#SBATCH --mail-type=TIME_LIMIT_80,TIME_LIMIT,FAIL,ARRAY_TASKS
#SBATCH --mail-user="lodevicus_vanniekerk@hms.harvard.edu"

##SBATCH -o slurm_files/slurm-%j.out                 # File to which STDOUT + STDERR will be written, including job ID in filename
#SBATCH --job-name="deepseq_training_original_msa_seeds"

# Job array-specific
#SBATCH --output=slurm_files/slurm-lvn-%A_%3a-%x.out
##SBATCH --error=slurm_files/slurm-lvn-%A_%3a-%x.err   # Optional: Redirect STDERR to its own file
#SBATCH --array=0-39,100-139,200-239,300-339,400-439%10  		  # Job arrays, range inclusive (MIN-MAX%MAX_CONCURRENT_TASKS)  # original DeepSeq MSA: 40 datasets * 5 = 199 (indexing from 0)
#SBATCH --array=2,3,4,7,8,104			      # Resubmitting / testing only first job

# 28 Feb reruns:
#Failed rerun theano:
#3
#+24min limits:
#0,1,5,6,9,10,11,12,13,14
#+ Slow / no GPU:
#101,103,302,411
#+ cuda OOM:
#324,403
#SBATCH --array=3,0,1,5,6,9,10,11,12,13,14,101,103,302,411,324,403

################################################################################

set -e # fail fully on first line failure (from Joost slurm_for_ml)

# Note: Remember to clear ~/.theano cache before running this script

echo "hostname: $(hostname)"
echo "Running from: $(pwd)"
echo "GPU available: " $SLURM_STEP_GPUS
module load gcc/6.2.0 cuda/9.0
export THEANO_FLAGS='floatX=float32,device=cuda,force_device=True' # Otherwise will only raise a warning and carry on with CPU

# To generate this file from a directory, just do e.g. 'ls -1 /n/groups/marks/projects/marks_lab_and_oatml/protein_transformer/MSA/deepsequence/*.a2m > msas_original.txt'
lines=( $(cat "msas_original.txt") ) # Old alignments, in /n/groups/marks/projects/marks_lab_and_oatml/protein_transformer/MSA/deepsequence/
dataset_id=$(($SLURM_ARRAY_TASK_ID % 100))  # Group a run of datasets together
seed_id=$(($SLURM_ARRAY_TASK_ID / 100))
seeds=(1 2 3 4 5)  # For some reason Theano won't accept seed 0..
seed=${seeds[$seed_id]}
echo "dataset_id: $dataset_id, seed: $seed"

dataset_name=${lines[$dataset_id]}
echo "dataset name: $dataset_name"

# Monitor GPU usage (store outputs in ./gpu_logs/)
/home/lov701/job_gpu_monitor.sh --interval 1m gpu_logs &

srun stdbuf -oL -eL /n/groups/marks/users/aaron/deep_seqs/deep_seqs_env/bin/python \
  /n/groups/marks/users/lood/DeepSequence_runs/run_svi.py \
  --dataset $dataset_name \
  --weights_dir weights_2020_02_15 \
  --alignments_dir pascal_deepseq_alignments_dir \
  --seed "$seed"  # grouping seeds together, e.g. job array 15-19 is dataset id 3, seeds 0-4 (indexing from 0)
#  --theta-override 0.9
