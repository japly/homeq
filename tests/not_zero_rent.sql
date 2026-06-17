-- This asserts that no non-null monthly_rent_sek is zero or negative 

SELECT *
FROM {{ ref('stg_listings') }}
WHERE monthly_rent_sek is not NULL
  AND monthly_rent_sek <= 0