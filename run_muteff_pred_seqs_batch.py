import argparse
import os
import time
import sys

import numpy as np
import pandas as pd

sys.path.insert(0, "./DeepSequence/")
import model
import helper
import train

model_params = {
    "bs"                :   100,
    "encode_dim_zero"   :   1500,
    "encode_dim_one"    :   1500,
    "decode_dim_zero"   :   100,
    "decode_dim_one"    :   2000,  # 500 in repo
    "n_latent"          :   30,
    "logit_p"           :   0.001,
    "sparsity"          :   "logit",
    "final_decode_nonlin":  "sigmoid",
    "final_pwm_scale"   :   True,
    "n_pat"             :   4,
    "r_seed"            :   12345,
    "conv_pat"          :   True,
    "d_c_size"          :   40
    }


def create_parser():
    parser = argparse.ArgumentParser(description="Calculate DeepSequence mutation effect predictions.")
    # parser.add_argument("--alignment", type=str, required=True, default="datasets/alignments/BLAT_ECOLX_1_b0.5.a2m",
    #                     help="Alignment file")
    # parser.add_argument("--mutants", type=str, required=True, default="datasets/mutations/BLAT_ECOLX_Ranganathan2015_BLAT_ECOLX_hmmerbit_plmc_vae_hmm_results.csv",
    #                     help="Table of mutants to predict")
    # parser.add_argument("--output", type=str, required=True, default="calc_muteff/output/BLAT_ECOLX_output.csv",
    #                     help="Output file location")
    # parser.add_argument("--colname", type=str, default="mutation_effect_prediction",
    #                     help="Output mutation effect column name")
    parser.add_argument("--samples", type=int, default=2000,
                        help="Number of prediction iterations")
    parser.add_argument("--alphabet_type", type=str, default="protein", help="Specify alphabet type")

    # New arguments
    parser.add_argument("--dms_input_dir", type=str, required=True)
    parser.add_argument("--dms_output_dir", type=str, required=True)
    parser.add_argument("--msa_path", type=str, required=True)
    parser.add_argument("--dms_index", type=int, required=True)
    parser.add_argument("--model_checkpoint", type=str, required=True)
    parser.add_argument("--dms_mapping", type=str, required=True)
    parser.add_argument("--weights_dir", type=str)
    parser.add_argument("--seed", type=int)
    return parser


def main(args):
    # Load the deep mutational scan
    # if args.dms_index is not None:
    assert os.path.isdir(args.model_checkpoint), "Model checkpoint directory does not exist:"+args.model_checkpoint
    assert args.dms_index is not None, "Must specify a dms index"
    assert os.path.isfile(args.dms_mapping), "Mapping file does not exist:"+args.dms_mapping
    assert os.path.isdir(args.dms_input_dir), "DMS input directory does not exist:"+args.dms_input_dir
    assert os.path.isdir(args.dms_output_dir), "DMS output directory does not exist:"+args.dms_output_dir
    if args.weights_dir is not None:
        assert os.path.isdir(args.weights_dir), "Weights directory specified but does not exist:"+args.weights_dir

    if seed is not None:
        print("Using seed:", seed)

    DMS_phenotype_name, dms_input, dms_output, msa_path, mutant_col, sequence = get_dms_mapping(args)

    data_helper = helper.DataHelper(alignment_file=msa_path,
                                    working_dir='.',
                                    calc_weights=False,
                                    alphabet_type=args.alphabet_type,
                                    weights_dir=data_params["weights_dir"],
                                    )
    assert sequence != data_helper.focus_seq_trimmed, "Sequence in DMS file does not match sequence in MSA file"

    print("Using MSA path as model prefix: "+msa_path)
    # TODO rather read in params from file
    # inference for each model
    # TODO this may be unnecessary since we override the seed below anyway
    if args.seed is not None:
        model_params['r_seed'] = args.seed

    vae_model   = model.VariationalAutoencoder(data_helper,
        batch_size                     =   model_params["bs"],
        encoder_architecture           =   [model_params["encode_dim_zero"],
                                                model_params["encode_dim_one"]],
        decoder_architecture           =   [model_params["decode_dim_zero"],
                                                model_params["decode_dim_one"]],
        n_latent                       =   model_params["n_latent"],
        logit_p                        =   model_params["logit_p"],
        sparsity                       =   model_params["sparsity"],
        encode_nonlinearity_type       =   "relu",
        decode_nonlinearity_type       =   "relu",
        final_decode_nonlinearity      =   model_params["final_decode_nonlin"],
        final_pwm_scale                =   model_params["final_pwm_scale"],
        conv_decoder_size              =   model_params["d_c_size"],
        convolve_patterns              =   model_params["conv_pat"],
        n_patterns                     =   model_params["n_pat"],
        random_seed                    =   model_params["r_seed"],
    )

    print ("Model built")
    dataset_name = msa_path.split('.a2m')[0].split('/')[-1]
    vae_model.load_parameters(file_prefix="dataset-"+str(dataset_name), seed=args.seed)

    print ("Parameters loaded\n\n")
    
    #custom_matr_mutant_name_list, custom_matr_delta_elbos =\
    data_helper.custom_mutant_matrix_df(
        input_filename=dms_input,
        model=vae_model,
        mutant_col=mutant_col,
        effect_col=DMS_phenotype_name,
        N_pred_iterations=args.samples,
        output_filename_prefix=dms_output,
        silent_allowed=True,
    )

    # df.to_csv(args.dms_output)


