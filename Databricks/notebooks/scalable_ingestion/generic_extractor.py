""" 
Generic Extractor Notebook
Extracts data from various sources and loads into landing zone.
"""
import zipfile
import json
import os
import requests
import kagglehub
from huggingface_hub import snapshot_download

source_type   = dbutils.widgets.get("source_type")
source_config = json.loads(dbutils.widgets.get("source_config"))
landing_path  = dbutils.widgets.get("landing_path")

def extract_kaggle(config, landing):
    """Extracts data from a Kaggle dataset and downloads it to the specified landing path."""
    kagglehub.dataset_download(config["repo"], output_dir=landing)   

def extract_hugging_face(config, landing):
    """Extracts data from a Hugging Face dataset and downloads it to the specified landing path."""
    local_file_path = snapshot_download(
        repo_id=config["repo"],
        repo_type="dataset",
        local_dir=landing
    )
    print("files downloaded to: ", local_file_path)

def extract_url_zip(config, landing):
    """Extracts data from a URL pointing to a ZIP file, 
    and downloads and unzips it to the specified landing path."""

    zip_url = config["repo"]
    print("Downloading zip file from URL : ", zip_url)

    # 3.05s to connect, 300s to stream data chunks
    timeout_config = (3.05, 300)
    zip_temp_path = os.path.join(landing, "temp_download.zip")

    # Add comprehensive headers to identify the request as a legitimate browser
    headers = source_config.get("headers", {})
    
    with requests.get(zip_url, stream=True, timeout=timeout_config, headers=headers) as response:
        response.raise_for_status()
        with open(zip_temp_path, "wb") as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)

    with zipfile.ZipFile(zip_temp_path, "r") as zip_ref:
        zip_ref.extractall(landing)
    print("Done! Everything has been successfully extracted.")


if source_type == "kaggle":
    extract_kaggle(source_config, landing_path)
elif source_type == "hugging_face":
    extract_hugging_face(source_config, landing_path)
elif source_type == "url_zip":
    extract_url_zip(source_config, landing_path)
