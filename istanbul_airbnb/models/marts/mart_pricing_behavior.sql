-- Fiyatlama Davranışı, Dinamik Minimum Gece ve Manzara Primi Mart Tablosu (mart_pricing_behavior):
-- Projenin 1. ana sorusu ("Dinamik vs statik fiyatlama ve manzara/olanak farkları geliri nasıl etkiliyor?")
-- için oda tipi, fiyatlama davranışı, dinamik minimum gece kuralı ve manzara kategorisine göre performans metriklerini özetler.

with base as (

    select
        room_type,
        coalesce(mar_to_jun_pricing_behavior, '5) Yeni Ilan (Martta Yok)') as pricing_behavior_group,
        coalesce(has_dynamic_min_nights, false) as has_dynamic_min_nights_flag,
        view_category,
        has_water_view,
        has_city_skyline_view,
        price,
        price_capped_30k,
        price_change_pct_mar26_to_jun26,
        has_active_occupancy_l365d,
        estimated_occupancy_l365d,
        estimated_revenue_l365d,
        closed_day_rate_in_window,
        review_scores_rating
    from {{ ref('dim_listing') }}

)

select
    concat(
        room_type, '_',
        pricing_behavior_group, '_',
        cast(has_dynamic_min_nights_flag as string), '_',
        view_category
    ) as pricing_behavior_key,
    room_type,
    pricing_behavior_group as mar_to_jun_pricing_behavior,
    has_dynamic_min_nights_flag as has_dynamic_min_nights,
    view_category,
    has_water_view,
    has_city_skyline_view,

    count(*) as listings_count,
    round(avg(price_capped_30k), 0) as avg_price_capped_tl,
    round(approx_quantiles(price, 100)[offset(50)], 0) as median_price_tl,
    round(avg(price_change_pct_mar26_to_jun26), 2) as avg_price_change_pct_mar_to_jun,

    round(avg(if(has_active_occupancy_l365d, 1.0, 0.0)) * 100.0, 1) as active_occupancy_listings_pct,
    round(approx_quantiles(if(has_active_occupancy_l365d, estimated_occupancy_l365d, null), 100)[offset(50)], 0) as median_active_occupancy_days,
    round(approx_quantiles(if(estimated_revenue_l365d > 0, estimated_revenue_l365d, null), 100)[offset(50)], 0) as median_active_revenue_l365d_tl,
    round(avg(closed_day_rate_in_window) * 100.0, 1) as avg_closed_day_rate_in_window_pct,
    round(avg(review_scores_rating), 2) as avg_rating

from base
group by 1, 2, 3, 4, 5, 6, 7
