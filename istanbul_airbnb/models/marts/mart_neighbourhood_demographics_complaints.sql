-- Semt ve Puan Grubu Bazında Turist Profili & Şikayet Röntgeni Mart Tablosu (mart_neighbourhood_demographics_complaints):
-- Fikir 2 (Alfabe/Dil bazlı turist segmentasyonu) ve Fikir 3 (Düşük puanlı ilanlarda hangi şikayetler öne çıkıyor?)
-- sorularını (neighbourhood, rating_group) düzeyinde özetler.

with joined as (

    select
        l.listing_id,
        l.neighbourhood,
        l.room_type,
        l.rating_group,
        l.review_scores_rating,
        l.review_scores_cleanliness,
        l.review_scores_location,
        l.review_scores_value,
        coalesce(r.analyzed_reviews_count, 0) as analyzed_reviews_count,
        coalesce(r.reviews_western_latin, 0) as reviews_western_latin,
        coalesce(r.reviews_turkish, 0) as reviews_turkish,
        coalesce(r.reviews_cyrillic, 0) as reviews_cyrillic,
        coalesce(r.reviews_arabic, 0) as reviews_arabic,
        coalesce(r.reviews_east_asian, 0) as reviews_east_asian,
        coalesce(r.complaint_cleanliness_count, 0) as complaint_cleanliness_count,
        coalesce(r.complaint_smell_mold_count, 0) as complaint_smell_mold_count,
        coalesce(r.complaint_noise_count, 0) as complaint_noise_count,
        coalesce(r.complaint_stairs_hill_count, 0) as complaint_stairs_hill_count,
        coalesce(r.complaint_accuracy_photo_count, 0) as complaint_accuracy_photo_count,
        coalesce(r.complaint_utilities_wifi_count, 0) as complaint_utilities_wifi_count,
        coalesce(r.any_complaint_reviews_count, 0) as any_complaint_reviews_count
    from {{ ref('dim_listing') }} l
    left join {{ ref('int_listing_review_insights') }} r
        on l.listing_id = r.listing_id

)

select
    concat(neighbourhood, '_', rating_group) as neighbourhood_rating_key,
    neighbourhood,
    rating_group,
    count(*) as listings_count,
    sum(analyzed_reviews_count) as total_analyzed_reviews,

    -- Alt Puan Ortalamaları
    round(avg(review_scores_rating), 2) as avg_overall_rating,
    round(avg(review_scores_cleanliness), 2) as avg_cleanliness_score,
    round(avg(review_scores_location), 2) as avg_location_score,
    round(avg(review_scores_value), 2) as avg_value_score,

    -- Turist Profili Payları (% - toplam yorum üzerinden)
    round(safe_divide(sum(reviews_western_latin), sum(analyzed_reviews_count)) * 100.0, 1) as share_western_latin_pct,
    round(safe_divide(sum(reviews_turkish), sum(analyzed_reviews_count)) * 100.0, 1) as share_turkish_pct,
    round(safe_divide(sum(reviews_cyrillic), sum(analyzed_reviews_count)) * 100.0, 1) as share_cyrillic_pct,
    round(safe_divide(sum(reviews_arabic), sum(analyzed_reviews_count)) * 100.0, 1) as share_arabic_pct,
    round(safe_divide(sum(reviews_east_asian), sum(analyzed_reviews_count)) * 100.0, 1) as share_east_asian_pct,

    -- Şikayet Sıklığı (Her 100 yorumda kaç şikayet geçiyor?)
    round(safe_divide(sum(any_complaint_reviews_count), sum(analyzed_reviews_count)) * 100.0, 2) as any_complaint_per_100_reviews,
    round(safe_divide(sum(complaint_cleanliness_count), sum(analyzed_reviews_count)) * 100.0, 2) as cleanliness_complaint_per_100_reviews,
    round(safe_divide(sum(complaint_smell_mold_count), sum(analyzed_reviews_count)) * 100.0, 2) as smell_mold_complaint_per_100_reviews,
    round(safe_divide(sum(complaint_noise_count), sum(analyzed_reviews_count)) * 100.0, 2) as noise_complaint_per_100_reviews,
    round(safe_divide(sum(complaint_stairs_hill_count), sum(analyzed_reviews_count)) * 100.0, 2) as stairs_hill_complaint_per_100_reviews,
    round(safe_divide(sum(complaint_accuracy_photo_count), sum(analyzed_reviews_count)) * 100.0, 2) as photo_accuracy_complaint_per_100_reviews,
    round(safe_divide(sum(complaint_utilities_wifi_count), sum(analyzed_reviews_count)) * 100.0, 2) as utilities_wifi_complaint_per_100_reviews

from joined
group by 1, 2, 3
