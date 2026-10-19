# İstanbul Airbnb Projesi

Inside Airbnb İstanbul verisiyle analytics engineering portföy projesi: ham veri (BigQuery) → dbt Core (staging → intermediate → marts) → Looker Studio → README. Sahibi: Numan. Ayrıntılı geçmiş, bulgular ve sayılar: `docs/AGENT_HANDOFF_istanbul_airbnb.md`. Sadece ihtiyaç olunca aç, her oturumda baştan okuma.

## Çalışma kuralları

1. `venv/` ve `data/` klasörlerini listeleme, arama ya da okuma. dbt projesi `istanbul_airbnb/` içinde, scriptler `scripts/` içinde.
2. Numan öğrenerek ilerliyor. Hazır kod yığma; her komutun, sorgunun ya da modelin ne yaptığını kısaca anlat, hataları birlikte oku. Bir seferde tek adım ver.
3. "Fikir alışverişi" denirse önce seçenekleri tartış; onay gelmeden dosya üretme ya da repoda değişiklik yapma.
4. Türkçe konuş (teknik terimler İngilizce kalabilir). Doğrudan ve net ol; bir şey yanlışsa söyle.
5. Devir notunda "doğrulanmadı" diye işaretli şeyleri doğrulanmış gibi anlatma, önce kontrol et.
6. `main`'e doğrudan push yok; her iş için ayrı dal, sonra Pull Request.
7. Ortam: Windows 11, PowerShell, VS Code. Paket kurarken `python -m pip install ...` kalıbını kullan. Bağlantı bazen yavaş; uzun indirmelerde haber ver.
8. Ham veriye (`istanbul_airbnb_raw`) dbt ile yazma. dbt çıktıları kişisel dataset'e gider.
9. Terminal komutlarını çalıştırmadan önce ne yapacağını söyle. `gcloud`, IAM/izin değişikliği, tablo/dataset silme ya da üzerine yazma (`DROP`, `DELETE`, `LOAD DATA OVERWRITE`, `git push --force`) gibi geri dönüşü zor komutları **onay almadan çalıştırma**.
10. Gizli bilgi (servis hesabı JSON'u, anahtar, token) dosyaya yazma, commit etme ya da bana yapıştırtma.

## Altyapı özeti

- GCP projesi `istanbul-airbnb`, her şey **EU** bölgesinde (dataset, bucket, dbt `location`).
- Ham dataset `istanbul_airbnb_raw`: `raw_{listings|calendar|reviews}_{YYYYMMDD}`, 4 snapshot (20250929, 20251230, 20260331, 20260630), auto-detect şema ile yüklendi.
- dbt Core 1.12.5 + dbt-bigquery 1.12.1, oauth (gcloud ADC). `profiles.yml` proje dışında: `C:\Users\numan\.dbt\profiles.yml`. Dataset adı kararı açık: `dbt_write` mi `dbt_numan` mı.
- Repo: `github.com/omowalee/istanbul-airbnb-market-analysis` (public). Arkadaş dbt Cloud ile katılıyor (subdirectory `istanbul_airbnb`, Fusion olmayan sürüm).

## Veri kararları (kısa)

- **Analiz havuzu (2026-06-30):** `source = 'city scrape'`, `minimum_nights <= 30`, `price IS NOT NULL`, `room_type IN ('Entire home/apt','Private room')`, teklif süresi ≤ 30 gece. Sonuç 14.886 ilan. Tek modelde: `int_active_short_term_listings`.
- **Mart 2026 kısmi snapshot** (14 bin ilan). Pazar büyüklüğü analizlerinden çıkar, ilan bazlı analizde kullanılabilir.
- **Fiyat:** `price` `$` ile görünür ama TL. 2026'da ölçüm yöntemi değişti; dönemsel fiyat karşılaştırması **yalnızca Mart–Haziran 2026**.
- **Kolon tipleri snapshot'lar arasında tutarsız** (price: INT64/STRING/FLOAT64). Staging'de her snapshot önce metne çevrilip tek kuralla temizlenir, `UNION ALL` ile birleştirilir. Wildcard tablo adı backtick içinde olmalı.
- **Takvimde fiyat yok;** `available=false` rezervasyon demek değil. Kapalı gün oranı ilanın kendi takvim penceresi (3/6/9/12 ay) içinde hesaplanır.
- **Lisans:** "sahte" ya da "kaçak" denmez; "izin numarası alanında tutarsızlık" denir. Öncesi-sonrası (yasa etkisi) kanıtlanamaz, veri Eylül 2025'te başlıyor.
- **Yorum büyümesi** oran olarak sunulur (survivorship bias, ~%20 kayıp); mutlak sayı verilmez.

## Sıradaki işler

1. `git status` ile repo ve klasör yapısını kontrol et, özetle.
2. `profiles.yml` dataset adını netleştir, `dbt debug` çalıştır.
3. `staging-models` dalı: `models/example/` sil, `sources.yml` yaz, `stg_listings`'i birlikte, parça parça kur.
4. Devir notundaki 4. bölümdeki bekleyen keşif sorgularının sonuçlarını iste.
