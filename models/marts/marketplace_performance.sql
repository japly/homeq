with funnel as (
    SELECT * 
    FROM {{ ref('int_listing_funnel') }}
)

SELECT
    city,
    count(*) as total_listings,
    sum(total_applications) as total_applications,
    round(avg(total_applications), 1) as avg_applications_per_listing,
    sum(case when total_applications = 0 then 1 else 0 end) as listings_with_zero_applications,
    sum(case when is_rented then 1 else 0 end) as rented_count,
    round(100.0 * sum(case when is_rented then 1 else 0 end) / count(*), 1) as rented_rate_pct,
    sum(shortlisted_count) as total_shortlisted,
    round(100.0 * sum(shortlisted_count) / nullif(sum(total_applications), 0), 1) as shortlist_rate_pct,
    round(avg(monthly_rent_sek), 0) as avg_monthly_rent_sek
FROM funnel
GROUP BY city
ORDER BY rented_rate_pct desc