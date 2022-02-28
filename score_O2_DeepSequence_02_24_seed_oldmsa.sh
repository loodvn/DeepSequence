#!/bin/bash
#SBATCH -c 2                           	# Request one core
#SBATCH -N 1                           	# Request one node (if you request more than one core with -c, also using
                                       	# -N 1 means all cores will be on the same node)
#SBATCH -t 0-5:59                      # Runtime in D-HH:MM format
#SBATCH -p gpu_quad,gpu_marks,gpu #,gpu_requeue        # Partition to run in
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
#SBATCH --job-name="ds_dms_oldmsa"
# Job array-specific
#SBATCH --output=slurm_files/slurm-lvn-%A_%3a-%x.out
# TODO don't know where MSAs are for new indices: [0, 1, 11, 20, 24, 25, 33] (full benchmark indices: [ 1  3 29 51 57 58 75])
#SBATCH --array=0-37,100-137,200-237,300-337,400-437%1          		# 37 rows in DeepSeq subset, 81 DMSs in total benchmark
##SBATCH --array=112                   # Just checking a few examples
#SBATCH --hold  # Holds job so that we can first check the first few

################################################################################

set -e # fail fully on first line failure (from Joost slurm_for_ml)

# Note: Remember to clear ~/.theano cache before running this script, otherwise jobs eventually start crashing while compiling theano

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

# Note: using modified DeepSeq mapping file.
export dms_mapping=/n/groups/marks/users/lood/DeepSequence_runs/DMS_mapping_deepseq_20220109.csv  # From /home/pn73/protein_transformer/utils/mapping_files/DMS_mapping_20220109.csv
export dms_input_folder=/n/groups/marks/projects/marks_lab_and_oatml/protein_transformer/DMS/DMS_Benchmarking_Dataset_20220109
# Remember to create this folder before run:
export dms_output_folder=/n/groups/marks/users/lood/DeepSequence_runs/model_scores_02_28_msa_original/ #/n/groups/marks/projects/marks_lab_and_oatml/protein_transformer/model_scores/MSA_transformer
#export msa_path=/n/groups/marks/projects/marks_lab_and_oatml/protein_transformer/MSA/tkmer_20220109
export msa_path=/n/groups/marks/users/lood/DeepSequence_runs/pascal_deepseq_alignments_dir  # Original DeepSequence MSA: /n/groups/marks/projects/marks_lab_and_oatml/protein_transformer/MSA/deepsequence/
export model_checkpoint_dir=/n/groups/marks/users/lood/DeepSequence_runs/params_02_28_msa_original/  # TODO rsync to keep the params_02_28_msa_original folder up to date

# Monitor GPU usage (store outputs in ./gpu_logs/)
/home/lov701/job_gpu_monitor.sh --interval 1m gpu_logs &

srun stdbuf -oL -eL /n/groups/marks/users/aaron/deep_seqs/deep_seqs_env/bin/python \
  /n/groups/marks/users/lood/DeepSequence_runs/run_muteff_pred_seqs_batch.py \
  --dms_mapping $dms_mapping \
  --dms_input_dir $dms_input_folder \
  --dms_output_dir $dms_output_folder \
  --msa_path $msa_path \
  --model_checkpoint $model_checkpoint_dir \
  --dms_index $DATASET_ID \
  --samples 2000 \
  --seed "$SEED" \
  --msa_use_uniprot  # Workaround for old MSAs, where the mapping file doesn't contain the MSA filepaths
#  --theta-override 0.9
