-- 4 snapshot'taki raw_calendar_* tablolarını birleştirir.
-- Not: 2025-09-29 tablosunda boş price/adjusted_price kolonları varken diğer 3 dönemde bu kolonlar yoktur;
-- bu yüzden sadece ortak 5 temel kolonu seçiyoruz.
-- Ayrıca 'available = false' rezervasyon demek olmadığı için 'is_closed_day' (1/0) ve Cuma-Cumartesi için 'is_weekend_night' bayraklarını üretiyoruz.

with raw_unioned as (

    select
        date '2025-09-29' as snapshot_date,
        false as is_partial_snapshot,
        listing_id,
        date as calendar_date,
        available,
        minimum_nights,
        maximum_nights
    from {{ source('istanbul_airbnb_raw', 'raw_calendar_20250929') }}

    union all

    select
        date '2025-12-30' as snapshot_date,
        false as is_partial_snapshot,
        listing_id,
        date as calendar_date,
        available,
        minimum_nights,
        maximum_nights
    from {{ source('istanbul_airbnb_raw', 'raw_calendar_20251230') }}

    union all

    select
        date '2026-03-31' as snapshot_date,
        true as is_partial_snapshot,
        listing_id,
        date as calendar_date,
        available,
        minimum_nights,
        maximum_nights
    from {{ source('istanbul_airbnb_raw', 'raw_calendar_20260331') }}

    union all

    select
        date '2026-06-30' as snapshot_date,
        false as is_partial_snapshot,
        listing_id,
        date as calendar_date,
        available,
        minimum_nights,
        maximum_nights
    from {{ source('istanbul_airbnb_raw', 'raw_calendar_20260630') }}

)

select
    snapshot_date,
    is_partial_snapshot,
    listing_id,
    calendar_date,
    date_trunc(calendar_date, month) as calendar_month,
    available,
    case when available = false then 1 else 0 end as is_closed_day,
    -- BigQuery'de DAYOFWEEK: Pazar=1, ..., Cuma=6, Cumartesi=7
    extract(dayofweek from calendar_date) in (6, 7) as is_weekend_night,
    minimum_nights,
    maximum_nights
from raw_unioned
