""" Configuration driven auto-extractor to extract data from various sources"""
import argparse
import json
import os
import requests
import kagglehub
import zipfile
from huggingface_hub import snapshot_download

def extract_kaggle(config, landing):
    """ Downloads the dataset from kaggle at the given repo"""
    kagglehub.dataset_download(config["repo"], output_dir=landing)

def extract_hugging_face(config, landing):
    """ Downloads the files from hugging face at the given repo"""
    local_file_path = snapshot_download(
        repo_id=config["repo"],
        repo_type="dataset",
        local_dir=landing
    )
    print("files downloaded to: ", local_file_path)

def extract_url_zip(config, landing):
    """ Extracts zip file downloaded from the specified url in the config"""
    zip_url = config["repo"]
    print("Downloading zip file from URL: ", zip_url)
    timeout_config = (3.05, 300)
    zip_temp_path = os.path.join(landing, "temp_download.zip")
    headers = config.get("headers", {})

    with requests.get(zip_url, stream=True, timeout=timeout_config, headers=headers) as response:
        response.raise_for_status()
        with open(zip_temp_path, "wb") as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)

    with zipfile.ZipFile(zip_temp_path, "r") as zip_ref:
        zip_ref.extractall(landing)
    print("Done! Everything has been successfully extracted.")

def main():
    """ Wheel entry point """
    parser = argparse.ArgumentParser()
    parser.add_argument("--source_type", required=True)
    parser.add_argument("--source_config", required=True)
    parser.add_argument("--landing_path", required=True)
    args = parser.parse_args()
    
    source_type = args.source_type
    source_config = json.loads(args.source_config)
    landing_path = args.landing_path

    if source_type == "kaggle":
        extract_kaggle(source_config, landing_path)
    elif source_type == "hugging_face":
        extract_hugging_face(source_config, landing_path)
    elif source_type == "url_zip":
        extract_url_zip(source_config, landing_path)