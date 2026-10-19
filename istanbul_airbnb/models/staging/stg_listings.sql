-- Parça 1: 4 snapshot tablosunu tip uyuşmazlıklarını gidererek (STRING üzerinden) UNION ALL ile birleştiriyoruz.
-- Parça 2 (cleaned CTE'si): Bir sonraki adımda eklenecek.

with raw_unioned as (

    -- 1) 2025-09-29 Snapshot
    select
        date '2025-09-29' as snapshot_date,
        false as is_partial_snapshot,
        id as listing_id,
        name as listing_name,
        source,
        last_scraped,
        host_id,
        host_name,
        cast(host_since as string) as host_since_raw,
        host_location,
        host_response_time,
        host_response_rate,
        host_acceptance_rate,
        host_is_superhost,
        host_listings_count,
        cast(host_total_listings_count as string) as host_total_listings_count_raw,
        host_has_profile_pic,
        host_identity_verified,
        neighbourhood_cleansed as neighbourhood,
        latitude,
        longitude,
        property_type,
        room_type,
        accommodates,
        bathrooms,
        bathrooms_text,
        bedrooms,
        beds,
        amenities,
        cast(price as string) as price_raw,
        minimum_nights,
        maximum_nights,
        cast(null as date) as price_quote_checkin_date,
        cast(null as date) as price_quote_checkout_date,
        cast(null as float64) as price_quote_total_price,
        cast(null as float64) as price_quote_price_per_night,
        cast(null as string) as price_quote_raw,
        has_availability,
        availability_30,
        availability_60,
        availability_90,
        availability_365,
        number_of_reviews,
        number_of_reviews_ltm,
        number_of_reviews_l30d,
        number_of_reviews_ly,
        estimated_occupancy_l365d,
        cast(estimated_revenue_l365d as string) as estimated_revenue_l365d_raw,
        first_review,
        last_review,
        review_scores_rating,
        review_scores_accuracy,
        review_scores_cleanliness,
        review_scores_checkin,
        review_scores_communication,
        review_scores_location,
        review_scores_value,
        license,
        cast(instant_bookable as string) as instant_bookable_raw,
        calculated_host_listings_count,
        calculated_host_listings_count_entire_homes,
        calculated_host_listings_count_private_rooms,
        calculated_host_listings_count_shared_rooms,
        reviews_per_month
    from {{ source('istanbul_airbnb_raw', 'raw_listings_20250929') }}

    union all

    -- 2) 2025-12-30 Snapshot
    select
        date '2025-12-30' as snapshot_date,
        false as is_partial_snapshot,
        id as listing_id,
        name as listing_name,
        source,
        last_scraped,
        host_id,
        host_name,
        cast(host_since as string) as host_since_raw,
        host_location,
        host_response_time,
        host_response_rate,
        host_acceptance_rate,
        host_is_superhost,
        host_listings_count,
        cast(host_total_listings_count as string) as host_total_listings_count_raw,
        host_has_profile_pic,
        host_identity_verified,
        neighbourhood_cleansed as neighbourhood,
        latitude,
        longitude,
        property_type,
        room_type,
        accommodates,
        bathrooms,
        bathrooms_text,
        bedrooms,
        beds,
        amenities,
        cast(price as string) as price_raw,
        minimum_nights,
        maximum_nights,
        cast(null as date) as price_quote_checkin_date,
        cast(null as date) as price_quote_checkout_date,
        cast(null as float64) as price_quote_total_price,
        cast(null as float64) as price_quote_price_per_night,
        cast(null as string) as price_quote_raw,
        has_availability,
        availability_30,
        availability_60,
        availability_90,
        availability_365,
        number_of_reviews,
        number_of_reviews_ltm,
        number_of_reviews_l30d,
        number_of_reviews_ly,
        estimated_occupancy_l365d,
        cast(estimated_revenue_l365d as string) as estimated_revenue_l365d_raw,
        first_review,
        last_review,
        review_scores_rating,
        review_scores_accuracy,
        review_scores_cleanliness,
        review_scores_checkin,
        review_scores_communication,
        review_scores_location,
        review_scores_value,
        license,
        cast(instant_bookable as string) as instant_bookable_raw,
        calculated_host_listings_count,
        calculated_host_listings_count_entire_homes,
        calculated_host_listings_count_private_rooms,
        calculated_host_listings_count_shared_rooms,
        reviews_per_month
    from {{ source('istanbul_airbnb_raw', 'raw_listings_20251230') }}

    union all

    -- 3) 2026-03-31 Snapshot (Kısmi tarama: ~14 bin ilan)
    select
        date '2026-03-31' as snapshot_date,
        true as is_partial_snapshot,
        id as listing_id,
        name as listing_name,
        source,
        last_scraped,
        host_id,
        host_name,
        cast(host_since as string) as host_since_raw,
        host_location,
        host_response_time,
        host_response_rate,
        host_acceptance_rate,
        host_is_superhost,
        host_listings_count,
        cast(host_total_listings_count as string) as host_total_listings_count_raw,
        host_has_profile_pic,
        host_identity_verified,
        neighbourhood_cleansed as neighbourhood,
        latitude,
        longitude,
        property_type,
        room_type,
        accommodates,
        bathrooms,
        bathrooms_text,
        bedrooms,
        beds,
        amenities,
        cast(price as string) as price_raw,
        minimum_nights,
        maximum_nights,
        price_quote_checkin_date,
        price_quote_checkout_date,
        price_quote_total_price,
        price_quote_price_per_night,
        price_quote_raw,
        has_availability,
        availability_30,
        availability_60,
        availability_90,
        availability_365,
        number_of_reviews,
        number_of_reviews_ltm,
        number_of_reviews_l30d,
        number_of_reviews_ly,
        estimated_occupancy_l365d,
        cast(estimated_revenue_l365d as string) as estimated_revenue_l365d_raw,
        first_review,
        last_review,
        review_scores_rating,
        review_scores_accuracy,
        review_scores_cleanliness,
        review_scores_checkin,
        review_scores_communication,
        review_scores_location,
        review_scores_value,
        license,
        cast(instant_bookable as string) as instant_bookable_raw,
        calculated_host_listings_count,
        calculated_host_listings_count_entire_homes,
        calculated_host_listings_count_private_rooms,
        calculated_host_listings_count_shared_rooms,
        reviews_per_month
    from {{ source('istanbul_airbnb_raw', 'raw_listings_20260331') }}

    union all

    -- 4) 2026-06-30 Snapshot
    select
        date '2026-06-30' as snapshot_date,
        false as is_partial_snapshot,
        id as listing_id,
        name as listing_name,
        source,
        last_scraped,
        host_id,
        host_name,
        cast(host_since as string) as host_since_raw,
        host_location,
        host_response_time,
        host_response_rate,
        host_acceptance_rate,
        host_is_superhost,
        host_listings_count,
        cast(host_total_listings_count as string) as host_total_listings_count_raw,
        host_has_profile_pic,
        host_identity_verified,
        neighbourhood_cleansed as neighbourhood,
        latitude,
        longitude,
        property_type,
        room_type,
        accommodates,
        bathrooms,
        bathrooms_text,
        bedrooms,
        beds,
        amenities,
        cast(price as string) as price_raw,
        minimum_nights,
        maximum_nights,
        price_quote_checkin_date,
        price_quote_checkout_date,
        price_quote_total_price,
        price_quote_price_per_night,
        price_quote_raw,
        has_availability,
        availability_30,
        availability_60,
        availability_90,
        availability_365,
        number_of_reviews,
        number_of_reviews_ltm,
        number_of_reviews_l30d,
        number_of_reviews_ly,
        estimated_occupancy_l365d,
        cast(estimated_revenue_l365d as string) as estimated_revenue_l365d_raw,
        first_review,
        last_review,
        review_scores_rating,
        review_scores_accuracy,
        review_scores_cleanliness,
        review_scores_checkin,
        review_scores_communication,
        review_scores_location,
        review_scores_value,
        license,
        cast(instant_bookable as string) as instant_bookable_raw,
        calculated_host_listings_count,
        calculated_host_listings_count_entire_homes,
        calculated_host_listings_count_private_rooms,
        calculated_host_listings_count_shared_rooms,
        reviews_per_month
    from {{ source('istanbul_airbnb_raw', 'raw_listings_20260630') }}

),

