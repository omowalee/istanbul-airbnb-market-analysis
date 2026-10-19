-- Host Boyut Tablosu (dim_host):
-- Haziran 2026 (2026-06-30) aktif kısa dönem havuzundaki ev sahiplerinin (host)
-- portföy büyüklüğü, çalıştığı semt/lisans çeşitliliği ve hem toplam hem ilan başı gelir performansını içerir.

select
    host_id,
    snapshot_date,
    host_since,
    host_is_superhost,
    host_identity_verified,
    total_platform_listings_count,
    host_segment,
    active_short_term_listings_count,
    entire_home_listings_count,
    private_room_listings_count,
    distinct_neighbourhoods_count,
    primary_neighbourhood,
    distinct_license_numbers_count,
    primary_license_status,
    avg_listing_price,
    median_listing_price,
    avg_listing_rating,
    total_portfolio_reviews,
    total_portfolio_reviews_ltm,
    active_revenue_listings_count,
    avg_occupancy_days_l365d,
    median_active_occupancy_days_l365d,
    total_portfolio_revenue_l365d,
    avg_active_listing_revenue_l365d,
    median_active_listing_revenue_l365d
from {{ ref('int_host_portfolio') }}
where snapshot_date = '2026-06-30'
