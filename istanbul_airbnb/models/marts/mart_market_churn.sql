-- Pazar Göçü ve Churn Analizi Mart Tablosu (mart_market_churn):
-- Fikir 4: Eylül 2025 (2025-09-29) snapshot'ında var olan 30.051 ilanın
-- 9 ay sonra Haziran 2026 (2026-06-30) snapshot'ındaki akıbetini (Kısa dönemde kaldı, 100+ gün uzun döneme geçti,
-- pasife düştü veya platformdan tamamen silindi) semt, oda tipi, host segmenti ve puan grubuna göre özetler.

with sep25_base as (

    select
        listing_id,
        neighbourhood,
        room_type,
        minimum_nights as sep25_minimum_nights,
        source as sep25_source,
        price as sep25_price,
        license_category as sep25_license_category,
        case
            when calculated_host_listings_count = 1 then '1) Bireysel (1 ilan)'
            when calculated_host_listings_count between 2 and 5 then '2) Kucuk (2-5 ilan)'
            when calculated_host_listings_count between 6 and 20 then '3) Orta (6-20 ilan)'
            else '4) Profesyonel (21+ ilan)'
        end as sep25_host_segment,
        case
            when review_scores_rating is null then '5) Puansiz (0 yorum)'
            when review_scores_rating >= 4.80 then '1) 4.80-5.00 (Mukemmel)'
            when review_scores_rating >= 4.50 then '2) 4.50-4.79 (Iyi)'
            when review_scores_rating >= 4.00 then '3) 4.00-4.49 (Orta)'
            else '4) < 4.00 (Dusuk)'
        end as sep25_rating_group,
        case
            when source = 'city scrape' and minimum_nights <= 30 then '1) Aktif Kisa Donem (<=30 gece)'
            when minimum_nights >= 100 then '2) Yasa Esigi Uzun Donem (100+ gece)'
            else '3) Diger / Pasif Ilan'
        end as sep25_initial_status
    from {{ ref('stg_listings') }}
    where snapshot_date = '2025-09-29'

),

jun26_base as (

    select
        listing_id,
        minimum_nights as jun26_minimum_nights,
        source as jun26_source,
        price as jun26_price,
        license_category as jun26_license_category
    from {{ ref('stg_listings') }}
    where snapshot_date = '2026-06-30'

),

transition as (

    select
        s.*,
        j.listing_id is not null as still_on_platform_jun26,
        case
            when j.listing_id is null then '4) Platformdan Tamamen Silindi (Churn)'
            when j.jun26_source = 'city scrape' and j.jun26_minimum_nights <= 30 then '1) Aktif Kisa Donemde Kaldi (<=30 gece)'
            when j.jun26_minimum_nights >= 100 then '2) 100+ Gun Uzun Doneme Gecti/Kaldi'
            else '3) Pasife Dustu (previous scrape / 31-99 gece)'
        end as jun26_outcome_status
    from sep25_base s
    left join jun26_base j
        on s.listing_id = j.listing_id

)

select
    concat(
        neighbourhood, '_',
        room_type, '_',
        sep25_initial_status, '_',
        sep25_host_segment, '_',
        sep25_rating_group, '_',
        jun26_outcome_status
    ) as churn_cohort_key,
    neighbourhood,
    room_type,
    sep25_initial_status,
    sep25_host_segment,
    sep25_rating_group,
    jun26_outcome_status,
    count(*) as listings_count,
    round(avg(sep25_price), 0) as avg_sep25_price_tl
from transition
group by 1, 2, 3, 4, 5, 6, 7