cleaned as (

    select
        -- 1. Tekil satır anahtarı (listing_id + snapshot_date)
        concat(cast(listing_id as string), '_', cast(snapshot_date as string)) as listing_snapshot_id,
        snapshot_date,
        is_partial_snapshot,

        -- 2. Temel ilan bilgileri
        listing_id,
        listing_name,
        source,
        last_scraped,

        -- 3. Host bilgileri ve tip dönüşümleri
        host_id,
        host_name,
        safe_cast(host_since_raw as date) as host_since,
        host_location,
        host_response_time,
        safe_cast(replace(host_response_rate, '%', '') as float64) as host_response_rate_pct,
        safe_cast(replace(host_acceptance_rate, '%', '') as float64) as host_acceptance_rate_pct,
        host_is_superhost,
        host_listings_count,
        safe_cast(host_total_listings_count_raw as int64) as host_total_listings_count,
        host_has_profile_pic,
        host_identity_verified,
        calculated_host_listings_count,
        calculated_host_listings_count_entire_homes,
        calculated_host_listings_count_private_rooms,
        calculated_host_listings_count_shared_rooms,

        -- 4. Konum ve mülk özellikleri
        neighbourhood,
        latitude,
        longitude,
        property_type,
        room_type,
        accommodates,
        bedrooms,
        beds,
        bathrooms,
        bathrooms_text,
        coalesce(
            bathrooms,
            case
                when regexp_contains(lower(bathrooms_text), r'half-bath') then 0.5
                else safe_cast(regexp_extract(bathrooms_text, r'(\d+\.?\d*)') as float64)
            end
        ) as bathrooms_cleansed,
        amenities,

        -- 5. Fiyat, minimum gece ve 2026 teklif (price_quote) alanları
        price_raw,
        safe_cast(replace(replace(price_raw, '$', ''), ',', '') as float64) as price,
        minimum_nights,
        maximum_nights,
        price_quote_checkin_date,
        price_quote_checkout_date,
        date_diff(price_quote_checkout_date, price_quote_checkin_date, day) as price_quote_nights,
        price_quote_total_price,
        price_quote_price_per_night,
        price_quote_raw,

        -- 6. Takvim özeti, yorumlar ve gelir/doluluk tahminleri
        has_availability,
        availability_30,
        availability_60,
        availability_90,
        availability_365,
        number_of_reviews,
        number_of_reviews_ltm,
        number_of_reviews_l30d,
        number_of_reviews_ly,
        reviews_per_month,
        first_review,
        last_review,
        estimated_occupancy_l365d,
        safe_cast(replace(replace(estimated_revenue_l365d_raw, '$', ''), ',', '') as float64) as estimated_revenue_l365d,

        -- 7. Değerlendirme puanları (Review Scores)
        review_scores_rating,
        review_scores_accuracy,
        review_scores_cleanliness,
        review_scores_checkin,
        review_scores_communication,
        review_scores_location,
        review_scores_value,

        -- 8. Lisans / İzin numarası temizliği ve sınıflandırması
        license,
        trim(license) as license_trimmed,
        case
            when license is null or trim(license) = '' or lower(trim(license)) in ('none', 'null') then 'bos'
            when lower(trim(license)) = 'exempt' then 'muaf'
            when lower(trim(license)) = 'non-real estate listing' then 'konut_disi'
            when regexp_contains(trim(license), r'^\d{2}-\d+$') then 'izin_belgesi'
            when regexp_contains(trim(license), r'^\d{4}-\d{2}-\d+$') then 'yil_formatli'
            when regexp_contains(trim(license), r'^\d+$') then 'sadece_rakam'
            else 'diger'
        end as license_category,
        case
            when regexp_contains(trim(license), r'^\d{2}-\d+$') then regexp_extract(trim(license), r'^(\d{2})-')
            when regexp_contains(trim(license), r'^\d{4}-\d{2}-\d+$') then regexp_extract(trim(license), r'^\d{4}-(\d{2})-')
            else null
        end as license_province_code,

        -- 9. Instant bookable boolean dönüşümü
        case
            when lower(trim(instant_bookable_raw)) in ('t', 'true', '1') then true
            when lower(trim(instant_bookable_raw)) in ('f', 'false', '0') then false
            else null
        end as instant_bookable

    from raw_unioned

)

select * from cleaned