def get_dms_mapping(args):
    mapping_protein_seq_DMS = pd.read_csv(args.dms_mapping)
    DMS_id = mapping_protein_seq_DMS["DMS_id"][args.dms_index]
    print("Compute scores for DMS: " + str(DMS_id))
    sequence = mapping_protein_seq_DMS["target_seq"][mapping_protein_seq_DMS["DMS_id"] == DMS_id].values[0].upper()
    dms_input = os.path.join(args.dms_input_dir, mapping_protein_seq_DMS["DMS_filename"][
        mapping_protein_seq_DMS["DMS_id"] == DMS_id].values[0])
    assert os.path.isfile(dms_input), "DMS input file not found" + dms_input
    print("DMS input file: " + dms_input)
    if "DMS_mutant_column" in mapping_protein_seq_DMS.columns:
        mutant_col = mapping_protein_seq_DMS["DMS_mutant_column"][mapping_protein_seq_DMS["DMS_id"] == DMS_id].values[0]
    else:
        print("DMS_mutant_column not found in mapping file, using mutant")
        mutant_col = "mutant"
    DMS_phenotype_name = \
    mapping_protein_seq_DMS["DMS_phenotype_name"][mapping_protein_seq_DMS["DMS_id"] == DMS_id].values[0]
    print("DMS mutant column: " + mutant_col)
    print("DMS phenotype name: " + DMS_phenotype_name)
    dms_output = os.path.join(args.dms_output_dir, DMS_id)  # Only the prefix, as the file will have _samples etc
    msa_path = os.path.join(args.msa_path,
                            mapping_protein_seq_DMS["MSA_filename"][mapping_protein_seq_DMS["DMS_id"] == DMS_id].values[
                                0])  # msa_path is expected to be the path to the directory where MSAs are located.
    assert os.path.isfile(msa_path), "MSA file not found: " + msa_path
    print("MSA file: " + msa_path)
    target_seq_start_index = mapping_protein_seq_DMS["start_idx"][mapping_protein_seq_DMS["DMS_id"] == DMS_id].values[
        0] if "start_idx" in mapping_protein_seq_DMS.columns else 1
    target_seq_end_index = target_seq_start_index + len(sequence)
    # msa_start_index = mapping_protein_seq_DMS["MSA_start"][mapping_protein_seq_DMS["DMS_id"]==DMS_id].values[0] if "MSA_start" in mapping_protein_seq_DMS.columns else 1
    # msa_end_index = mapping_protein_seq_DMS["MSA_end"][mapping_protein_seq_DMS["DMS_id"]==DMS_id].values[0] if "MSA_end" in mapping_protein_seq_DMS.columns else len(args.sequence)
    # if (target_seq_start_index!=msa_start_index) or (target_seq_end_index!=msa_end_index):
    #     args.sequence = args.sequence[msa_start_index-1:msa_end_index]
    #     target_seq_start_index = msa_start_index
    #     target_seq_end_index = msa_end_index
    # df = pd.read_csv(args.dms_input)
    # df,_ = DMS_file_cleanup(df, target_seq=args.sequence, start_idx=target_seq_start_index, end_idx=target_seq_end_index, DMS_mutant_column=mutant_col, DMS_phenotype_name=DMS_phenotype_name)
    # else:
    #     df = pd.read_csv(args.dms_input)
    return DMS_phenotype_name, dms_input, dms_output, msa_path, mutant_col, sequence


if __name__ == "__main__":
    parser = create_parser()
    args = parser.parse_args()
    print("args:", args)
    start_time = time.time()
    main(args)
    print("Done in " + str(time.time() - start_time) + " seconds")

