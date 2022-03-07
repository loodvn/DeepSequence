#!/bin/bash
#SBATCH -c 2                               # Request two cores
#SBATCH -N 1                               # Request one node (if you request more than one core with -c, also using
                                           # -N 1 means all cores will be on the same node)
#SBATCH -t 0-23:59                         # Runtime in D-HH:MM format
#SBATCH -p gpu_quad    #,gpu_marks,gpu,gpu_requeue        # Partition to run in
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
#SBATCH --job-name="deepseq_training_msa_v5_seeds"

# Job array-specific
#SBATCH --output=slurm_files/slurm-lvn-%A_%3a-%x.out   # Nice tip: using %3a to pad to 3 characters (23 -> 023)
##SBATCH --error=slurm_files/slurm-lvn-%A_%3a-%x.err   # Optional: Redirect STDERR to its own file
#SBATCH --array=0-71,100-171,200-271,300-371,400-471%10  		  # Job arrays, range inclusive (MIN-MAX%MAX_CONCURRENT_TASKS)  # 72 MSAs in msa_tkmer_20220227 (removed 2 extra BRCA1)
##SBATCH --array=0,1,100,102			      # Resubmitting / testing only first job
#SBATCH --array=17,321,421    # Out-of-memory resubmissions
##SBATCH --hold  # Holds job so that we can first manually check a few

# Quite neat workflow:
# Submit job array in held state, then release first job to test
# Add a dependency so that the next jobs are submitted as soon as the first job completes successfully:
# scontrol update Dependency=afterok:<jobid>_0 JobId=<jobid>
# Release all the other jobs; they'll be stuck until the first job is done
################################################################################

set -e # fail fully on first line failure (from Joost slurm_for_ml)

# Note: Remember to clear ~/.theano cache before running this script

echo "hostname: $(hostname)"
echo "Running from: $(pwd)"
echo "GPU available: $(nvidia-smi)"
module load gcc/6.2.0 cuda/9.0
export THEANO_FLAGS='floatX=float32,device=cuda,force_device=True' # Otherwise will only raise a warning and carry on with CPU

# To generate this file from a directory, just do e.g. '(cd ALIGNMENTS_DIR && ls -1 *.a2m) > datasets.txt'
# Note: Deleted non-"full" BRCA1 alignments from copied folder
lines=( $(cat "msa_v5.txt") ) # v5 benchmark
DATASET_ID=$(($SLURM_ARRAY_TASK_ID % 100))  # Group a run of datasets together
seed_id=$(($SLURM_ARRAY_TASK_ID / 100))
seeds=(1 2 3 4 5)  # For some reason Theano won't accept seed 0..
SEED=${seeds[$seed_id]}
echo "DATASET_ID: $DATASET_ID, seed: $SEED"

dataset_name=${lines[$DATASET_ID]}
echo "dataset name: $dataset_name"

#CAPSD_AAV2S_uniprot_t099_msc70_mcc70_b0.8.a2m
#ENV_HV1B9_S364P-M373R_b0.3.a2m
#GCN4_YEAST_full_24-02-2022_b01.a2m
#GFP_AEQVI_b0.8.a2m
#NRAM_I33A0_full_11-26-2021_b01.a2m
#R1AB_SARS2_02-19-2022_b07.a2m
#TADBP_HUMAN_full_11-26-2021_b09.a2m
# Note also that there are some extra weights files: CAS9_STRP1_theta_0.2.npy, LAMB_ECOLI_theta_0.2.npy
export WEIGHTS_DIR=weights_msa_tkmer_20220227
export ALIGNMENTS_DIR=msa_tkmer_20220227

# Monitor GPU usage (store outputs in ./gpu_logs/)
/home/lov701/job_gpu_monitor.sh --interval 1m gpu_logs &

srun stdbuf -oL -eL /n/groups/marks/users/aaron/deep_seqs/deep_seqs_env/bin/python \
  /n/groups/marks/users/lood/DeepSequence_runs/run_svi.py \
  --dataset $dataset_name \
  --weights_dir $WEIGHTS_DIR \
  --alignments_dir $ALIGNMENTS_DIR \
  --seed $SEED
#  --theta-override 0.9

# Note: Reusing Pascal's MSA_weights, could also recompute them
# Also Note: Need to save this in a separate place than ./params
#   - Perhaps it is better after all to create different "working directories"?