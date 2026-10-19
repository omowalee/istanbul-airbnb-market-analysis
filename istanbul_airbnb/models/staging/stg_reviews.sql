-- 4 snapshot'taki raw_reviews_* tablolarını birleştirir.
-- Survivorship bias analizi ve dönemsel karşılaştırmalar için tüm snapshot'lar snapshot_date ile tutulur.

with raw_unioned as (

    select
        date '2025-09-29' as snapshot_date,
        false as is_partial_snapshot,
        id as review_id,
        listing_id,
        date as review_date,
        reviewer_id,
        reviewer_name,
        comments
    from {{ source('istanbul_airbnb_raw', 'raw_reviews_20250929') }}

    union all

    select
        date '2025-12-30' as snapshot_date,
        false as is_partial_snapshot,
        id as review_id,
        listing_id,
        date as review_date,
        reviewer_id,
        reviewer_name,
        comments
    from {{ source('istanbul_airbnb_raw', 'raw_reviews_20251230') }}

    union all

    select
        date '2026-03-31' as snapshot_date,
        true as is_partial_snapshot,
        id as review_id,
        listing_id,
        date as review_date,
        reviewer_id,
        reviewer_name,
        comments
    from {{ source('istanbul_airbnb_raw', 'raw_reviews_20260331') }}

    union all

    select
        date '2026-06-30' as snapshot_date,
        false as is_partial_snapshot,
        id as review_id,
        listing_id,
        date as review_date,
        reviewer_id,
        reviewer_name,
        comments
    from {{ source('istanbul_airbnb_raw', 'raw_reviews_20260630') }}

)

select
    concat(cast(review_id as string), '_', cast(snapshot_date as string)) as review_snapshot_id,
    snapshot_date,
    is_partial_snapshot,
    review_id,
    listing_id,
    review_date,
    date_trunc(review_date, month) as review_month,
    extract(year from review_date) as review_year,
    reviewer_id,
    reviewer_name,
    comments
from raw_unioned
