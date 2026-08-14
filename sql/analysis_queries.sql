-- =============================================================================
-- Customer Shopping Behaviour Analysis — analytical queries
-- Target: MySQL 8.0+ (window functions and CTEs required)
--
-- These re-answer the project's business questions against the warehouse,
-- proving the star schema joins correctly and demonstrating the SQL layer
-- independently of the pandas analysis.
--
-- Expected results are noted above each query so the output can be verified.
-- =============================================================================

USE customer_behaviour;


-- -----------------------------------------------------------------------------
-- Q1 · Category performance
-- Expected: Clothing $104,264 (44.7%), Accessories $74,200, Footwear $36,093,
--           Outerwear $18,524. Total revenue $233,081.
-- -----------------------------------------------------------------------------
SELECT  i.category,
        COUNT(*)                          AS orders,
        ROUND(SUM(f.purchase_amount), 2)  AS revenue,
        ROUND(AVG(f.purchase_amount), 2)  AS avg_order_value,
        ROUND(AVG(f.review_rating), 2)    AS avg_rating,
        ROUND(SUM(f.est_annual_value), 2) AS est_annual_value
FROM        fact_purchase f
INNER JOIN  dim_item i ON f.item_key = i.item_key
GROUP BY    i.category
ORDER BY    revenue DESC;


-- -----------------------------------------------------------------------------
-- Q2 · Top 3 items within each category, with share of category revenue
-- Uses RANK() and a windowed SUM() to avoid a self-join.
-- Expected: Outerwear splits ~50/50 between Coat and Jacket — only two items,
--           which is worth knowing before reading anything into its share.
-- -----------------------------------------------------------------------------
WITH item_revenue AS (
    SELECT  i.category,
            i.item_purchased,
            SUM(f.purchase_amount) AS revenue
    FROM        fact_purchase f
    INNER JOIN  dim_item i ON f.item_key = i.item_key
    GROUP BY    i.category, i.item_purchased
),
ranked AS (
    SELECT  category,
            item_purchased,
            revenue,
            RANK() OVER (PARTITION BY category ORDER BY revenue DESC) AS revenue_rank,
            ROUND(100.0 * revenue / SUM(revenue) OVER (PARTITION BY category), 1)
                AS pct_of_category
    FROM    item_revenue
)
SELECT   category, item_purchased, revenue, pct_of_category
FROM     ranked
WHERE    revenue_rank <= 3
ORDER BY category, revenue DESC;


-- -----------------------------------------------------------------------------
-- Q3 · Segment value by age band
-- The HAVING clause suppresses thin cells that would produce unstable averages.
-- -----------------------------------------------------------------------------
SELECT  c.segment,
        c.age_band,
        COUNT(DISTINCT c.customer_id)                     AS customers,
        ROUND(AVG(f.purchase_amount), 2)                  AS avg_order_value,
        ROUND(AVG(f.purchases_per_year), 1)               AS avg_purchases_per_year,
        ROUND(SUM(f.est_annual_value), 2)                 AS est_annual_value,
        ROUND(100.0 * SUM(c.is_subscriber) / COUNT(*), 1) AS subscriber_pct
FROM        dim_customer c
INNER JOIN  fact_purchase f ON c.customer_id = f.customer_id
GROUP BY    c.segment, c.age_band
HAVING      COUNT(DISTINCT c.customer_id) >= 20
ORDER BY    est_annual_value DESC
LIMIT 15;


-- -----------------------------------------------------------------------------
-- Q4 · Location leaderboard
-- -----------------------------------------------------------------------------
SELECT  l.location,
        COUNT(*)                          AS orders,
        ROUND(SUM(f.purchase_amount), 2)  AS revenue,
        ROUND(AVG(f.purchase_amount), 2)  AS avg_order_value,
        RANK() OVER (ORDER BY SUM(f.purchase_amount) DESC) AS revenue_rank
FROM        fact_purchase f
INNER JOIN  dim_location l ON f.location_key = l.location_key
GROUP BY    l.location
ORDER BY    revenue_rank
LIMIT 10;


