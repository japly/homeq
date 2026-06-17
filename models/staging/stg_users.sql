with source as (
    SELECT * FROM {{ source('raw', 'users') }}
),

-- Remove duplicate users by user_id. Keep the user_id created first 
deduped as (
    SELECT * ,
    row_number() over (
        partition by user_id
        order by created_at asc
    ) as rn
    FROM source
    WHERE user_id NOT LIKE 'u_99%'
)

-- 
SELECT 
    user_id,
    lower(trim(user_type)) as user_type,
    lower(trim(email)) as email, 
    name, 
    trim(city) as city,
    cast(created_at as timestamp) as created_at,
CASE WHEN age = '' THEN NULL 
    ELSE cast(age as integer) 
    END as age
FROM deduped
WHERE rn = 1 