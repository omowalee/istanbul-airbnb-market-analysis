# İstanbul Airbnb Projesi: Agent Devir Notu

Bu belge, projenin şimdiye kadarki durumunu, kurulumu, veri keşfinde bulunan her şeyi ve sıradaki adımları içerir. Devam eden agent bunu baştan sona okuyup oradan ilerlemeli. Sayıların hepsi gerçek sorgu çıktılarından alındı; doğrulanmamış olanlar **(doğrulanmadı)** diye işaretli.

---

## 0. Kullanıcıyla çalışma şekli (önce bunu oku)

- Kullanıcı **Numan**, Türkçe konuşuyor; cevaplar Türkçe olmalı (teknik terimler İngilizce kalabilir).
- **Öğrenerek ilerlemek istiyor.** "Hazır kod ver, çalıştır" yaklaşımından açıkça rahatsız oldu. Her komutun/sorgunun ne yaptığını kısaca anlat, hataları birlikte oku (traceback'te asıl mesaj en alttaki satır gibi).
- **"Fikir alışverişi" dediğinde** önce seçenekleri tartışmak istiyor; onay vermeden bitmiş bir şey üretme.
- Sonuçları sorgu çıktısı olarak yapıştırıyor, ekran görüntüsü de atıyor. Adım adım, her seferinde bir şey istiyor.
- Windows 11, VS Code, PowerShell. İnternet bağlantısı zaman zaman çok yavaş (pip indirmeleri kopabiliyor).
- Hedef: Upwork / yabancı şirket remote data analytics. Bu proje **portföy projesi**; GitHub README'si ve LinkedIn yazısı olacak. Bu yüzden her bulgu "gerekçeli karar" olarak kaydedilmeli.
- Tonu doğrudan ve cesaretlendirici, ama abartısız. Yanlış bir şey söylediyse düzeltmekten çekinme.

---

## 1. Projenin amacı

**"İstanbul Kısa Dönem Kiralık Pazarı: Kim Kazanıyor, Neden?"** Inside Airbnb İstanbul verisiyle uçtan uca analytics engineering projesi: ham veri → BigQuery → dbt (staging → intermediate → marts) → Looker Studio panosu → README + LinkedIn vaka yazısı + kısa video.

Ana soru: bir ilanın gelirini ne belirliyor: konum, fiyatlama davranışı, host tipi, kalite, düzenleme?

Alt sorular:
1. Dinamik vs statik fiyatlama farkı büyük veride de geçerli mi? (eski Alaçatı analizindeki bulgunun testi)
2. Profesyonel hostlar bireysellerden daha mı iyi performans gösteriyor?
3. Toplu taşıma/merkeze yakınlık fiyatı ve doluluğu nasıl etkiliyor?
4. Lisans/izin durumu ve arz nasıl değişti (snapshot'lar arası)?
5. Düşük puanlı ilanlarda yorumlarda hangi şikayetler öne çıkıyor?

Bu proje, Numan'ın eski "Alaçatı/İzmir Airbnb fiyatlama" portföy projesinin devamı: o proje 500 ilan × 145 gün gibi küçük/sade bir veriye dayandığı için bırakıldı. Airbnb'yi kendin scrape etme fikri, kullanım şartlarını ihlal ettiği ve portföyde yayınlanacağı için **bilerek reddedildi**; açık lisanslı Inside Airbnb kullanılıyor.

---

## 2. Altyapı ve mevcut durum

### GCP
- Proje ID: **`istanbul-airbnb`** (Numan Owner).
- BigQuery dataset: **`istanbul_airbnb_raw`**, bölge **EU**. Ham veri burada, ona dokunulmaz (bkz. bölüm 6).
- Cloud Storage bucket: **`istanbul-airbnb-numan-raw`** (EU). Klasörler: `2025-09-29-raw/`, `2025-12-30-raw/`, `2026-03-31-raw/`, `2026-06-30-raw/`. Her birinde 7 dosya (`listings.csv.gz`, `calendar.csv.gz`, `reviews.csv.gz`, özet csv'ler, `neighbourhoods.geojson`).
- **EU/US bölge uyumsuzluğu** Numan'ı daha önce Greenweez projesinde uğraştırdı. Her şey EU'da kalmalı (dataset, bucket, dbt `location`).
- Cloud Storage'ta soft delete (7 gün) açık, versioning/retention kapalı.

### Ham tablolar (12 adet, BigQuery'de yüklü)
Adlandırma: `raw_{listings|calendar|reviews}_{YYYYMMDD}`. Yükleme `LOAD DATA OVERWRITE ... FROM FILES` ile GCS'ten yapıldı (`scripts/load_raw.sql`), **auto-detect şema** kullanıldı, `allow_quoted_newlines = TRUE` (listings ve reviews için şart: host_about gibi metinlerde satır sonu var).

| Snapshot | listings | calendar | reviews |
|---|---|---|---|
| 2025-09-29 | 30.051 | 10.968.564 | 544.606 |
| 2025-12-30 | 30.465 | 11.119.743 | 576.267 |
| 2026-03-31 | **14.340 (kısmi)** | 5.234.102 | 469.356 |
| 2026-06-30 | 26.631 | 9.720.288 | 580.909 |

Doğrulama: calendar satırı ≈ ilan × 365 (farklar birkaç düzine satır), yani yükleme eksiksiz.

**Henüz yüklenmeyen:** `raw_neighbourhoods` (geojson). BigQuery geojson'u doğrudan almıyor; `geojson_to_ndjson.py` scripti önerildi (her semt bir satır: `neighbourhood`, `geometry_json`), sonra JSONL olarak yükleyip `ST_GEOGFROMGEOJSON(geometry_json, make_valid => TRUE)` ile kullanılacak. **Çalıştırıldığı doğrulanmadı.**

### Repo
- GitHub: `github.com/omowalee/istanbul-airbnb-market-analysis` (**public**), ilk commit push edildi.
- Yerel yol: `C:\Users\numan\Desktop\istanbul-airbnb-market-analysis`
- Yapı (hedeflenen):
  ```
  .gitignore            (kökte; venv/, .venv/, data/, *.json, .env, logs/)
  scripts/              (load_insideairbnb.py [eski work.py], load_raw.sql, geojson_to_ndjson.py)
  istanbul_airbnb/      (dbt projesi; kendi .gitignore'u var: target/, dbt_packages/, logs/)
  data/raw/<tarih>/     (git'e gitmez)
  venv/
  ```
- Numan klasör taşıma adımlarını (work.py → scripts/) yaptı mı **doğrulanmadı**; `git status` ile kontrol et.
- `istanbul_airbnb/models/example/` dbt'nin örnek modelleri; **silinecek**.
- Kural: kimse doğrudan `main`'e push etmez; her iş ayrı dal + Pull Request.

### dbt
- **dbt Core 1.12.5 + dbt-bigquery 1.12.1** (venv içinde, Python 3.13). Arkadaş aynı sürümleri kuracak: `python -m pip install dbt-core==1.12.5 dbt-bigquery==1.12.1`.
- Kimlik doğrulama: **oauth** (gcloud `application-default login`), servis hesabı anahtarı yok.
- `profiles.yml`: `C:\Users\numan\.dbt\profiles.yml` (proje dışında, git'e girmez). `project: istanbul-airbnb`, `location: EU`, `threads: 4`, timeout 300.
- **`dbt debug` → "All checks passed!"** (bağlantı çalışıyor).
- **Açık nokta:** profiles.yml'deki `dataset` şu an **`dbt_write`** (Numan öyle yazmış; ilk başta yanlışlıkla `istanbul_airbnb_raw` yazmıştı ve düzeltti). Önerilen: `dbt_numan` (kişi adıyla, arkadaşla çakışmasın). Karar Numan'ın.
- Dataset mantığı: `istanbul_airbnb_raw` (kiler, dbt asla yazmaz) → `dbt_numan` / `dbt_abi` (kişisel geliştirme) → `istanbul_airbnb_prod` (ortak vitrin, main dalından; Looker Studio buraya bağlanacak, henüz yok).

### İşbirliği (bir arkadaş katılıyor)
- Arkadaş **dbt Cloud** kullanacak, Numan **dbt Core**; ikisi aynı repoyla çalışabilir.
- dbt Cloud ayarları: Project ID `istanbul-airbnb`, Location EU, development dataset `dbt_abi`, repo yukarıdaki, **Project subdirectory = `istanbul_airbnb`** (kritik), **Fusion olmayan** dbt sürümü (Greenweez'de Fusion sözdizimi sorunları yaşandı).
- dbt Cloud servis hesabı arkadaşın **kendi** GCP projesinde oluşturuluyor; Numan'ın projesine yalnızca servis hesabı e-postası eklenir (JSON anahtarı kimseyle paylaşılmaz).
- **Yetki durumu (yarım):**
  - Arkadaşın kişisel Gmail'i: proje seviyesinde BigQuery Data Viewer + Job User verildi. Konsolda projeyi görmesi için kendi Explorer'ında **+ Add → Star a project by name → `istanbul-airbnb`** yapması gerekiyor. "Veri gözükmüyor" sorunu bu yüzden çıktı, kesin çözüldüğü **doğrulanmadı**.
  - Servis hesabının `istanbul_airbnb_raw` üzerinde Data Editor + Data Viewer + BigQuery User yetkileri görünüyordu. Proje IAM'de servis hesabında **Job User yoktu** (dbt Cloud sorgu çalıştıramaz).
  - Numan en sonunda "ikisine de (servis hesabı ve Gmail) ham veride ve `dbt_abi`'de okuma+yazma verelim" dedi; riski kabul etti (ham dosyalar bucket'ta, `load_raw.sql` ile yeniden yüklenebilir, BigQuery time travel 7 gün).
  - **`dbt_abi` dataset'i henüz oluşturulmamıştı** (EU olarak açılmalı).
  - Numan'ın kendisinin servis hesabına ihtiyacı yok (oauth).

---

## 3. Veri keşfi: bulgular ve kararlar

### 3.1 Snapshot'lar
- Dört tarih: 2025-09-29, 2025-12-30, 2026-03-31, 2026-06-30.
- **Mart 2026 kısmi tarama.** İlan sayısı ~14 bin (diğerleri 27–30 bin). Mart ilanlarının %85,5'i Aralık'ta, %81,2'si Haziran'da da var. Normal geçiş referansı: Aralık ilanlarının %91,0'ı Eylül'de de var. Sonuç: örneklem genel olarak temsili, yeni ilanlara hafif kaymalı.
  **Karar:** Mart "kısmi snapshot" işaretlenir; pazar büyüklüğü / toplam ilan / arz değişimi analizlerinden çıkarılır; ilan bazlı analizlerde (fiyat, puan değişimi) kullanılabilir.
- Pazar-yapı soruları (dağılım, segment) **tek dönemle (2026-06-30)** yapılır; aynı ilanı 4 kez saymamak için dönemler toplanmaz. Değişim soruları dönemler yan yana, her biri ayrı hesaplanarak yapılır.

### 3.2 Analiz havuzu kuralları (2026-06-30)
1. `source = 'city scrape'` (bu turda gerçekten taranan, aktif ilan)
2. `minimum_nights <= 30`
3. `price IS NOT NULL`
4. `room_type IN ('Entire home/apt', 'Private room')` (Hotel room 309 ve Shared room 137 ilan: gürültü, çıkarıldı)
5. Teklif süresi ≤ 30 gece: `DATE_DIFF(price_quote_checkout_date, price_quote_checkin_date, DAY) <= 30`

Sonuç: **14.886 ilan** (11.070 tüm ev + 3.816 özel oda); 26.631'in ~%56'sı.
Bu kurallar dbt'de tek bir model olacak: `int_active_short_term_listings`. **Kural 5'in 2025 dönemlerinde uygulanamaz** (kolonlar yok); dbt'de "kolon varsa uygula".

Havuza giden yol:

| | Kısa dönem (≤30) | Uzun dönem (>30) |
|---|---|---|
| city scrape | 15.366 (fiyatı boş: 75) | 29 |
| previous scrape | 580 (fiyatı boş: 450) | 10.656 |

`source` pratikte "aktif kısa dönem ilan mı" göstergesi. Toplam: 15.395 city scrape, 2.688 fiyatı boş, 10.684 uzun dönem (%40).

Oda tipi (tüm 26.631): Entire home/apt 17.939 · Private room 8.246 · Hotel room 309 · Shared room 137. Havuzda tüm ev payı %74,4 (tüm veride %67,4): özel odalar daha sık pasife düşüyor/uzun döneme çevriliyor.

En çok ilan: Beyoğlu 7.254 · Fatih 3.771 · Şişli 3.587 · Kadıköy 1.938 · Beşiktaş 1.445 · Esenyurt 902 · Bahçelievler 653 · Üsküdar 608 · Kağıthane 526 · Bağcılar 453. İlk 5 semt pazarın ~%68'i, Beyoğlu tek başına %27. Esenyurt (6. sıra, merkeze çok uzak) farklı bir segment olabilir; merkez/çeper ayrımı düşünülecek.

### 3.3 Fiyat
- **`price` kolonu `$` ile gösteriliyor ama değerler TL** (`price_quote_raw` içinde `₺`). README'de ilk not.
- **Fiyat üretim yöntemi:** 2026'da Inside Airbnb fiyatı sahte rezervasyon teklifinden hesaplıyor (`price_quote_*` kolonları). Uzun minimum geceli ilanlarda teklif aylık fiyat üzerinden alınıp gece sayısına bölünüyor → gecelik fiyat yaklaşık 5× düşük çıkıyor (ör. Ortaköy 1+1: ₺691 gösteriliyor, gerçek ~₺2.300–2.800). Havuzda teklif >30 gece olanlar: 8 ilan (6 tüm ev, medyan ₺880 vs ₺4.691; 2 özel oda, ₺633 vs ₺2.993). **Karar:** 8 ilan için JSON ayrıştırmak yerine kural 5 ile çıkar.
- **Havuz medyan gecelik fiyat (Haziran 2026, TL):** tüm ev **4.691**, özel oda **2.993** (tüm evin %64'ü; normalde bu oran çok daha düşük olurdu, özel odaların bir kısmı otel/pansiyon odası olabilir; test: `calculated_host_listings_count_private_rooms`, "Non-real estate listing" ile çaprazlama).
- **Dönemler arası fiyat karşılaştırılamıyor.** `price` tipleri: Eylül INT64, Aralık STRING, Mart/Haziran FLOAT64. Aynı ilanlarda Eylül→Mart fiyatı tüm evlerde ~×2 (ör. 4.258→8.532; 2.878→6.784), özel odalarda ~×0,8–0,9. Mart→Haziran %0–30 (makul). **Karar:** dönemsel fiyat karşılaştırması **yalnızca Mart–Haziran 2026**.
- **Aralık 2025'te `price` tamamen boş görünüyor** (20 örnek satırda hepsi null; kolonun STRING yüklenmesinin sebebi bu olabilir). Kesin doğrulama sorgusu verilmişti ama sonucu **doğrulanmadı**: `SELECT price, COUNT(*) FROM raw_listings_20251230 GROUP BY 1` (null / boş metin / başka format).
- Bekleyen iki kontrol sorgusu (sonuçları alınmadı): her dönemde fiyatı dolu ilan sayısı (UNION ALL ile), Eylül→Haziran aynı ilanlarda fiyat oranı medyanı oda tipine göre.
- `estimated_occupancy_l365d` ve `estimated_revenue_l365d` Inside Airbnb'nin hazır tahminleri (son 12 ay); gelir hesabında kullanılacak (takvimde fiyat yok).

### 3.4 Yasa eşiği: minimum 100 gece
7464 sayılı Kanun (Resmi Gazete 2 Kasım 2023, yürürlük 1 Ocak 2024): konutların turizm amaçlı (tek seferde en fazla 100 gün) kiralanması Kültür ve Turizm Bakanlığı izin belgesine bağlı; 100 günü aşan kiralamalar kapsam dışı. İzin belgesi örnekleri vergi dairesine gönderiliyor. (Numan'ın "100 gün ve üzerine vergi indirimi" sezgisi kanunla ilgili çıktı; asıl nokta izin eşiği.)

Tüm 26.631 ilanda minimum gece dağılımı:

| Grup | İlan |
|---|---|
| 1–30 | 15.946 |
| 31–99 | 42 |
| **tam 100** | **9.776 (%36,7)** |
| 101–180 | 601 |
| 180+ | 265 |
| boş | 1 |

Pazar ikiye bölünmüş (ya ≤30 ya da 100). "previous scrape" uzun dönem ilanlarda minimum gece hep tam 100. Teknik not: kanun "en fazla 100 gün" diyor, yani tam 100 hâlâ kapsam içinde. **Sınır:** veri Eylül 2025'te başlıyor, yasa 2024'te geldi → "yasadan sonra ilanlar kaçtı" öncesi-sonrası kanıtı **yapılamaz**; bugünkü pazarın izi betimlenir. Bunu README'de açıkça yaz.

### 3.5 Lisans (`license`) kolonu
Kısa dönem (`minimum_nights <= 30`, 15.946 ilan) kategorileri (regex'lerle):

| Kategori | İlan | Farklı numara | Numara başı |
|---|---|---|---|
| izin_belgesi `^\d{2}-\d+$` (ör. 34-421) | 9.513 | 4.034 | 2,4 |
| yil_formatli `^\d{4}-\d{2}-\d+$` (ör. 2022-34-1339) | 2.122 | 536 | 4,0 |
| konut_disi ("Non-real estate listing") | 2.044 | 1 | |
| sadece_rakam (ör. 18744) | 1.627 | 409 | 4,0 |
| diger | 325 | 194 | 1,7 |
| muaf ("Exempt") | 205 | 1 | |
| bos / None | 110 | | |

- `yil_formatli + sadece_rakam + konut_disi` = 5.793 ilan (%36): çok birimli ticari işletme (otel, apart) deseni. "Evini kiralayan sıradan vatandaş" imajının arkasında büyük ticari katman var.
- İzin formatlı numaraların paylaşımı: 2.484 numara tek ilanda · 837 numara aynı hostun çok ilanında (3.127 ilan) · **713 numara farklı hostların ilanlarında (3.902 ilan, %41)**.
- En çok paylaşılan: **`12-3456` 147 ilan / 61 host** (sıralı rakamlar, yer tutucu/örnek numara); `34-1476` 189 ilan / 9 host (yönetim şirketi deseni); `00-9775` (geçersiz il kodu); `51-2728` (başka il kodu).
- İl kodu önek dağılımı: **34 = 7.344 ilan**, 12 = 533, 22 = 157, 13 = 146, 14 = 110 ... toplam **91 farklı önek** (geçerli il kodu 81; `00`, `83`, `92`, `99` gibi geçersizler var). 10–25 arası küçük önekler il kodu değil, yıl kısaltması / yer tutucu / uydurma olabilir.
- Manşet: kısa dönem ilanların **%46'sında (7.344)** İstanbul formatında (`34-`) izin numarası var.
- **Dil kuralı:** "sahte izin / vergi kaçıran" **denmez**. Doğru çerçeve: "izin numarası alanında veri kalitesi ve tutarsızlık"; platformdaki beyanların resmi kayıtlarla doğrulanamadığı. Yönetim şirketleri/co-hosting meşru olabilir.
- dbt izin etiketleri taslağı: `istanbul_tekil`, `istanbul_paylasilan`, `yer_tutucu`, `dogrulanamayan` (NN-NNNN ama 34 değil), `isletme_belgesi`, `konut_disi`, `muaf`, `bos`, `diger`. (Regex'te `$` sonu önemli: kalıp sıkılaşınca 9.741 → 9.513 oldu.)
- Önemli: kısa dönem ilanların %99,3'ünde lisans alanı dolu görünüyordu; "alan dolu" ≠ "izin var".

### 3.6 Takvim (`raw_calendar_*`)
- Kolonlar yalnızca: `listing_id`, `date`, `available` (BOOL), `minimum_nights`, `maximum_nights`. **Fiyat kolonu yok.** Günlük fiyat analizi yapılamaz.
- `available = false` ≠ rezervasyon (host kapatmış olabilir). Metrik adı "doluluk" değil **"kapalı gün oranı"** olmalı. (Örnek: ilan 25436, Bebek, min 100, tüm günler false.)
- **Takvim penceresi artefaktı:** hostlar takvimlerini 3/6/9/12 ay ileriye açık tutuyor. Havuzda her ilanın son müsait gününün ayı: 2026-09 → 763 · 2026-12 → 1.070 · 2027-03 → 1.559 · 2027-06/07 → 10.530 (%71); komşu aylarda 40–190. Uzak ayların "kapalı oranı" (Ocak %19,5 → Nisan–Haziran 2027 %30) rezervasyon değil, pencere ayarı. **Karar:** kapalı gün oranı ilanın **kendi penceresi** içinde hesaplanır (`int_listing_calendar_window`). Takvim yalnızca yakın dönem için güvenilir sinyal.
- Aylık kapalı gün oranı (havuz, ilk/son yarım aylar hariç): Tem 2026 %30,3 → Ağu 16,0 → Eyl 12,3 → Eki 13,8 → Kas 12,5 → Ara 14,1 → Oca 19,5 → ... → Haz 2027 30,6.
- Takvimdeki `minimum_nights` **güne özel** (host belirli tarihe farklı kural koyabiliyor). Genel kuralın üstüne çıkan ilan oranı: **Cuma–Cumartesi her ay hafta içinden 1–1,5 puan yüksek**; sezon dalgası: Ağu–Eki %12,2–12,6 (hafta içi) / 13,3–14,0 (Cum–Cmt), Şubat dip (%10,8 / 11,8). Yorum sezonuyla aynı aylar → **üçgenleme**. (Sıradan günlerde bile ~%11 yüksek görünmesi: listings'teki değerin sadece "bugünün" kuralı olmasından olabilir; farklara bakıldığı için sonucu etkilemiyor.)

### 3.7 Yorumlar ve sezon
- Yorum sayısı yıllara göre (ay bazında) net sezon: **Şubat en düşük** (2025'te ortalamanın ~%69'u), **Eylül–Ekim zirve** (Ekim ~%128), Nisan–Mayıs ikinci güçlü dönem. Yaz zayıf (şehir turizmi; Alaçatı'nın tersi: bu karşıtlık anlatıda kullanılabilir).
- Büyüme: 2024/2023 ≈ +%36, 2025/2024 ≈ +%36, 2026 Oca–May / 2025 Oca–May ≈ +%35.
- **Survivorship bias:** Eylül 2025 snapshot'ında 2023: 102.763, 2024: 140.116 yorum; Haziran 2026 snapshot'ında 82.682 ve 112.669 → **~%19,5 kayıp** (platformdan ayrılan ilanların yorumları gidiyor). Kayıp iki yılda aynı oranda → **oranlar korunuyor**. **Karar:** büyüme "hâlâ aktif ilanların yorum hacmindeki büyüme" olarak sunulur; mutlak sayı verilmez. Haziran/Temmuz 2026 yarım aylar (yorum gecikmesi) dışarıda bırakılır.

### 3.8 Olanaklar (`amenities`) ve manzara primi
- `amenities` metin olarak saklanmış JSON dizisi: `UNNEST(JSON_EXTRACT_STRING_ARRAY(amenities))`. Çok sayıda marka/varyasyon var (Siemens refrigerator, "55 inch HDTV ..."), analizde **anahtar kelime grupları** kullan.
- Havuzdaki sıklıklar: Wifi %93,6 · Hair dryer %85 · Kitchen %75,1 (4 ilandan 1'inde mutfak yok) · Air conditioning %72 · Dedicated workspace %61 · Elevator %34,6 · Mini fridge %28 · Building staff %24 · Washer %51 · Exterior security cameras %45.
- Mutfaksız + mini buzdolabı + bina personeli = otel işareti olabilir (test edilecek).
- `view` olanakları: City skyline 1.887 · Sea 740 · Garden 531 · Courtyard 206 · Harbor 138 · Park 136 · Bay 135 · Mountain 108 · Marina 91 · Pool 88 · Canal 86 · Valley 81 · Beach 73 · River 38 · Lake 34 · Ocean 31 · Resort 8 · Vineyard 4 · Desert 1. **"Bosphorus view" seçeneği yok** (Airbnb sabit menü); Boğaz muhtemelen Canal/Sea/River. Desert/Vineyard gibi etiketler beyan, doğrulanmış bilgi değil.
- **Su manzarası primi** (tüm ev, 2–4 kişilik, aynı semt içinde medyan oranı; regex `(sea|harbor|bay|ocean|canal|river|beach|marina|lake) view`):

| Semt | Manzaralı | Manzarasız | Prim | Güvenilirlik |
|---|---|---|---|---|
| Beyoğlu | 183 | 2.798 | **1,46** | yüksek (manşet) |
| Fatih | 76 | 853 | 1,19 | iyi |
| Beşiktaş | 17 | 401 | 1,75 | düşük örneklem |
| Kadıköy | 20 | 558 | 1,09 | düşük örneklem |

  Sunum dili: "manzaralı evlerin aldığı fiyat farkı" (nedensellik iddiası yok; manzaralı evler daha lüks/yeni olabilir).
- Henüz yapılmadı: şehir silüeti primi (regex `city skyline view`), `HAVING` eşiğini 10'a düşürüp Sarıyer/Üsküdar'ı eklemek.

### 3.9 Kolon tipi tutarsızlıkları (dbt staging'in gerekçesi)
`INFORMATION_SCHEMA.COLUMNS` karşılaştırması (Eylül / Aralık / Mart / Haziran):

| Kolon | Tipler |
|---|---|
| price | INT64 / STRING / FLOAT64 / FLOAT64 |
| estimated_revenue_l365d | INT64 / STRING / INT64 / INT64 |
| host_since | DATE / STRING / STRING / STRING |
| host_total_listings_count | INT64 / STRING / STRING / STRING |
| instant_bookable | BOOL / STRING / STRING / STRING |
| host_profile_id, host_profile_url, hosts_time_as_{host,user}_{years,months} | Eylül'de yok, Aralık'tan itibaren var |
| price_quote_* (checkin/checkout date, price_per_night, raw, total_price) | yalnızca Mart ve Haziran |

Sonuç: wildcard (`raw_listings_*`) tip uyuşmazlığında hata verebilir. dbt staging'de her snapshot için kolonlar önce `CAST(... AS STRING)` / `SAFE_CAST` ile tek tipe getirilmeli, `UNION ALL` ile birleştirilmeli, `snapshot_date` `_TABLE_SUFFIX` ya da sabit değerden üretilmeli.

### 3.10 Diğer notlar
- Airbnb koordinatları gizlilik için ~150 m kaydırıyor: konum analizinde 500 m / 1 km bantları kullan.
- `neighbourhood` boş, **`neighbourhood_cleansed`** dolu.
- Veri kalitesi örnekleri: `bathrooms` genelde boş, `bathrooms_text` dolu ("1.5 baths"); `host_response_*`, `host_location` vb. sıkça boş.
- Host adları sadece keşif için bakılır; raporda bireysel kişi adı kullanılmaz.

---

## 4. Bekleyen sorgular ve yarım kalan işler

1. **Quick data profile** (BigQuery UI) arayüzü dondurdu → bırakıldı. Yerine SQL ile profilleme: kolon grupları halinde, `UNPIVOT` ile (bos_yuzde, farkli_deger, APPROX_TOP_COUNT). **Grup 1 (host kolonları) sorgusu verildi, sonuç alınmadı.** Sıradaki grup: mülk özellikleri (property_type, room_type, accommodates, bedrooms, beds, bathrooms_text), sonra puanlar, doluluk/gelir, olanaklar. Alternatif: Python/pandas profil scripti (`pip install pandas`, `listings.csv.gz` ile).
2. Merkeze uzaklık sorgusu (Taksim 28.9850/41.0369, Sultanahmet 28.9802/41.0086, `ST_GEOGPOINT(boylam, enlem)` sırası önemli) verildi, **sonucu görülmedi**.
3. Dört keşif sorgusu (fiyat dağılımı + uç değerler, host segmentleri, en büyük 15 host, puan grupları) verildi, sonuçlar **alınmadı**.
4. Dec 2025 fiyat doğrulaması ve Eylül→Haziran fiyat oranı sorguları (bkz. 3.3).
5. `raw_neighbourhoods` yüklemesi (bkz. bölüm 2).
6. İBB Açık Veri'den raylı sistem istasyonları (metro mesafesi analizi için) henüz alınmadı.
7. Arkadaşın erişim/`dbt_abi` kurulumu doğrulanacak.
8. `profiles.yml` dataset adı kararı (`dbt_write` vs `dbt_numan`).

### Fikir listesi (tartışıldı, çoğu yapılmadı)
- Yorum metninin alfabesinden turist profili (Arapça/Kiril/Latin), bayram dönemleriyle.
- Başlığında "Taksim/Sultanahmet" geçen ilanların gerçek mesafesi (abartı testi).
- Platformu kim terk ediyor: Eylül 2025'te olup Haziran 2026'da olmayan ilanlar (puan, lisans, oda tipi).
- Yer tutucu/uydurma izin numaralı ilanlar farklı mı davranıyor (fiyat, doluluk, puan)?
- Otel/konut dışı beyanlı işletmeler vs bireysel evler: gelir ve doluluk.
- Asansörün fiyat/puana etkisi, çalışma alanı (dijital göçebe) olanağı.
- Hostların minimum geceyi hangi tarihlerde yükselttiği (bayram/yılbaşı), talep proxy'si.

---

## 5. dbt yol haritası (sıradaki asıl iş)

Dal: `git checkout -b staging-models`. Önce `models/example/` sil.

1. **`sources.yml`**: 12 ham tablo (+ `raw_neighbourhoods`) tanıtılır; snapshot başına kaynak tablolar.
2. **Staging:** `stg_listings`, `stg_calendar`, `stg_reviews`, `stg_neighbourhoods`. Her snapshot için tip birleştirme (bkz. 3.9), `price` temizliği (ör. `SAFE_CAST(REPLACE(REPLACE(CAST(price AS STRING),'$',''),',','') AS FLOAT64)`), boolean düzeltmeleri, `bathrooms_text` ayrıştırma, `snapshot_date`, `is_partial_snapshot` (Mart), lisans kategorisi, `license_status`.
3. **Intermediate:** `int_active_short_term_listings` (havuz kuralları), `int_listing_calendar_window` (ilan başına pencere + pencere içi kapalı gün oranı), `int_listing_history` (ilan × snapshot, LAG ile değişimler), `int_host_portfolio` (bireysel / küçük 2–5 / orta 6–20 / profesyonel 21+), `int_listing_amenity_flags` (manzara, mutfak, asansör vb.), konum/mesafe modelleri.
4. **Marts:** `dim_listing`, `dim_host`, `dim_neighbourhood`, `fct_listing_nights`, `mart_neighbourhood_kpis`, `mart_pricing_behavior`, lisans/izin tutarlılık mart'ı.
5. **Testler:** `unique`, `not_null`, `relationships`, `accepted_values` (room_type), custom test (fiyat > 0), kaynak freshness gerekmiyor.
6. **Looker Studio** (4 sayfa): Pazar özeti · Fiyatlama · Host ve konum · Pazar değişimi. `istanbul_airbnb_prod`'a bağlanır.
7. **README:** Setup bölümü (arkadaş için kurulum), **Data Quality Notes**, Data Exploration özeti, sınırlar (öncesi-sonrası yok, fiyat dönemleri karşılaştırılamaz, survivorship bias).

### README "Data Quality Notes" maddeleri (hazır)
1. Mart snapshot'ı kısmi; pazar büyüklüğü analizlerinden çıkarıldı.
2. Minimum gece %36,7 oranında tam 100'de kümeleniyor (yasa eşiğinin izi).
3. Uzun konaklama tekliflerinde fiyat ~5× düşük hesaplanıyor; teklif süresi >30 gece olanlar çıkarıldı.
4. İzin numarası alanında yer tutucu, geçersiz il kodu ve paylaşılan numaralar var.
5. Takvim penceresi 3/6/9/12 ay; kapalı gün oranı ilanın kendi penceresinde hesaplanır.
6. Yorumlarda dokuz ayda ~%20 kayıp (survivorship); büyüme oran olarak sunulur.
7. Fiyat ölçüm yöntemi 2026'da değişti; dönemsel fiyat karşılaştırması yalnızca Mart–Haziran 2026.
8. `price` kolonu `$` işaretli ama TL; tipler snapshot'lar arasında tutarsız.

---

## 6. Teknik tuzaklar ve ipuçları (bu projede yaşananlar)

- **Wildcard tablo** adı backtick içinde olmalı: `` `istanbul_airbnb_raw.raw_reviews_*` ``; tam yolda proje adı tireli: `` `istanbul-airbnb.istanbul_airbnb_raw.raw_calendar_*` ``. `_TABLE_SUFFIX` ile dönem seçilir.
- `SELECT *` calendar'da ~300 MB tarar (ücretsiz 1 TB/ay kotasının çok altında ama alışkanlık: Preview sekmesi ücretsiz, sadece gereken kolonlar seçilmeli).
- BigQuery'de `DAYOFWEEK`: Pazar = 1, Cuma = 6, Cumartesi = 7.
- `ST_GEOGPOINT(boylam, enlem)`; `ST_DISTANCE` metre verir.
- Explorer panelinde tarih son ekli tablolar tek satırda gruplanır (sadece 3 tablo görünmesi normaldi; 12 tablo var). `__TABLES__` ile satır sayıları kontrol edilir.
- BigQuery arayüzü çok sayıda açık sekmeyle ağırlaşıyor (donma yaşandı); Chrome'da Shift+Esc ile bellek kontrolü, "Close all tabs".
- Windows'ta `python -m pip install ...` kalıbı kullan (`py` bazen venv dışı Python'u çalıştırıyor). VS Code'un yeni dosyayı seçili klasöre koyma huyu nedeniyle kökte `.gitignore` açarken terminalden `notepad .gitignore` kullanıldı.
- IAM: proje seviyesinde verilen rol tüm dataset'lere "miras" geçer; dataset penceresinde "Show inherited roles" anahtarı bunu gösterir. Projeler birbirinden bağımsız (Numan'ın diğer projeleri `data-analytics-469406`, `workintech-final` etc. bu izinlerden etkilenmez).
- Raw yükleme scripti (`load_insideairbnb.py`, tüm kolonlar STRING) yazıldı ama kullanılmadı; Numan dosyaları elle indirip bucket'a koydu, ham tablolar SQL `LOAD DATA` ile yüklendi. Auto-detect sorunları (tip tutarsızlığı) bu yüzden staging'de çözülecek. İstenirse ham katman tüm kolonlar STRING olacak şekilde yeniden yüklenebilir (daha sağlam).

---

## 7. İlk adım önerisi (agent için)

1. `git status` ve klasör yapısını kontrol et; `scripts/` düzenini tamamla.
2. `profiles.yml` dataset adını Numan'la netleştir (`dbt_numan` önerilir), `dbt debug` tekrar çalıştır.
3. `staging-models` dalını aç, `models/example/` sil, `sources.yml` yaz. Numan öğrenerek ilerlediği için ilk modeli (`stg_listings`) birlikte, parça parça yaz; her tip dönüşümünün gerekçesini bölüm 3.9'a bağla.
4. Paralelde yarım kalan keşif sorgularının (bölüm 4) sonuçlarını iste.
