# Basically a copy of the first part of run_svi.py, but not loading the model after calculating the weights
import os

import numpy as np
import pandas as pd
import time
import sys

sys.path.insert(0, "./DeepSequence/")
import helper
import argparse

parser = argparse.ArgumentParser(description="Calculating the weights and storing in weights_dir.")
parser.add_argument("--dataset", type=str, default="BLAT_ECOLX",
                    help="Dataset name for fitting model.")
parser.add_argument("--theta-override", type=float, default=None,
                    help="Override the model theta.")
# Keeping this different from weights_dir just so that we don't make mistakes and overwrite weights
parser.add_argument("--alignments_dir", type=str, help="Overrides the default ./datasets/alignments/")
parser.add_argument("--weights_dir_out", type=str, default="", help="Location to store weights.")
parser.add_argument("--mapping_file", type=str, help="Lood: A DMS mapping file with UniProt ID -> theta weight")
args = parser.parse_args()

# DataHelper expects the dataset name without extension
args.dataset = args.dataset.split(".a2m")[0]
assert not args.dataset.endswith(".a2m")

data_params = {
    "dataset": args.dataset,
    "weights_dir": args.weights_dir_out,
}

if __name__ == "__main__":
    start_time = time.time()

    if args.mapping_file:
        assert os.path.isfile(args.mapping_file), "Mapping file {} does not exist.".format(args.mapping_file)
        df_mapping = pd.read_csv(args.mapping_file)
        df_mapping = df_mapping.drop_duplicates(subset='UniProt_ID')
        # Find correct theta for UniProt_ID == protein_name
        # TODO Note: This fails for some of the MSA,weight pairs in the original DeepSeq dataset,
        #  since they don't have unique UniProt ids
        dataset_prefix = "_".join(args.dataset.split("_")[:2])
        assert dataset_prefix in df_mapping['UniProt_ID'].values, "Dataset prefix {} not found in mapping file.".format(dataset_prefix)
        theta = float(df_mapping[df_mapping["UniProt_ID"] == dataset_prefix]['theta'])

    data_helper = helper.DataHelper(dataset=data_params["dataset"],
                                    working_dir='.',
                                    theta=args.theta_override,
                                    weights_dir=data_params["weights_dir"],
                                    calc_weights=True,
                                    alignments_dir=args.alignments_dir,
                                    save_weights=True,
                                    )
    # write out what theta was used
    data_params['theta'] = data_helper.theta

    end_time = time.time()
    print("Done in " + str(time.time() - start_time) + " seconds")
