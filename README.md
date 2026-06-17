# HomeQ - Take home test

---

## How to run

```bash
pip install dbt-duckdb

# From this directory:
DBT_PROJECT_DIR=$(pwd) dbt seed          # Load the three CSVs into DuckDB
DBT_PROJECT_DIR=$(pwd) dbt run           # Build staging, intermediate and marts
DBT_PROJECT_DIR=$(pwd) dbt test          # Run all data tests 
```

**Project structure:**

```
seeds/               Raw CSVs (users, listings, applications)
models/
  staging/           1:1 with sources — cleaning only, materialized as views
    stg_users.sql
    stg_listings.sql
    stg_applications.sql
    sources.yml
    stg_models.yml   Tests for staging layer
  intermediate/       Intermediate layer for joining before marts
    int_listing_funnel.sql
    int_models.yml   Tests for intermediate layer
  marts/             Business level aggregates, materialized as tables
    marketplace_performance.sql
    mart_models.yml  Test for marts layer
```

## Business question

**Question:** "Where on the platform is the marketplace working best, and where is it struggling?"

### Metric definition(s)

I chose the following metrics that together separate demand-side from supply-side problems:

| Metric | Definition | Why |
|---|---|---|
| **avg_applications_per_listing** | Mean number of applications received per listing | Demand signal — high = seekers are actively engaging |
| **shortlist_rate_pct** | % of applications that reached "shortlisted" status | Landlord engagement / match quality — low = friction or irrelevant applicants |
| **rented_rate_pct** | % of listings that ended as "rented" | Throughput — the bottom-line outcome |

Together they let you distinguish four situations:
- High demand + high shortlist → marketplace working well
- High demand + low shortlist → seekers interested but landlords aren't converting (price mismatch? poor fit?)
- Low demand + high shortlist → tight market, scarce supply
- Low demand + low shortlist → struggling on both sides

###  Data quality issues you found

Before building any dbt models i chose to check all the CSV files using DuckDB directly againts the raw data files. I checked row counts, null rates, cardinality etc. The issues I found in the data sets is lsited below.

 ```
  -- Duplicated user_ids 
  SELECT user_id, COUNT(*)
  FROM read_csv_auto('seeds/users.csv')
  GROUP BY user_id
  HAVING COUNT(*) > 1;

  -- Duplicate listing_ids
  SELECT listing_id, COUNT(*)
  FROM read_csv_auto('seeds/listings.csv')
  GROUP BY listing_id
  HAVING COUNT(*) > 1;

  -- Check for referential integrity
  SELECT DISTINCT a.seeker_id
  FROM read_csv_auto('seeds/applications.csv') a
  WHERE a.seeker_id NOT IN (
      SELECT user_id FROM read_csv_auto('seeds/users.csv')
  );

  -- Check for mixed case
  SELECT DISTINCT user_type
  FROM read_csv_auto('seeds/users.csv');

  -- Check for future-dated records
  SELECT COUNT(*)
  FROM read_csv_auto('seeds/applications.csv')
  WHERE applied_at > current_timestamp;

  -- listing IDs in applications
  SELECT DISTINCT listing_id
  FROM read_csv_auto('seeds/applications.csv')
  WHERE listing_id NOT IN (
      SELECT listing_id FROM read_csv_auto('seeds/listings.csv')
  );

  -- landlords IDs in listings
  SELECT DISTINCT landlord_id
  FROM read_csv_auto('seeds/listings.csv')
  WHERE landlord_id NOT IN (
      SELECT user_id FROM read_csv_auto('seeds/users.csv')
  );
 ```

  | Issue | How I handled it |
  |---|---|
  | `user_type` mixed case (`SEEKER`, `Seeker`, `Landlord`) | Normalized with `lower(trim())` in `stg_users` |
  | 3 duplicate `user_id` in users.csv | Kept earliest `created_at` per `user_id` using `ROW_NUMBER()` |
  | 2 duplicate `listing_id` in listings.csv | Kept earliest `listed_at` per `listing_id` using `ROW_NUMBER()` |
  | 5 applications reference `l_99xxx` listing IDs not in listings.csv | Filtered out in `stg_applications` — likely deleted listings |
  | 11 applications from `u_99xxx` seeker IDs not in users.csv | Filtered out in `stg_applications` — likely deleted accounts |
  | 2 listings owned by `u_99xxx` landlords not in users.csv | Filtered out in `stg_listings` — same pattern as above |
  | 2 future-dated applications | Filtered out in `stg_applications` |
  | 16 users with empty `age` | Kept as NULL — field is optional at signup |


### Results

  | city | total_listings | total_applications | avg_applications_per_listing | rented_rate_pct | shortlist_rate_pct |
  |---|---|---|---|---|---|
  | Stockholm | 22 | 146 | 6.6 | 63.6 | 7.5 |
  | Lund | 24 | 180 | 7.5 | 37.5 | 10.0 |
  | Uppsala | 19 | 115 | 6.1 | 36.8 | 7.8 |
  | Linköping | 31 | 225 | 7.3 | 35.5 | 6.2 |
  | Malmö | 27 | 167 | 6.2 | 33.3 | 4.8 |
  | Göteborg | 25 | 153 | 6.1 | 32.0 | 3.9 |

  ### Answer

The strongest pattern in the data: 
For five of the six cities, shortlist_rate_pct correlates strongly with rented_rate_pct (0.96). Cities with poor application-to-shortlist matching Göteborg (3.9% shortlist, 32.0% rented) and Malmö (4.8%, 33.3%) end up with the lowest rented rates. 
Cities with high shortlist rates, Lund (10.0%, 37.5%) and Uppsala (7.8%, 36.8%) end up with the highest, among this group. 
This isnt two separate problems; its one continuous relationship: cities with better matching tend to have more rentals.
Stockholm is a exception. Its rented_rate (63.6%) is far above what its shortlist_rate (7.5%) would predict from that relationship. Nearly double every other city despite unremarkable demand and matching. I couldnt find a clear explanation in this dataset. Worth investigating further with another hour, ideally with data including decision timestamps and price negotiation history for exeample. 
Lund stands out differently with a high demand (7.5, avg_applications_per_listing highest of all cities) but only 37.5% rented rate. The dataset doesnt explain this gap clearly. Possible causes can be that listings are
too recent to have converted yet, seekers are declining offers, or price levels dont match expectations. 
Worth investigating with longer time series data.


## Assumptions

- For duplicate user_ids I kept the earliest record, assuming later records are corrections or re-registrations. 
- For duplicate listing_ids I kept the first listed record, same logic as above.
- The `rented` status on a listing is independent of application status, a listing can be `rented` without any application being `shortlisted`. I treat listing status as the outcome signal for throughput.
- Ghost IDs (u_99xxx / l_99xxx) are deleted/archived accounts or tests, not data entry errors.

## What I'd do with another hour

 - **Stockholm outlier investigation** — its 63.6% rented_rate breaks an otherwise near-perfect shortlist→rented 
  correlation (0.96) across the other five cities. Ruled out listing age and rent level; would need decision-timestamp 
  data to dig further.
  - **District-level breakdown** — city grain hides within-city variation, and was deliberately skipped here since several 
  districts have too few listings for a reliable rate.
  - **Lund supply-gap sizing** — Lund pairs highest demand-per-listing with the best matching and conversion, suggesting a 
  tight market. Worth quantifying how much additional listing supply the existing demand could plausibly absorb.
  - **Time-to-rented tracking** — no timestamp exists for when a listing's status flips to rented, only that it eventually 
  did. Would let me replace is_rented (binary) with an actual speed metric.
