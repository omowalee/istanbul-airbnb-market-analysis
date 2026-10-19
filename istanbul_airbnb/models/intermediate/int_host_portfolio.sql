-- Aktif kısa dönem havuzundaki (int_active_short_term_listings) ilanları (snapshot_date, host_id) düzeyinde özetler.
-- Host'un portföy büyüklüğünü, coğrafi yayılımını, izin belgesi yapısını ve hem toplam hem ilan başı performansını hesaplar.

select
    concat(cast(host_id as string), '_', cast(snapshot_date as string)) as host_snapshot_id,
    snapshot_date,
    is_partial_snapshot,
    host_id,
    any_value(host_name) as host_name,
    any_value(host_since) as host_since,
    any_value(host_is_superhost) as host_is_superhost,
    any_value(host_identity_verified) as host_identity_verified,
    max(calculated_host_listings_count) as total_platform_listings_count,
    any_value(host_segment) as host_segment,

    -- Aktif kısa dönem havuzundaki ilan dağılımı
    count(*) as active_short_term_listings_count,
    countif(room_type = 'Entire home/apt') as entire_home_listings_count,
    countif(room_type = 'Private room') as private_room_listings_count,

    -- Coğrafi ve lisans çeşitliliği
    count(distinct neighbourhood) as distinct_neighbourhoods_count,
    approx_top_count(neighbourhood, 1)[offset(0)].value as primary_neighbourhood,
    count(distinct license_trimmed) as distinct_license_numbers_count,
    approx_top_count(license_status, 1)[offset(0)].value as primary_license_status,

    -- Fiyat ve kalite metrikleri
    round(avg(price), 2) as avg_listing_price,
    round(approx_quantiles(price, 100)[offset(50)], 2) as median_listing_price,
    round(avg(review_scores_rating), 2) as avg_listing_rating,
    sum(number_of_reviews) as total_portfolio_reviews,
    sum(number_of_reviews_ltm) as total_portfolio_reviews_ltm,

    -- Doluluk ve gelir metrikleri (Toplam portföy vs İlan başı)
    countif(estimated_occupancy_l365d > 0) as active_revenue_listings_count,
    round(avg(estimated_occupancy_l365d), 1) as avg_occupancy_days_l365d,
    round(approx_quantiles(if(estimated_occupancy_l365d > 0, estimated_occupancy_l365d, null), 100)[offset(50)], 1) as median_active_occupancy_days_l365d,
    round(sum(coalesce(estimated_revenue_l365d, 0)), 0) as total_portfolio_revenue_l365d,
    round(avg(if(estimated_revenue_l365d > 0, estimated_revenue_l365d, null)), 0) as avg_active_listing_revenue_l365d,
    round(approx_quantiles(if(estimated_revenue_l365d > 0, estimated_revenue_l365d, null), 100)[offset(50)], 0) as median_active_listing_revenue_l365d

from {{ ref('int_active_short_term_listings') }}
group by snapshot_date, is_partial_snapshot, host_id
