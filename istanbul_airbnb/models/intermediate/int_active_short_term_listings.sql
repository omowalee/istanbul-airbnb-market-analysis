-- Aktif kısa dönem kiralık ilan havuzu (Analiz Havuzu).
-- Kurallar (Bölüm 3.2):
--   1. source = 'city scrape' (aktif taranan ilan)
--   2. minimum_nights <= 30 (kısa dönem)
--   3. price IS NOT NULL (fiyatı olan; not: Aralık 2025'te tüm fiyatlar NULL olduğu için bu havuzda yer almaz)
--   4. room_type IN ('Entire home/apt', 'Private room') (Hotel room ve Shared room gürültüsü çıkarıldı)
--   5. price_quote_nights IS NULL OR price_quote_nights <= 30 (2026'da >30 gecelik sahte tekliflerden gelen ~5x düşük fiyatlı 8 ilan çıkarıldı)

with filtered_pool as (

    select *
    from {{ ref('stg_listings') }}
    where source = 'city scrape'
      and minimum_nights <= 30
      and price is not null
      and room_type in ('Entire home/apt', 'Private room')
      and (price_quote_nights is null or price_quote_nights <= 30)

),

license_sharing as (

    select
        *,
        -- Aynı snapshot içinde bu lisans numarasını kullanan toplam ilan ve farklı host sayısı
        count(*) over (partition by snapshot_date, license_trimmed) as license_listing_count_in_snapshot,
        count(distinct host_id) over (partition by snapshot_date, license_trimmed) as license_distinct_hosts_in_snapshot,

        -- Taksim (28.9850, 41.0369) ve Sultanahmet (28.9802, 41.0086) kuş uçuşu mesafeleri (km)
        round(
            st_distance(
                st_geogpoint(longitude, latitude),
                st_geogpoint(28.9850, 41.0369)
            ) / 1000.0,
            2
        ) as dist_taksim_km,
        round(
            st_distance(
                st_geogpoint(longitude, latitude),
                st_geogpoint(28.9802, 41.0086)
            ) / 1000.0,
            2
        ) as dist_sultanahmet_km
    from filtered_pool

),

enriched as (

    select
        *,
        -- İki merkezden (Taksim / Sultanahmet) hangisine daha yakınsa o mesafe (km)
        least(dist_taksim_km, dist_sultanahmet_km) as min_center_km,

        -- Merkeze uzaklık bandı
        case
            when least(dist_taksim_km, dist_sultanahmet_km) <= 1.0 then '1) 0-1 km'
            when least(dist_taksim_km, dist_sultanahmet_km) <= 3.0 then '2) 1-3 km'
            when least(dist_taksim_km, dist_sultanahmet_km) <= 5.0 then '3) 3-5 km'
            when least(dist_taksim_km, dist_sultanahmet_km) <= 10.0 then '4) 5-10 km'
            else '5) 10+ km'
        end as center_distance_band,

        -- Host portföy segmenti (calculated_host_listings_count bazında)
        case
            when calculated_host_listings_count = 1 then '1) Bireysel (1 ilan)'
            when calculated_host_listings_count between 2 and 5 then '2) Kucuk (2-5 ilan)'
            when calculated_host_listings_count between 6 and 20 then '3) Orta (6-20 ilan)'
            else '4) Profesyonel (21+ ilan)'
        end as host_segment,

        -- Değerlendirme puanı grubu (4.50 eşiği analizi için)
        case
            when review_scores_rating is null then '5) Puansiz (0 yorum)'
            when review_scores_rating >= 4.80 then '1) 4.80-5.00 (Mukemmel)'
            when review_scores_rating >= 4.50 then '2) 4.50-4.79 (Iyi)'
            when review_scores_rating >= 4.00 then '3) 4.00-4.49 (Orta)'
            else '4) < 4.00 (Dusuk)'
        end as rating_group,

        -- Detaylı izin/lisans durumu (Bölüm 3.5 dil kurallarına uygun: "sahte/kaçak" denmez, veri tutarlılığı sınıflandırılır)
        case
            when license_category in ('bos', 'muaf', 'konut_disi', 'diger') then license_category
            when license_category in ('yil_formatli', 'sadece_rakam') then 'isletme_belgesi'
            when license_trimmed in ('12-3456', '12-345', '12-34567', '00-0000')
              or license_province_code = '00' then 'yer_tutucu'
            when license_category = 'izin_belgesi' and license_province_code != '34' then 'dogrulanamayan_il_kodu'
            when license_category = 'izin_belgesi' and license_province_code = '34' and license_listing_count_in_snapshot = 1 then 'istanbul_tekil'
            when license_category = 'izin_belgesi' and license_province_code = '34' and license_distinct_hosts_in_snapshot = 1 then 'istanbul_ayni_host_coklu'
            when license_category = 'izin_belgesi' and license_province_code = '34' and license_distinct_hosts_in_snapshot > 1 then 'istanbul_farkli_host_paylasilan'
            else 'diger'
        end as license_status

    from license_sharing

)

select * from enriched
