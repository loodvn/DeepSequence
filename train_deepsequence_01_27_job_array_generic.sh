#!/bin/bash
#SBATCH -c 2                               # Request two cores
#SBATCH -N 1                               # Request one node (if you request more than one core with -c, also using
                                           # -N 1 means all cores will be on the same node)
#SBATCH -t 0-23:59                         # Runtime in D-HH:MM format
#SBATCH -p gpu_quad                           # Partition to run in
#SBATCH --gres=gpu:teslaV100s:1		         # If on gpu_quad, use teslaV100s, if on gpu_requeue, use teslaM40 or a100?
#SBATCH --mem=20G                          # Memory total in MB (for all cores)

#SBATCH --mail-type=TIME_LIMIT_80,TIME_LIMIT,FAIL,ARRAY_TASKS
#SBATCH --mail-user="lodevicus_vanniekerk@hms.harvard.edu"

#SBATCH -o slurm_files/slurm-%j.out                 # File to which STDOUT + STDERR will be written, including job ID in filename
#SBATCH --job-name="deepseq_training_original"
# Job array-specific
#SBATCH --output=slurm_files/slurm-lvn-%A_%a-%x.out
#SBATCH --array=0-70%10  		# Job arrays (e.g. 1-100 with a maximum of 5 jobs at once)
##SBATCH --array=2			# Resubmitting

hostname
pwd
module load gcc/6.2.0 cuda/9.0
export THEANO_FLAGS='floatX=float32,device=cuda,force_device=True' # Otherwise will only raise a warning and carry on with CPU

# To generate this file from a directory, just do e.g. 'ls -1 /n/groups/marks/projects/marks_lab_and_oatml/protein_transformer/MSA/deepsequence/*.a2m > msas_original.txt'
lines=(`cat "datasets.txt"`)
dataset_name=${lines[$SLURM_ARRAY_TASK_ID]}
echo $dataset_name

# Monitor GPU usage (store outputs in ./gpu_logs/)
/home/lov701/job_gpu_monitor.sh gpu_logs &

srun stdbuf -oL -eL /n/groups/marks/users/aaron/deep_seqs/deep_seqs_env/bin/python \
  /n/groups/marks/users/lood/DeepSequence_runs/run_svi.py \
  --dataset $dataset_name \
  --weights_dir /home/pn73/protein_transformer/utils/msa_weights/
#  --theta-override 0.9
