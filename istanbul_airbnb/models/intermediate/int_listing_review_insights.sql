-- Haziran 2026 (2026-06-30) yorumlarını (stg_reviews) tarayarak her listing_id için:
-- 1. Turist profilini (Arapça, Kiril/Rusça, Doğu Asya, Türkçe, Batı/İngilizce alfabe ve dil kalıpları)
-- 2. Şikayet anahtar kelimelerini (Temizlik, Koku/Rutubet, Gürültü, Yokuş/Merdiven, Fotoğraf Uyumsuzluğu, Tesisat/Wifi)
-- ilan bazında sayar.

with jun26_reviews as (

    select
        listing_id,
        review_id,
        review_date,
        coalesce(comments, '') as comment_text,
        lower(coalesce(comments, '')) as comment_lower
    from {{ ref('stg_reviews') }}
    where snapshot_date = '2026-06-30'
      and comments is not null
      and trim(comments) != ''

),

classified as (

    select
        listing_id,
        review_id,

        -- 1. Alfabe / Dil Bazlı Turist Profili Sınıflandırması
        case
            when regexp_contains(comment_text, r'\p{Arabic}') then 'Arabic'
            when regexp_contains(comment_text, r'\p{Cyrillic}') then 'Cyrillic'
            when regexp_contains(comment_text, r'[\p{Han}\p{Hangul}\p{Hiragana}\p{Katakana}]') then 'East_Asian'
            when regexp_contains(comment_lower, r'[çğış]|teşekkür|tesekkur|her şey|hersey|gayet|konum|ev sahibi|kesinlikle') then 'Turkish'
            else 'Western_Latin'
        end as guest_language_group,

        -- 2. Şikayet Kategorileri (İngilizce + Türkçe anahtar kelimeler)
        regexp_contains(comment_lower, r'\b(dirty|filthy|stain|stains|cockroach|cockroaches|bedbug|insects|dusty|unclean|pis|kirli|böcek|bocek|lekeli)\b') as has_cleanliness_complaint,
        regexp_contains(comment_lower, r'\b(smell|smells|smelly|odor|odour|mold|mould|damp|humidity|sewage|musty|koku|kokuyor|rutubet|küf|kuf)\b') as has_smell_mold_complaint,
        regexp_contains(comment_lower, r'\b(noisy|noise|loud|earplugs|nightclub|street noise|gürültü|gurultu|çok ses|cok ses)\b') as has_noise_complaint,
        regexp_contains(comment_lower, r'\b(steep|stairs|uphill|no elevator|5th floor|4th floor|narrow stairs|yokuş|yokus|dik merdiven)\b') as has_stairs_hill_complaint,
        regexp_contains(comment_lower, r'(not like the photos|different from photos|nothing like the pictures|misleading|smaller than|catfish|fotoğraflarla|fotograflarla|göründüğü gibi değil)') as has_accuracy_photo_complaint,
        regexp_contains(comment_lower, r'(no hot water|cold water|wifi didn|no wifi|slow wifi|broken ac|no air conditioning|no heating|sıcak su yok|sicak su|internet çekmiyor)') as has_utilities_wifi_complaint

    from jun26_reviews

)

select
    listing_id,
    count(*) as analyzed_reviews_count,

    -- Turist Profili Sayıları
    countif(guest_language_group = 'Western_Latin') as reviews_western_latin,
    countif(guest_language_group = 'Turkish') as reviews_turkish,
    countif(guest_language_group = 'Cyrillic') as reviews_cyrillic,
    countif(guest_language_group = 'Arabic') as reviews_arabic,
    countif(guest_language_group = 'East_Asian') as reviews_east_asian,

    -- Şikayet Sayıları
    countif(has_cleanliness_complaint) as complaint_cleanliness_count,
    countif(has_smell_mold_count) as complaint_smell_mold_count,
    countif(has_noise_complaint) as complaint_noise_count,
    countif(has_stairs_hill_complaint) as complaint_stairs_hill_count,
    countif(has_accuracy_photo_complaint) as complaint_accuracy_photo_count,
    countif(has_utilities_wifi_complaint) as complaint_utilities_wifi_count,
    countif(
        has_cleanliness_complaint or has_smell_mold_count or has_noise_complaint
        or has_stairs_hill_complaint or has_accuracy_photo_complaint or has_utilities_wifi_complaint
    ) as any_complaint_reviews_count

from (
    select
        *,
        has_smell_mold_complaint as has_smell_mold_count
    from classified
)
group by listing_id
