-- Her (snapshot_date, listing_id) için amenities JSON dizisinden anahtar olanak ve manzara bayraklarını (BOOL) çıkarır.
-- Bölüm 3.8: Su manzarası (has_water_view), şehir silüeti (has_city_skyline_view), asansör, çalışma alanı
-- ve mutfaksız + mini buzdolabı/bina personeli ("otel benzeri birim" - is_hotel_like_unit) sinyallerini üretir.

with base as (

    select
        listing_snapshot_id,
        snapshot_date,
        listing_id,
        amenities,
        coalesce(array_length(json_extract_string_array(amenities)), 0) as amenities_count,

        -- Manzara bayrakları
        regexp_contains(amenities, r'(?i)"(sea|harbor|bay|ocean|canal|river|beach|marina|lake) view"') as has_water_view,
        regexp_contains(amenities, r'(?i)"city skyline view"') as has_city_skyline_view,
        regexp_contains(amenities, r'(?i)"(garden|courtyard|park) view"') as has_green_view,

        -- Temel konfor ve dijital göçebe olanakları
        regexp_contains(amenities, r'(?i)wifi') as has_wifi,
        regexp_contains(amenities, r'(?i)"kitchen"|kitchenette') as has_kitchen,
        regexp_contains(amenities, r'(?i)air conditioning|central air conditioning|ac - split type') as has_air_conditioning,
        regexp_contains(amenities, r'(?i)"elevator"') as has_elevator,
        regexp_contains(amenities, r'(?i)"dedicated workspace"') as has_dedicated_workspace,
        regexp_contains(amenities, r'(?i)washer') as has_washer,
        regexp_contains(amenities, r'(?i)free parking|paid parking') as has_parking,
        regexp_contains(amenities, r'(?i)pool|hot tub|sauna|hammam') as has_wellness_facility,
        regexp_contains(amenities, r'(?i)self check-in|keypad|smart lock|lockbox') as has_self_checkin,

        -- Otel / apart tipi işletme sinyalleri (Bölüm 3.8)
        regexp_contains(amenities, r'(?i)mini fridge') as has_mini_fridge,
        regexp_contains(amenities, r'(?i)building staff') as has_building_staff,
        regexp_contains(amenities, r'(?i)exterior security cameras') as has_security_cameras

    from {{ ref('stg_listings') }}

)

select
    *,
    -- Mutfaksız olup mini buzdolabı veya bina personeli olan birimler (otel odası / apart deseni)
    (not has_kitchen and (has_mini_fridge or has_building_staff)) as is_hotel_like_unit,

    -- Özet manzara kategorisi
    case
        when has_water_view and has_city_skyline_view then '1) Su + Sehir Silueti Manzarasi'
        when has_water_view then '2) Su Manzarasi (Deniz/Bogaz)'
        when has_city_skyline_view then '3) Sehir Silueti Manzarasi'
        when has_green_view then '4) Bahce/Park Manzarasi'
        else '5) Belirtilmemis / Manzarasiz'
    end as view_category
from base
