-- Add a column marking each encounter as build (70%) or test (30%)
ALTER TABLE fact_encounter ADD COLUMN sample_split VARCHAR(5);

UPDATE fact_encounter
SET sample_split = CASE WHEN MOD(patient_nbr, 10) < 7 THEN 'build' ELSE 'test' END
WHERE encounter_id > 0;

SELECT sample_split, COUNT(*) AS encounters
FROM fact_encounter
WHERE exclusion_reason IS NULL
GROUP BY sample_split;

-- Compare candidate tier cutoffs on the build and test parts
WITH base AS (
    SELECT sample_split, readmit_30, number_inpatient
    FROM fact_encounter
    WHERE exclusion_reason IS NULL
),
cutoffs AS (
    SELECT 1 AS cutoff UNION ALL SELECT 2 UNION ALL SELECT 3
),
stats AS (
    SELECT
        b.sample_split,
        c.cutoff,
        COUNT(*)                                          AS encounters,
        SUM(b.number_inpatient >= c.cutoff)               AS tier_n,
        SUM(b.readmit_30)                                 AS readmissions,
        SUM(b.readmit_30 * (b.number_inpatient >= c.cutoff)) AS tier_readm
    FROM base b
    CROSS JOIN cutoffs c
    GROUP BY b.sample_split, c.cutoff
)
SELECT
    sample_split,
    cutoff,
    ROUND(tier_n / encounters * 100, 1)                                  AS tier_share_pct,
    ROUND(tier_readm / tier_n * 100, 1)                                  AS tier_rate_pct,
    ROUND((readmissions - tier_readm) / (encounters - tier_n) * 100, 1)  AS rest_rate_pct,
    ROUND((tier_readm / tier_n)
        / ((readmissions - tier_readm) / (encounters - tier_n)), 2)      AS lift,
    ROUND(tier_readm / readmissions * 100, 1)                            AS capture_pct
FROM stats
ORDER BY sample_split, cutoff;

-- Flag encounters in the higher-risk tier: 2 or more prior-year inpatient visits
ALTER TABLE fact_encounter ADD COLUMN in_tier TINYINT;

UPDATE fact_encounter
SET in_tier = CASE WHEN number_inpatient >= 2 THEN 1 ELSE 0 END
WHERE encounter_id > 0;

SELECT in_tier,
       COUNT(*)                         AS encounters,
       SUM(readmit_30)                  AS readmitted_30,
       ROUND(AVG(readmit_30) * 100, 1)  AS rate_pct
FROM fact_encounter
WHERE exclusion_reason IS NULL
GROUP BY in_tier;

-- Capture curve: running totals as the tier widens, highest risk first
WITH by_visits AS (
    SELECT
        LEAST(number_inpatient, 6) AS prior_visits,
        COUNT(*)                   AS encounters,
        SUM(readmit_30)            AS readmissions
    FROM fact_encounter
    WHERE exclusion_reason IS NULL
    GROUP BY LEAST(number_inpatient, 6)
)
SELECT
    prior_visits,
    encounters,
    readmissions,
    RANK() OVER (ORDER BY readmissions / encounters DESC)                  AS risk_rank,
    SUM(encounters)   OVER (ORDER BY prior_visits DESC)                    AS cum_encounters,
    SUM(readmissions) OVER (ORDER BY prior_visits DESC)                    AS cum_readmissions,
    ROUND(SUM(encounters)   OVER (ORDER BY prior_visits DESC)
          / SUM(encounters) OVER () * 100, 1)                              AS cum_encounter_pct,
    ROUND(SUM(readmissions) OVER (ORDER BY prior_visits DESC)
          / SUM(readmissions) OVER () * 100, 1)                            AS cum_capture_pct
FROM by_visits
ORDER BY prior_visits DESC;

-- Workload assumptions
SET @contacts_per_patient = 2;
SET @minutes_per_contact  = 20;

-- Staff hours and readmissions reached for each targeting option
WITH options AS (
    SELECT 'All encounters' AS option_name, 0 AS cutoff
    UNION ALL SELECT '1+ prior visits', 1
    UNION ALL SELECT '2+ prior visits', 2
    UNION ALL SELECT '3+ prior visits', 3
),
base AS (
    SELECT number_inpatient, readmit_30
    FROM fact_encounter
    WHERE exclusion_reason IS NULL
),
workload AS (
    SELECT
        o.option_name,
        o.cutoff,
        SUM(b.number_inpatient >= o.cutoff)                  AS encounters_targeted,
        SUM(b.readmit_30 * (b.number_inpatient >= o.cutoff)) AS readmissions_reached,
        SUM(b.number_inpatient >= o.cutoff)
            * @contacts_per_patient * @minutes_per_contact / 60 AS staff_hours
    FROM options o
    CROSS JOIN base b
    GROUP BY o.option_name, o.cutoff
)
SELECT
    option_name,
    encounters_targeted,
    readmissions_reached,
    ROUND(readmissions_reached / 11314 * 100, 1)       AS reach_pct,
    ROUND(staff_hours)                                 AS staff_hours,
    ROUND(staff_hours / readmissions_reached, 1)       AS hours_per_readmission
FROM workload
ORDER BY cutoff;