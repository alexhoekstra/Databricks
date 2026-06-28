# terraform.tfvars
domains = {
  wc = {
    source_type = "kaggle"
    source_config = {
      repo = "swaptr/fifa-wc-2026-teams"
      filenames = [{name="teams.csv", table = "wc_teams_bronze"}]
    }
    target_catalog = "main"
    schedule = "0 0 14 * * ?"
    sp = "auto_ingest_sp"
    mode = "overwrite"
    wheel_version = "0.1.1"
  }
  arc_challenge = {
    source_type = "hugging_face"
    source_config = {
      repo = "allenai/ai2_arc"
      filenames = [
        {name = "ARC-Challenge/test-00000-of-00001.parquet", table = "arc_test_bronze"},
        {name = "ARC-Challenge/train-00000-of-00001.parquet",table = "arc_train_bronze"}, 
        {name = "ARC-Challenge/validation-00000-of-00001.parquet", table = "arc_validation_bronze"},
        {name = "ARC-Challenge/*.parquet", table = "arc_merged_bronze"}]
    }
    target_catalog = "main"
    schedule = "0 0 14 * * ?"
    sp = "auto_ingest_sp"
    mode = "overwrite"
    wheel_version = "0.1.1"
  },
  stock_exchange_metrics = {
    source_type = "url_zip"
    source_config = {
      repo = "https://www.sec.gov/files/opa/data/market-structure/summary-metrics-exchange/metrics_by_exchange_q4_2025.zip"
      filenames = [
        {name = "*.csv", table = "summary_metrics_by_exchange_bronze"}]
      # SEC-compliant headers with proper identification
      headers   = {
        "User-Agent" = "testCompanyName testman@testCompanyName.com"
        "Accept-Encoding" = "gzip, deflate"
        "Host" = "www.sec.gov"
      }
    }
    target_catalog = "main"
    schedule = "0 0 14 * * ?"
    sp = "auto_ingest_sp"
    mode = "overwrite"
    wheel_version = "0.1.1"
  }
}