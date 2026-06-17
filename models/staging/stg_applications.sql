with source as ( 
    SELECT * 
    FROM {{ source('raw', 'applications') }}
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
