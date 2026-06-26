""" 
Generic Extractor Notebook
Extracts data from various sources and loads into landing zone.
"""
import json
import kagglehub

source_type   = dbutils.widgets.get("source_type")
source_config = json.loads(dbutils.widgets.get("source_config"))
landing_path  = dbutils.widgets.get("landing_path")

def extract_kaggle(config, landing) :
    """Extracts data from a Kaggle dataset and downloads it to the specified landing path."""
    kagglehub.dataset_download(config["dataset"], output_dir=landing)   

def extract_hugging_face(config, landing) :
    """Extracts data from a Hugging Face dataset and downloads it to the specified landing path."""
    print("Hello")


if source_type == "kaggle":
    extract_kaggle(source_config, landing_path)
elif source_type == "hugging_face":
    extract_hugging_face(source_config, landing_path)
