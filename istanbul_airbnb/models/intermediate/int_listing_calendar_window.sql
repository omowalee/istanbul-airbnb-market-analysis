-- Her (snapshot_date, listing_id) için takvim penceresini (3/6/9/12 ay) ve
-- ilanın KENDİ AÇIK PENCERESİ içindeki kapalı gün oranını (closed_day_rate_in_window) hesaplar.
-- Ayrıca hostun takvimde gün bazında minimum_nights kuralını değiştirip değiştirmediğini (hafta sonu / sezon esnekliği) ölçer.

with calendar_bounds as (

    select
        snapshot_date,
        listing_id,
        calendar_date,
        available,
        is_closed_day,
        is_weekend_night,
        minimum_nights,
        min(calendar_date) over (partition by snapshot_date, listing_id) as calendar_start_date,
        max(if(available = true, calendar_date, null)) over (partition by snapshot_date, listing_id) as last_available_date
    from {{ ref('stg_calendar') }}

),

aggregated as (

    select
        concat(cast(listing_id as string), '_', cast(snapshot_date as string)) as listing_snapshot_id,
        snapshot_date,
        listing_id,

        min(calendar_start_date) as calendar_start_date,
        max(calendar_date) as calendar_end_date,
        max(last_available_date) as last_available_date,

        count(*) as total_calendar_days,
        sum(is_closed_day) as total_closed_days_365d,
        round(avg(is_closed_day), 4) as raw_closed_day_rate_365d,

        -- İlanın açık tuttuğu takvim penceresi (calendar_start_date .. last_available_date) içindeki gün sayısı
        countif(last_available_date is not null and calendar_date <= last_available_date) as window_days,

        -- Kendi açık penceresi içindeki kapalı gün sayısı ve oranı (Takvim penceresi artefaktından arındırılmış metrik)
        countif(last_available_date is not null and calendar_date <= last_available_date and is_closed_day = 1) as closed_days_in_window,
        round(
            safe_divide(
                countif(last_available_date is not null and calendar_date <= last_available_date and is_closed_day = 1),
                countif(last_available_date is not null and calendar_date <= last_available_date)
            ),
            4
        ) as closed_day_rate_in_window,

        -- Yakın dönem (ilk 30 ve ilk 90 gün) kapalı gün oranları
        round(
            avg(if(date_diff(calendar_date, calendar_start_date, day) < 30, is_closed_day, null)),
            4
        ) as closed_day_rate_next_30d,
        round(
            avg(if(date_diff(calendar_date, calendar_start_date, day) < 90, is_closed_day, null)),
            4
        ) as closed_day_rate_next_90d,

        -- Güne özel minimum_nights davranışı (Dinamik kural / Hafta sonu farkı)
        min(minimum_nights) as min_calendar_minimum_nights,
        max(minimum_nights) as max_calendar_minimum_nights,
        (min(minimum_nights) != max(minimum_nights)) as has_dynamic_min_nights,
        round(avg(if(is_weekend_night, minimum_nights, null)), 2) as avg_weekend_min_nights,
        round(avg(if(not is_weekend_night, minimum_nights, null)), 2) as avg_weekday_min_nights

    from calendar_bounds
    group by snapshot_date, listing_id

)

select
    *,
    case
        when last_available_date is null or window_days = 0 then '0) Tamamen Kapali (0 gun)'
        when window_days <= 105 then '1) ~3 Ay Pencere (1-105 gun)'
        when window_days <= 195 then '2) ~6 Ay Pencere (106-195 gun)'
        when window_days <= 285 then '3) ~9 Ay Pencere (196-285 gun)'
        else '4) ~12 Ay Pencere (286+ gun)'
    end as calendar_window_bucket
from aggregated
