#!/bin/bash
#SBATCH -c 2                           	# Request one core
#SBATCH -N 1                           	# Request one node (if you request more than one core with -c, also using
                                       	# -N 1 means all cores will be on the same node)
#SBATCH -t 0-12:00                      # Runtime in D-HH:MM format
#SBATCH -p gpu_quad               	# Partition to run in / gpu_marks/gpu_requeue
#SBATCH --gres=gpu:teslaV100s:1		# If on gpu_quad, use teslaV100s, if on gpu_requeue, use teslaM40 or a100?
#SBATCH --mem=30G         		# Memory total in MB (for all cores)

#SBATCH --mail-type=TIME_LIMIT_80,TIME_LIMIT,FAIL,ARRAY_TASKS
#SBATCH --mail-user="lodevicus_vanniekerk@hms.harvard.edu"

##SBATCH -o slurm_files/slurm-%j.out                 # File to which STDOUT + STDERR will be written, including job ID in filename
#SBATCH --job-name="ds_dms5"
# Job array-specific
#SBATCH --output=slurm_files/slurm-lvn-%A_%a-%x.out
##SBATCH --array=30-49                  # Job arrays (e.g. 1-100 with a maximum of 5 jobs at once)
#SBATCH --array=0-81%10          		# I think there are 82 DMS files
#SBATCH --array=1,16,22,23,27,32,41,42,57,66,67               # Resubmitting failed jobs
# TODO debugging: only launch jobs after debug jobs have passed (e.g. job 0)

hostname
pwd
module load gcc/6.2.0 cuda/9.0
export THEANO_FLAGS='floatX=float32,device=cuda,force_device=True,traceback.limit=20, exception_verbosity=high' # Otherwise will only raise a warning and carry on with CPU

# lines=(`cat "datasets.txt"`)
# dataset_name=${lines[$SLURM_ARRAY_TASK_ID]}
# echo $dataset_name

export dms_mapping=/home/pn73/protein_transformer/utils/mapping_files/DMS_mapping_20220109.csv
export dms_input_folder=/n/groups/marks/projects/marks_lab_and_oatml/protein_transformer/DMS/DMS_Benchmarking_Dataset_20220109
export dms_output_folder=/n/groups/marks/users/lood/DeepSequence_runs/model_scores/ #/n/groups/marks/projects/marks_lab_and_oatml/protein_transformer/model_scores/MSA_transformer
export msa_path=/n/groups/marks/projects/marks_lab_and_oatml/protein_transformer/MSA/tkmer_20220109
export model_checkpoint_dir=/n/groups/marks/users/lood/DeepSequence_runs/params/

# Monitor GPU usage (store outputs in ./gpu_logs/)
/home/lov701/job_gpu_monitor.sh gpu_logs &

srun stdbuf -oL -eL /n/groups/marks/users/aaron/deep_seqs/deep_seqs_env/bin/python \
  /n/groups/marks/users/lood/DeepSequence_runs/run_muteff_pred_seqs_batch.py \
  --dms_mapping $dms_mapping \
  --dms_input_dir $dms_input_folder \
  --dms_output_dir $dms_output_folder \
  --msa_path $msa_path \
  --model_checkpoint $model_checkpoint_dir \
  --dms_index $SLURM_ARRAY_TASK_ID \
  --samples 2000
#  --theta-override 0.9


