with listings as (
    SELECT * 
    FROM {{ ref('stg_listings') }}
),

applications as (
    SELECT * 
    FROM {{ ref('stg_applications') }}
),

-- Aggregate applications to one row per listing_id before joining,
-- so the join below cant fan out and inflate listing-level rows.
application_counts as (
    SELECT
        listing_id,
        count(*) as total_applications,
        count(*) FILTER (where status = 'sent') as sent_count,
        count(*) FILTER (where status = 'viewed') as viewed_count,
        count(*) FILTER (where status = 'shortlisted') as shortlisted_count,
        count(*) FILTER (where status = 'declined') as declined_count,
        count(*) FILTER (where status = 'withdrawn') as withdrawn_count
    FROM applications
    GROUP BY listing_id
)

-- LEFT JOIN is deliberate: listings with zero applications must stay in
-- the result (they're the most direct signal of a struggling listing),
-- not get silently dropped by an inner join.
SELECT
    l.listing_id,
    l.landlord_id,
    l.city,
    l.district,
    l.monthly_rent_sek,
    l.size_sqm,
    l.rooms,
    l.listed_at,
    l.status as listing_status,
    l.status = 'rented' as is_rented,
    coalesce(ac.total_applications, 0) as total_applications,
    coalesce(ac.sent_count, 0) as sent_count,
    coalesce(ac.viewed_count, 0) as viewed_count,
    coalesce(ac.shortlisted_count, 0) as shortlisted_count,
    coalesce(ac.declined_count, 0) as declined_count,
    coalesce(ac.withdrawn_count, 0) as withdrawn_count
FROM listings l
LEFT JOIN application_counts ac
    ON l.listing_id = ac.listing_id