-- -----------------------------------------------------------------------------
-- Q5 · The headline finding, in SQL
-- Cadence vs basket size between the two segments.
-- Expected: high-value segment buys ~4.3x more often but spends only ~1.23x
--           more per order — value comes from frequency, not basket size.
-- -----------------------------------------------------------------------------
WITH segment_profile AS (
    SELECT  c.segment,
            COUNT(DISTINCT c.customer_id)  AS customers,
            AVG(f.purchase_amount)         AS avg_order_value,
            AVG(f.purchases_per_year)      AS avg_purchases_per_year,
            SUM(f.est_annual_value)        AS est_annual_value
    FROM        dim_customer c
    INNER JOIN  fact_purchase f ON c.customer_id = f.customer_id
    GROUP BY    c.segment
)
SELECT  segment,
        customers,
        ROUND(100.0 * customers / SUM(customers) OVER (), 1)               AS pct_of_customers,
        ROUND(avg_order_value, 2)                                          AS avg_order_value,
        ROUND(avg_purchases_per_year, 1)                                   AS avg_purchases_per_year,
        ROUND(est_annual_value, 2)                                         AS est_annual_value,
        ROUND(100.0 * est_annual_value / SUM(est_annual_value) OVER (), 1) AS pct_of_annual_value
FROM     segment_profile
ORDER BY est_annual_value DESC;


-- -----------------------------------------------------------------------------
-- Q6 · Revenue concentration
-- Deciles by order value. Expected: the top decile holds ~16% of revenue —
-- close to the 10% a uniform distribution would give, so there is no whale
-- segment. Growth has to come from the middle of the base.
-- -----------------------------------------------------------------------------
WITH ranked_customers AS (
    SELECT  customer_id,
            purchase_amount,
            NTILE(10) OVER (ORDER BY purchase_amount DESC) AS revenue_decile
    FROM    fact_purchase
)
SELECT  revenue_decile,
        COUNT(*)                                                        AS customers,
        SUM(purchase_amount)                                            AS revenue,
        ROUND(100.0 * SUM(purchase_amount) / SUM(SUM(purchase_amount)) OVER (), 1)
            AS pct_of_revenue,
        ROUND(SUM(SUM(purchase_amount)) OVER (ORDER BY revenue_decile)
              / SUM(SUM(purchase_amount)) OVER () * 100, 1)             AS cumulative_pct
FROM     ranked_customers
GROUP BY revenue_decile
ORDER BY revenue_decile;


-- -----------------------------------------------------------------------------
-- Q7 · Engagement levers — the null result
-- Group medians can't be computed portably in MySQL, so this reports means and
-- spread. The formal tests (Mann-Whitney U with Cliff's delta) live in the
-- notebook; all effect sizes were negligible.
--
-- Read the output with care: the discount flag is moderately associated with
-- subscription status and gender (Cramer's V 0.70 / 0.60), so differences here
-- cannot be attributed to discounting itself.
-- -----------------------------------------------------------------------------
SELECT  CASE WHEN f.received_discount = 1 THEN 'Discounted' ELSE 'Not discounted' END AS cohort,
        COUNT(*)                            AS customers,
        ROUND(AVG(f.purchase_amount), 2)    AS avg_order_value,
        ROUND(STDDEV(f.purchase_amount), 2) AS sd_order_value,
        ROUND(AVG(f.est_annual_value), 2)   AS avg_annual_value
FROM     fact_purchase f
GROUP BY cohort

UNION ALL

SELECT  CASE WHEN c.is_subscriber = 1 THEN 'Subscriber' ELSE 'Non-subscriber' END,
        COUNT(*),
        ROUND(AVG(f.purchase_amount), 2),
        ROUND(STDDEV(f.purchase_amount), 2),
        ROUND(AVG(f.est_annual_value), 2)
FROM        fact_purchase f
INNER JOIN  dim_customer c ON f.customer_id = c.customer_id
GROUP BY    CASE WHEN c.is_subscriber = 1 THEN 'Subscriber' ELSE 'Non-subscriber' END;


-- -----------------------------------------------------------------------------
-- Q8 · Data quality — imputed review ratings
-- Expected: 37 rows (0.95%), with observed-only and all-rows means within 0.01.
-- -----------------------------------------------------------------------------
SELECT  i.category,
        COUNT(*)                                                      AS orders,
        SUM(f.review_rating_imputed)                                  AS imputed_ratings,
        ROUND(100.0 * SUM(f.review_rating_imputed) / COUNT(*), 2)     AS imputed_pct,
        ROUND(AVG(f.review_rating), 3)                                AS avg_rating_all,
        ROUND(AVG(CASE WHEN f.review_rating_imputed = 0
                       THEN f.review_rating END), 3)                  AS avg_rating_observed
FROM        fact_purchase f
INNER JOIN  dim_item i ON f.item_key = i.item_key
GROUP BY    i.category
ORDER BY    imputed_pct DESC;
