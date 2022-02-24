#!/bin/bash
#SBATCH -c 2                               # Request two cores
#SBATCH -N 1                               # Request one node (if you request more than one core with -c, also using
                                           # -N 1 means all cores will be on the same node)
#SBATCH -t 0-5:59                         # Runtime in D-HH:MM format
#SBATCH -p gpu_quad                           # Partition to run in
#SBATCH --gres=gpu:teslaV100s:1		         # If on gpu_quad, use teslaV100s, if on gpu_requeue, use teslaM40 or a100?
#SBATCH --mem=20G                          # Memory total in MB (for all cores)

#SBATCH --mail-type=TIME_LIMIT_80,TIME_LIMIT,FAIL,ARRAY_TASKS
#SBATCH --mail-user="lodevicus_vanniekerk@hms.harvard.edu"

#SBATCH -o slurm_files/slurm-%j.out                 # File to which STDOUT + STDERR will be written, including job ID in filename
#SBATCH --job-name="deepseq_training_seeds"
# Job array-specific
#SBATCH --output=slurm_files/slurm-lvn-%A_%a-%x.out
##SBATCH --error=slurm_files/slurm-lvn-%A_%a-%x.err   # Optional: Redirect STDERR to its own file
#SBATCH --array=0-199%10  		  # Job arrays, range inclusive (MIN-MAX%MAX_CONCURRENT_TASKS)  # original DeepSeq MSA: 40 datasets * 5 = 199 (indexing from 0)
##SBATCH --array=0-4			      # Resubmitting / testing only first job

################################################################################

set -e # fail fully on first line failure (from Joost slurm_for_ml)

# Note: Remember to clear ~/.theano cache before running this script

echo "hostname: $(hostname)"
echo "Running from: $(pwd)"
module load gcc/6.2.0 cuda/9.0
export THEANO_FLAGS='floatX=float32,device=cuda,force_device=True' # Otherwise will only raise a warning and carry on with CPU

# To generate this file from a directory, just do e.g. 'ls -1 /n/groups/marks/projects/marks_lab_and_oatml/protein_transformer/MSA/deepsequence/*.a2m > msas_original.txt'
lines=(`cat "datasets.txt"`)
dataset_id=$(($SLURM_ARRAY_TASK_ID / 5))  # Group all seeds together
seed_id=$(($SLURM_ARRAY_TASK_ID % 5))
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
  --weights_dir /home/pn73/protein_transformer/utils/msa_weights/ \
  --alignments_dir protein_transformer_alignments_dir
#  --theta-override 0.9

# Note: Reusing Pascal's MSA_weights, could also recompute them
# Also Note: Need to save this in a separate place than ./params
#   - Perhaps it is better after all to create different "working directories"?