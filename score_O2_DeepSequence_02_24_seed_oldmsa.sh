#!/bin/bash
#SBATCH -c 2                           	# Request one core
#SBATCH -N 1                           	# Request one node (if you request more than one core with -c, also using
                                       	# -N 1 means all cores will be on the same node)
#SBATCH -t 0-5:59                      # Runtime in D-HH:MM format
#SBATCH -p gpu_quad,gpu #,gpu_requeue        # Partition to run in
# If on gpu_quad, use teslaV100s
# If on gpu_requeue, use teslaM40 or a100?
# If on gpu, any of them are fine (teslaV100, teslaM40, teslaK80) although K80 sometimes is too slow
#SBATCH --gres=gpu:1
#SBATCH --constraint=gpu_doublep
#SBATCH --qos=gpuquad_qos
#SBATCH --mem=10G                          # Memory total in MB (for all cores)



#SBATCH --mail-type=TIME_LIMIT_80,TIME_LIMIT,FAIL,ARRAY_TASKS
#SBATCH --mail-user="lodevicus_vanniekerk@hms.harvard.edu"

##SBATCH -o slurm_files/slurm-%j.out                 # File to which STDOUT + STDERR will be written, including job ID in filename
##SBATCH --job-name="ds_dms_oldmsa"
#SBATCH --job-name="tmp_ds_dms_oldmsa"
# Job array-specific
#SBATCH --output=slurm_files/slurm-lvn-%A_%a-%x.out
#SBATCH --array=0-81,100-181,200-281,300-381,400-481%10          		# I think there are 82 DMS files
#SBATCH --array=0,1,100,101                   # Just checking a few examples

################################################################################

set -e # fail fully on first line failure (from Joost slurm_for_ml)

# Note: Remember to clear ~/.theano cache before running this script

echo "hostname: $(hostname)"
echo "Running from: $(pwd)"
echo "GPU available: $(nvidia-smi)"
module load gcc/6.2.0 cuda/9.0
export THEANO_FLAGS='floatX=float32,device=cuda,force_device=True,traceback.limit=20, exception_verbosity=high' # Otherwise will only raise a warning and carry on with CPU

DATASET_ID=$(($SLURM_ARRAY_TASK_ID % 100))  # Group all datasets together in 0xx, 1xx, 2xx, etc.
SEED_ID=$(($SLURM_ARRAY_TASK_ID / 100))
seeds=(1 2 3 4 5)  # For some reason Theano won't accept SEED 0..
SEED=${seeds[$SEED_ID]}
echo "DATASET_ID: $DATASET_ID, SEED: $SEED"

export dms_mapping=/n/groups/marks/users/lood/DeepSequence_runs/DMS_mapping_20220109.csv  # From /home/pn73/protein_transformer/utils/mapping_files/DMS_mapping_20220109.csv
export dms_input_folder=/n/groups/marks/projects/marks_lab_and_oatml/protein_transformer/DMS/DMS_Benchmarking_Dataset_20220109
export dms_output_folder=/n/groups/marks/users/lood/DeepSequence_runs/model_scores_tmp_seed/ #/n/groups/marks/projects/marks_lab_and_oatml/protein_transformer/model_scores/MSA_transformer
#export msa_path=/n/groups/marks/projects/marks_lab_and_oatml/protein_transformer/MSA/tkmer_20220109
export msa_path=/n/groups/marks/users/lood/DeepSequence_runs/pascal_deepseq_alignments_dir  # Original DeepSequence MSA: /n/groups/marks/projects/marks_lab_and_oatml/protein_transformer/MSA/deepsequence/
export model_checkpoint_dir=/n/groups/marks/users/lood/DeepSequence_runs/params_02_28_msa_original/
export weights_dir=/n/groups/marks/users/lood/DeepSequence_runs/weights_2020_02_15/

# Monitor GPU usage (store outputs in ./gpu_logs/)
/home/lov701/job_gpu_monitor.sh --interval 1m gpu_logs &

srun stdbuf -oL -eL /n/groups/marks/users/aaron/deep_seqs/deep_seqs_env/bin/python \
  /n/groups/marks/users/lood/DeepSequence_runs/run_muteff_pred_seqs_batch.py \
  --dms_mapping $dms_mapping \
  --dms_input_dir $dms_input_folder \
  --dms_output_dir $dms_output_folder \
  --msa_path $msa_path \
  --model_checkpoint $model_checkpoint_dir \
  --weights_dir $weights_dir \
  --dms_index $DATASET_ID \
  --samples 2000 \
  --seed "$SEED" \
  --msa_use_uniprot  # Workaround for old MSAs, where the mapping file doesn't contain the MSA filepaths
#  --theta-override 0.9
