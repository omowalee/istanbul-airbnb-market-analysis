"""
Inside Airbnb Istanbul -> BigQuery yükleyici
Proje: istanbul-airbnb-market-analysis

Ne yapar:
  1. 4 snapshot için listings / calendar / reviews dosyalarını indirir (data/raw/<tarih>/)
  2. Her dosyayı BigQuery'ye tarih son ekli (date-sharded) tablo olarak yükler:
       raw_listings_20260630, raw_calendar_20260630, raw_reviews_20260630 ...
     Tüm kolonlar STRING olarak yüklenir; tip dönüşümü dbt staging'de yapılır.
  3. En güncel snapshot'ın neighbourhoods.geojson dosyasını raw_neighbourhoods tablosuna yükler.

dbt'de snapshot_date şöyle elde edilir:
  SELECT *, PARSE_DATE('%Y%m%d', _TABLE_SUFFIX) AS snapshot_date
  FROM `PROJE.istanbul_airbnb_raw.raw_listings_*`

Kullanım:
  pip install -r requirements.txt
  gcloud auth application-default login      (veya GOOGLE_APPLICATION_CREDENTIALS ile servis hesabı)
  python load_insideairbnb.py
"""

import csv
import gzip
import json
from pathlib import Path

import requests
from google.cloud import bigquery

# ---------------------------------------------------------------- AYARLAR
PROJECT_ID = "istanbul-airbnb"          # <-- kendi proje ID'n
DATASET = "istanbul_airbnb_raw"
LOCATION = "EU"                              # dbt bağlantısıyla AYNI olmalı

SNAPSHOTS = ["2025-09-29", "2025-12-30", "2026-03-31", "2026-06-30"]
BASE_URL = "https://data.insideairbnb.com/turkey/marmara/istanbul"
TABLES = ["listings", "calendar", "reviews"]

DATA_DIR = Path("data/raw")
MAX_BAD_RECORDS = 50                         # bozuk satır toleransı; log'da raporlanır
# ------------------------------------------------------------------------


def download(url: str, dest: Path) -> Path:
    """Dosya zaten varsa atlar, yoksa parça parça indirir."""
    if dest.exists() and dest.stat().st_size > 0:
        print(f"  ✓ zaten var: {dest}")
        return dest
    dest.parent.mkdir(parents=True, exist_ok=True)
    print(f"  ↓ indiriliyor: {url}")
    with requests.get(url, stream=True, timeout=120) as r:
        r.raise_for_status()
        tmp = dest.with_suffix(dest.suffix + ".part")
        with open(tmp, "wb") as f:
            for chunk in r.iter_content(chunk_size=1024 * 1024):
                f.write(chunk)
        tmp.rename(dest)
    print(f"  ✓ {dest} ({dest.stat().st_size / 1e6:.1f} MB)")
    return dest


def string_schema(gz_path: Path) -> list[bigquery.SchemaField]:
    """CSV başlığını okur, her kolonu STRING yapar."""
    with gzip.open(gz_path, "rt", encoding="utf-8", newline="") as f:
        header = next(csv.reader(f))
    return [bigquery.SchemaField(col.strip(), "STRING") for col in header]


def load_csv_gz(client: bigquery.Client, gz_path: Path, table_id: str) -> None:
    job_config = bigquery.LoadJobConfig(
        source_format=bigquery.SourceFormat.CSV,
        skip_leading_rows=1,
        schema=string_schema(gz_path),
        allow_quoted_newlines=True,          # açıklama/yorum metinlerinde satır sonu var
        max_bad_records=MAX_BAD_RECORDS,
        write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,
        encoding="UTF-8",
    )
    with open(gz_path, "rb") as f:
        job = client.load_table_from_file(f, table_id, job_config=job_config)
    job.result()
    table = client.get_table(table_id)
    bad = len(job.errors or [])
    print(f"  ✓ {table_id}: {table.num_rows:,} satır" + (f"  (⚠ {bad} hata kaydı)" if bad else ""))


def load_geojson(client: bigquery.Client, geo_path: Path, table_id: str) -> None:
    """Her semt bir satır: neighbourhood + geometry_json (dbt'de ST_GEOGFROMGEOJSON ile çevrilir)."""
    with open(geo_path, encoding="utf-8") as f:
        features = json.load(f)["features"]
    rows = [
        {
            "neighbourhood": feat["properties"].get("neighbourhood"),
            "neighbourhood_group": feat["properties"].get("neighbourhood_group"),
            "geometry_json": json.dumps(feat["geometry"]),
        }
        for feat in features
    ]
    job_config = bigquery.LoadJobConfig(
        schema=[
            bigquery.SchemaField("neighbourhood", "STRING"),
            bigquery.SchemaField("neighbourhood_group", "STRING"),
            bigquery.SchemaField("geometry_json", "STRING"),
        ],
        write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,
    )
    client.load_table_from_json(rows, table_id, job_config=job_config).result()
    print(f"  ✓ {table_id}: {len(rows)} semt")


def main() -> None:
    client = bigquery.Client(project=PROJECT_ID, location=LOCATION)

    dataset = bigquery.Dataset(f"{PROJECT_ID}.{DATASET}")
    dataset.location = LOCATION
    client.create_dataset(dataset, exists_ok=True)
    print(f"Dataset hazır: {PROJECT_ID}.{DATASET} ({LOCATION})\n")

    for snap in SNAPSHOTS:
        suffix = snap.replace("-", "")
        print(f"=== Snapshot {snap} ===")
        for name in TABLES:
            url = f"{BASE_URL}/{snap}/data/{name}.csv.gz"
            local = download(url, DATA_DIR / snap / f"{name}.csv.gz")
            load_csv_gz(client, local, f"{PROJECT_ID}.{DATASET}.raw_{name}_{suffix}")
        print()

    latest = SNAPSHOTS[-1]
    print("=== Semt sınırları ===")
    geo = download(
        f"{BASE_URL}/{latest}/visualisations/neighbourhoods.geojson",
        DATA_DIR / latest / "neighbourhoods.geojson",
    )
    load_geojson(client, geo, f"{PROJECT_ID}.{DATASET}.raw_neighbourhoods")

    print("\nBitti ✅")


if __name__ == "__main__":
    main()