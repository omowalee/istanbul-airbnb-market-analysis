-- İstanbul'un 39 ilçesinin GeoJSON poligon sınırlarını BigQuery GEOGRAPHY tipine dönüştürür,
-- ilçe yüzölçümünü (area_km2), merkez noktasını (centroid) ve Avrupa/Anadolu yakası ayrımını hesaplar.

with raw_geo as (

    select
        trim(neighbourhood) as neighbourhood,
        geometry_json,
        st_geogfromgeojson(geometry_json, make_valid => true) as neighbourhood_geom
    from {{ source('istanbul_airbnb_raw', 'raw_neighbourhoods') }}

)

select
    neighbourhood,
    -- İstanbul'un 39 ilçesini Avrupa ve Anadolu Yakası olarak sınıflandırıyoruz
    case
        when neighbourhood in (
            'Adalar', 'Ataşehir', 'Atasehir', 'Beykoz', 'Çekmeköy', 'Cekmekoy',
            'Kadıköy', 'Kadikoy', 'Kartal', 'Maltepe', 'Pendik', 'Sancaktepe',
            'Sultanbeyli', 'Şile', 'Sile', 'Tuzla', 'Ümraniye', 'Umraniye', 'Üsküdar', 'Uskudar'
        ) then 'Anadolu Yakasi'
        else 'Avrupa Yakasi'
    end as city_side,
    round(st_area(neighbourhood_geom) / 1e6, 2) as area_km2,
    round(st_x(st_centroid(neighbourhood_geom)), 5) as centroid_longitude,
    round(st_y(st_centroid(neighbourhood_geom)), 5) as centroid_latitude,
    neighbourhood_geom,
    geometry_json
from raw_geo
