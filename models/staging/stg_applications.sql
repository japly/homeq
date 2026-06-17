with source as ( 
    SELECT * 
    FROM {{ source('raw', 'applications') }}
),

valid_listing_ids as (
    SELECT listing_id
    FROM {{ ref('stg_listings') }}
    WHERE listing_id NOT LIKE 'l_99%'
      AND landlord_id NOT LIKE 'u_99%'
),

valid as (
    SELECT *
    FROM source
    WHERE listing_id IN (SELECT listing_id FROM {{ ref('stg_listings') }})
      AND seeker_id IN (SELECT user_id FROM {{ ref('stg_users') }})
      AND cast(applied_at as timestamp) <= current_timestamp
)

SELECT
    application_id,
    seeker_id,
    listing_id,
    cast(applied_at as timestamp) as applied_at,
    status
FROM valid