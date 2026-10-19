-- Ana İlan Tablosu (dim_listing):
-- Haziran 2026 (2026-06-30) aktif kısa dönem havuzundaki 14.886 ilanın
-- konum, host segmenti, puan grubu, izin durumu, takvim penceresi, olanak/manzara bayrakları
-- ve Mart -> Haziran 2026 fiyat değişim davranışını tek bir fiziksel tabloda (TABLE) birleştirir.
-- Looker Studio panosunun ana veri kaynağıdır.

with active_pool as (

    select *
    from {{ ref('int_active_short_term_listings') }}
    where snapshot_date = '2026-06-30'

),

calendar_win as (

    select *
    from {{ ref('int_listing_calendar_window') }}
    where snapshot_date = '2026-06-30'

),

amenities as (

    select *
    from {{ ref('int_listing_amenity_flags') }}
    where snapshot_date = '2026-06-30'

),

history as (

    select *
    from {{ ref('int_listing_history') }}

),

loc_features as (

    select *
    from {{ ref('int_listing_location_features') }}
    where snapshot_date = '2026-06-30'

)

select
    -- 1. Kimlik ve Temel Bilgiler
    p.listing_id,
    p.snapshot_date,
    p.listing_name,
    p.neighbourhood,
    p.latitude,
    p.longitude,
    p.property_type,
    p.room_type,
    p.accommodates,
    p.bedrooms,
    p.beds,
    p.bathrooms_cleansed as bathrooms,
    p.instant_bookable,

    -- 2. Konum, Merkeze Uzaklık, Raylı Sistem ve Başlık Abartısı Testi
    p.dist_taksim_km,
    p.dist_sultanahmet_km,
    p.min_center_km,
    p.center_distance_band,
    lf.nearest_rail_station,
    lf.nearest_rail_line,
    lf.nearest_rail_type,
    lf.dist_nearest_rail_m,
    lf.rail_distance_band,
    lf.claims_taksim_in_title,
    lf.claims_sultanahmet_in_title,
    lf.claims_galata_in_title,
    lf.claims_bosphorus_in_title,
    lf.title_location_claim_status,
    lf.is_title_location_exaggerated,

    -- 3. Host ve Portföy Segmenti
    p.host_id,
    p.host_since,
    p.host_is_superhost,
    p.host_identity_verified,
    p.host_response_time,
    p.host_response_rate_pct,
    p.host_acceptance_rate_pct,
    p.calculated_host_listings_count,
    p.host_segment,

    -- 4. Fiyat, Minimum Gece ve Gelir/Doluluk Tahminleri
    p.price,
    -- Ortalamalarda aşırı uç değer etkisini önlemek için %99 eşiğinde (30.000 TL) kırpılmış fiyat
    least(p.price, 30000.0) as price_capped_30k,
    p.minimum_nights,
    p.maximum_nights,
    p.price_quote_nights,
    p.estimated_occupancy_l365d,
    (p.estimated_occupancy_l365d > 0) as has_active_occupancy_l365d,
    p.estimated_revenue_l365d,

    -- 5. Yorumlar ve Kalite (Puan Grubu)
    p.number_of_reviews,
    p.number_of_reviews_ltm,
    p.number_of_reviews_l30d,
    p.reviews_per_month,
    p.first_review,
    p.last_review,
    p.review_scores_rating,
    p.review_scores_cleanliness,
    p.review_scores_location,
    p.review_scores_value,
    p.rating_group,

    -- 6. İzin / Lisans Durumu
    p.license_trimmed as license_number,
    p.license_category,
    p.license_province_code,
    p.license_listing_count_in_snapshot,
    p.license_distinct_hosts_in_snapshot,
    p.license_status,

    -- 7. Takvim Penceresi ve Dinamik Minimum Gece (int_listing_calendar_window)
    c.window_days as calendar_window_days,
    c.calendar_window_bucket,
    c.closed_day_rate_in_window,
    c.closed_day_rate_next_30d,
    c.closed_day_rate_next_90d,
    c.has_dynamic_min_nights,
    c.avg_weekend_min_nights,
    c.avg_weekday_min_nights,

    -- 8. Olanaklar ve Manzara (int_listing_amenity_flags)
    a.amenities_count,
    a.has_water_view,
    a.has_city_skyline_view,
    a.has_green_view,
    a.view_category,
    a.has_wifi,
    a.has_kitchen,
    a.has_air_conditioning,
    a.has_elevator,
    a.has_dedicated_workspace,
    a.has_washer,
    a.has_parking,
    a.has_wellness_facility,
    a.has_self_checkin,
    a.has_mini_fridge,
    a.has_building_staff,
    a.is_hotel_like_unit,

    -- 9. Dönemsel Geçmiş ve Fiyatlama Davranışı (int_listing_history)
    h.snapshots_present_count,
    h.first_seen_snapshot,
    h.price_mar26,
    h.price_change_pct_mar26_to_jun26,
    h.mar_to_jun_pricing_behavior,
    h.reviews_gained_sep25_to_jun26

from active_pool p
left join calendar_win c
    on p.listing_snapshot_id = c.listing_snapshot_id
left join amenities a
    on p.listing_snapshot_id = a.listing_snapshot_id
left join history h
    on p.listing_id = h.listing_id
left join loc_features lf
    on p.listing_snapshot_id = lf.listing_snapshot_id
