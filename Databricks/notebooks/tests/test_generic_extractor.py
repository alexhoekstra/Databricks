""" Unit tests for ../modules/domain_batch_ingest"""
# pylint: disable=E0401
# pylint: disable=C0115
# pylint: disable=C0116
import io
import sys
import types
import zipfile
from pathlib import Path
from domain_batch_ingest import generic_extractor

MODULE_ROOT = Path(__file__).resolve().parents[1] / "modules" / "domain_batch_ingest" / "src"
if str(MODULE_ROOT) not in sys.path:
    sys.path.insert(0, str(MODULE_ROOT))

if "requests" not in sys.modules:
    requests_module = types.ModuleType("requests")
    requests_module.get = lambda *args, **kwargs: None  # type: ignore
    sys.modules["requests"] = requests_module

if "kagglehub" not in sys.modules:
    kagglehub_module = types.ModuleType("kagglehub")
    kagglehub_module.dataset_download = lambda *args, **kwargs: None  # type: ignore
    sys.modules["kagglehub"] = kagglehub_module

if "huggingface_hub" not in sys.modules:
    huggingface_module = types.ModuleType("huggingface_hub")
    huggingface_module.snapshot_download = lambda *args, **kwargs: None  # type: ignore
    sys.modules["huggingface_hub"] = huggingface_module




def test_extract_kaggle_calls_dataset_download(monkeypatch):
    calls = {}

    def fake_download(repo, output_dir):
        calls["repo"] = repo
        calls["output_dir"] = output_dir

    monkeypatch.setattr(generic_extractor.kagglehub, "dataset_download", fake_download)

    generic_extractor.extract_kaggle({"repo": "my-repo"}, "/tmp/out")

    assert calls == {"repo": "my-repo", "output_dir": "/tmp/out"}


def test_extract_hugging_face_calls_snapshot_download(monkeypatch, capsys):
    calls = {}

    def fake_snapshot_download(repo_id, repo_type, local_dir):
        calls["repo_id"] = repo_id
        calls["repo_type"] = repo_type
        calls["local_dir"] = local_dir
        return "/tmp/downloaded"

    monkeypatch.setattr(generic_extractor, "snapshot_download", fake_snapshot_download)

    generic_extractor.extract_hugging_face({"repo": "hf-repo"}, "/tmp/out")

    captured = capsys.readouterr()
    assert calls == {"repo_id": "hf-repo", "repo_type": "dataset", "local_dir": "/tmp/out"}
    assert "files downloaded to:" in captured.out


def test_extract_url_zip_downloads_and_extracts(tmp_path, monkeypatch):
    landing = tmp_path / "landing"
    landing.mkdir()

    payload = io.BytesIO()
    with zipfile.ZipFile(payload, "w") as archive:
        archive.writestr("example.txt", "hello from zip")

    class DummyResponse:
        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc, tb):
            return False

        def raise_for_status(self):
            return None

        def iter_content(self, chunk_size=8192):
            yield payload.getvalue()

    monkeypatch.setattr(generic_extractor.requests, "get", lambda *args, **kwargs: DummyResponse())

    generic_extractor.extract_url_zip({"repo": "https://example.com/archive.zip"}, str(landing))

    assert (landing / "example.txt").read_text() == "hello from zip"


def test_main_dispatches_to_selected_extractor(monkeypatch):
    calls = []

    monkeypatch.setattr(generic_extractor.argparse.ArgumentParser, "parse_args", 
                        lambda self: types.SimpleNamespace(
        source_type="kaggle",
        source_config='{"repo": "demo"}',
        landing_path="/tmp/landing",
    ))
    monkeypatch.setattr(generic_extractor, "extract_kaggle", lambda config, landing: calls.append(
        ("kaggle", config, landing)))

    generic_extractor.main()

    assert calls == [("kaggle", {"repo": "demo"}, "/tmp/landing")]
