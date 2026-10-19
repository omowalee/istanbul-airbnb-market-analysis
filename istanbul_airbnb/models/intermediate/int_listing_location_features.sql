-- Her (snapshot_date, listing_id) için:
-- 1. En yakın raylı sistem (Metro/Tramvay/Marmaray) istasyonunu, hattını ve mesafesini (metre) hesaplar (dbt seed: istanbul_rail_stations).
-- 2. İlan başlığındaki (listing_name) "Taksim / Sultanahmet / Boğaz" iddialarını gerçek koordinat mesafesiyle test eder (Başlık Abartısı / Clickbait Testi).

with pool as (

    select
        listing_snapshot_id,
        snapshot_date,
        listing_id,
        listing_name,
        neighbourhood,
        latitude,
        longitude,
        dist_taksim_km,
        dist_sultanahmet_km,
        min_center_km
    from {{ ref('int_active_short_term_listings') }}

),

stations as (

    select
        station_id,
        station_name,
        line_code,
        line_type,
        st_geogpoint(longitude, latitude) as station_geog
    from {{ ref('istanbul_rail_stations') }}

),

nearest_station_calc as (

    select
        p.listing_snapshot_id,
        array_agg(
            struct(
                s.station_name,
                s.line_code,
                s.line_type,
                round(st_distance(st_geogpoint(p.longitude, p.latitude), s.station_geog), 0) as dist_m
            )
            order by st_distance(st_geogpoint(p.longitude, p.latitude), s.station_geog) asc
            limit 1
        )[offset(0)] as nearest_rail
    from pool p
    cross join stations s
    group by p.listing_snapshot_id

),

title_claims as (

    select
        p.*,
        n.nearest_rail.station_name as nearest_rail_station,
        n.nearest_rail.line_code as nearest_rail_line,
        n.nearest_rail.line_type as nearest_rail_type,
        n.nearest_rail.dist_m as dist_nearest_rail_m,

        case
            when n.nearest_rail.dist_m <= 400 then '1) <= 400m (~5 dk yurume)'
            when n.nearest_rail.dist_m <= 800 then '2) 401-800m (~10 dk yurume)'
            when n.nearest_rail.dist_m <= 1500 then '3) 801-1500m (~15-20 dk)'
            else '4) > 1500m (Uzak / Aktarma)'
        end as rail_distance_band,

        -- Başlıkta geçen konum/manzara iddiaları
        regexp_contains(lower(coalesce(p.listing_name, '')), r'taksim|istiklal') as claims_taksim_in_title,
        regexp_contains(lower(coalesce(p.listing_name, '')), r'sultanahmet|hagia sophia|blue mosque|ayasofya') as claims_sultanahmet_in_title,
        regexp_contains(lower(coalesce(p.listing_name, '')), r'galata') as claims_galata_in_title,
        regexp_contains(lower(coalesce(p.listing_name, '')), r'bosphorus|bogaz|boğaz') as claims_bosphorus_in_title

    from pool p
    left join nearest_station_calc n
        on p.listing_snapshot_id = n.listing_snapshot_id

)

select
    *,
    -- Başlık Abartısı (Marketing vs Reality) Sınıflandırması
    case
        when claims_taksim_in_title and dist_taksim_km > 1.5 then '1) Abartili Baslik: Taksim (>1.5 km uzakta)'
        when claims_sultanahmet_in_title and dist_sultanahmet_km > 1.5 then '2) Abartili Baslik: Sultanahmet (>1.5 km uzakta)'
        when (claims_taksim_in_title and dist_taksim_km <= 1.5)
          or (claims_sultanahmet_in_title and dist_sultanahmet_km <= 1.5) then '3) Dogru Baslik: Merkeze Gercekten Yakin (<=1.5 km)'
        else '4) Baslikta Taksim/Sultanahmet Iddiasi Yok'
    end as title_location_claim_status,

    (
        (claims_taksim_in_title and dist_taksim_km > 1.5)
        or (claims_sultanahmet_in_title and dist_sultanahmet_km > 1.5)
    ) as is_title_location_exaggerated
from title_claims
