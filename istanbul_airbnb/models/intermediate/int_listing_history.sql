-- Her listing_id'nin 4 snapshot (2025-09-29 .. 2026-06-30) boyunca geçmişini,
-- platformda kalma / ayrılma (churn) durumunu, kısa dönemden uzun döneme (100+ gün) geçişini
-- ve yalnızca karşılaştırılabilir dönem olan Mart 2026 -> Haziran 2026 fiyat değişimini özetler.

with listing_pivoted as (

    select
        listing_id,
        count(distinct snapshot_date) as snapshots_present_count,
        min(snapshot_date) as first_seen_snapshot,
        max(snapshot_date) as last_seen_snapshot,

        -- Hangi snapshot'larda var?
        countif(snapshot_date = '2025-09-29') > 0 as present_sep25,
        countif(snapshot_date = '2025-12-30') > 0 as present_dec25,
        countif(snapshot_date = '2026-03-31') > 0 as present_mar26,
        countif(snapshot_date = '2026-06-30') > 0 as present_jun26,

        -- En güncel bilinen temel özellikler (Haziran 2026 varsa o, yoksa en son göründüğü dönem)
        array_agg(neighbourhood order by snapshot_date desc limit 1)[offset(0)] as latest_neighbourhood,
        array_agg(room_type order by snapshot_date desc limit 1)[offset(0)] as latest_room_type,
        array_agg(host_id order by snapshot_date desc limit 1)[offset(0)] as latest_host_id,
        array_agg(license_category order by snapshot_date desc limit 1)[offset(0)] as latest_license_category,
        array_agg(review_scores_rating order by snapshot_date desc limit 1)[offset(0)] as latest_review_scores_rating,
        array_agg(number_of_reviews order by snapshot_date desc limit 1)[offset(0)] as latest_number_of_reviews,

        -- Dönem bazında minimum_nights ve source (kısa dönem -> 100 gün uzun dönem geçişi için)
        max(if(snapshot_date = '2025-09-29', minimum_nights, null)) as min_nights_sep25,
        max(if(snapshot_date = '2026-06-30', minimum_nights, null)) as min_nights_jun26,
        max(if(snapshot_date = '2025-09-29', source, null)) as source_sep25,
        max(if(snapshot_date = '2026-06-30', source, null)) as source_jun26,

        -- Karşılaştırılabilir tek fiyat dönemi: Mart 2026 vs Haziran 2026 (Bölüm 3.3 kararı)
        max(if(snapshot_date = '2026-03-31' and (price_quote_nights is null or price_quote_nights <= 30), price, null)) as price_mar26,
        max(if(snapshot_date = '2026-06-30' and (price_quote_nights is null or price_quote_nights <= 30), price, null)) as price_jun26,

        -- Yorum sayısı büyümesi (Eylül 2025 -> Haziran 2026)
        max(if(snapshot_date = '2025-09-29', number_of_reviews, null)) as reviews_sep25,
        max(if(snapshot_date = '2026-06-30', number_of_reviews, null)) as reviews_jun26

    from {{ ref('stg_listings') }}
    group by listing_id

)

select
    *,
    -- Eylül 2025'te platformda olup Haziran 2026'da tamamen kaybolan ilanlar (Churn)
    (present_sep25 and not present_jun26) as is_churned_sep25_to_jun26,

    -- Eylül 2025'te kısa dönem (<=30) olup Haziran 2026'da uzun döneme (>30, özellikle 100 gün) geçenler
    (present_sep25 and present_jun26 and min_nights_sep25 <= 30 and min_nights_jun26 > 30) as switched_short_to_long_term,

    -- Mart 2026 -> Haziran 2026 fiyat değişim oranı ve yüzdesi
    round(safe_divide(price_jun26, price_mar26), 4) as price_ratio_jun26_vs_mar26,
    round(safe_divide(price_jun26 - price_mar26, price_mar26) * 100.0, 2) as price_change_pct_mar26_to_jun26,

    -- Mart -> Haziran fiyatlama davranışı (Statik vs Fiyat Güncelleyen)
    case
        when price_mar26 is null or price_jun26 is null then null
        when abs(safe_divide(price_jun26 - price_mar26, price_mar26)) < 0.01 then '1) Statik Fiyat (Degisim <%1)'
        when safe_divide(price_jun26 - price_mar26, price_mar26) >= 0.15 then '2) Yuksek Artis (>=+%15)'
        when safe_divide(price_jun26 - price_mar26, price_mar26) >= 0.01 then '3) Ilmlı Artis (+%1..%15)'
        else '4) Fiyat Indirimi (<-%1)'
    end as mar_to_jun_pricing_behavior,

    -- 9 aylık yeni yorum kazanımı (Eylül 2025 -> Haziran 2026)
    (reviews_jun26 - reviews_sep25) as reviews_gained_sep25_to_jun26
from listing_pivoted
