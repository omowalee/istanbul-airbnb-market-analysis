-- Semt x Oda Tipi KPI Özeti (mart_neighbourhood_kpis):
-- Haziran 2026 aktif kısa dönem havuzundaki ilanları (neighbourhood, room_type) düzeyinde özetler
-- ve stg_neighbourhoods ile birleştirerek ilçe yüzölçümü (area_km2), km2 başına ilan yoğunluğu (listings_per_km2),
-- yaka (Avrupa/Anadolu) ve harita poligonu (neighbourhood_geom) alanlarını ekler.

with kpis as (

    select
        concat(neighbourhood, '_', room_type) as neighbourhood_room_key,
        snapshot_date,
        neighbourhood,
        room_type,

        -- İlan ve Host Hacmi
        count(*) as listings_count,
        round(count(*) * 100.0 / sum(count(*)) over (partition by room_type), 2) as share_within_room_type_pct,
        count(distinct host_id) as distinct_hosts_count,
        round(avg(if(host_segment = '4) Profesyonel (21+ ilan)', 1.0, 0.0)) * 100.0, 1) as professional_host_share_pct,

        -- Konum
        round(avg(min_center_km), 2) as avg_dist_to_center_km,

        -- Fiyat Dağılımı (TL)
        round(avg(price_capped_30k), 0) as avg_price_capped_tl,
        round(approx_quantiles(price, 100)[offset(25)], 0) as p25_price_tl,
        round(approx_quantiles(price, 100)[offset(50)], 0) as median_price_tl,
        round(approx_quantiles(price, 100)[offset(75)], 0) as p75_price_tl,

        -- Doluluk, Takvim ve Yıllık Gelir
        round(avg(if(has_active_occupancy_l365d, 1.0, 0.0)) * 100.0, 1) as active_occupancy_listings_pct,
        round(approx_quantiles(if(has_active_occupancy_l365d, estimated_occupancy_l365d, null), 100)[offset(50)], 0) as median_active_occupancy_days,
        round(approx_quantiles(if(estimated_revenue_l365d > 0, estimated_revenue_l365d, null), 100)[offset(50)], 0) as median_active_revenue_l365d_tl,
        round(sum(coalesce(estimated_revenue_l365d, 0)), 0) as total_estimated_revenue_l365d_tl,
        round(avg(closed_day_rate_in_window) * 100.0, 1) as avg_closed_day_rate_in_window_pct,

        -- Kalite ve Puan
        round(avg(review_scores_rating), 2) as avg_rating,
        round(approx_quantiles(review_scores_rating, 100)[offset(50)], 2) as median_rating,

        -- İzin Belgesi ve Olanak Oranları (%)
        round(avg(if(license_status = 'istanbul_tekil', 1.0, 0.0)) * 100.0, 1) as istanbul_single_license_pct,
        round(avg(if(license_status in ('istanbul_tekil', 'istanbul_ayni_host_coklu', 'istanbul_farkli_host_paylasilan'), 1.0, 0.0)) * 100.0, 1) as istanbul_any_license_pct,
        round(avg(if(has_water_view, 1.0, 0.0)) * 100.0, 1) as water_view_listings_pct,
        round(avg(if(has_elevator, 1.0, 0.0)) * 100.0, 1) as elevator_listings_pct,
        round(avg(if(is_hotel_like_unit, 1.0, 0.0)) * 100.0, 1) as hotel_like_units_pct

    from {{ ref('dim_listing') }}
    group by snapshot_date, neighbourhood, room_type

)

select
    k.*,
    n.city_side,
    n.area_km2,
    round(safe_divide(k.listings_count, n.area_km2), 2) as listings_per_km2,
    n.centroid_longitude,
    n.centroid_latitude,
    n.neighbourhood_geom
from kpis k
left join {{ ref('stg_neighbourhoods') }} n
    on k.neighbourhood = n.neighbourhood
