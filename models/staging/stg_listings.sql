with source as (
    SELECT * 
    FROM {{ source('raw', 'listings') }}
),

-- Remove duplicates in listing_id. All listings should be unique. 
-- 2 listings have lanlord_ids with u_99xxx, could be test listings? Remove from data
deduped as (
    SELECT *,
    row_number() over (
        partition by listing_id
        order by listed_at asc
    ) as rn
    FROM source
    WHERE landlord_id NOT LIKE 'u_99%'
    AND listing_id NOT LIKE 'l_99%'
)

SELECT 
    listing_id, 
    landlord_id,
    city,
    district,
    NULLIF(cast(monthly_rent_sek as integer), 0) as monthly_rent_sek,
    cast(size_sqm as integer) as size_sqm,
    cast(rooms as integer) as rooms,
    cast(listed_at as timestamp) as listed_at,
    status
    FROM deduped
    WHERE rn = 1
