/* 06_analysis.sql
   Exploratory analysis: 10 questions behind the dashboard insights.
   Every query uses included encounters only (exclusion_reason IS NULL). */

USE meridian;

-- Q1. What is the baseline 30-day readmission rate?
SELECT
    COUNT(*)                        AS encounters,
    SUM(readmit_30)                 AS readmissions,
    ROUND(100 * AVG(readmit_30), 2) AS rate_pct,
    COUNT(DISTINCT patient_nbr)     AS unique_patients
FROM fact_encounter
WHERE exclusion_reason IS NULL;

-- Q2. Are the same patients coming back?
-- 1 (CTE): count encounters and readmissions for each patient.
-- 2: group patients by how many encounters they had.
WITH per_patient AS (
    SELECT
        patient_nbr,
        COUNT(*)         AS n_encounters,
        SUM(readmit_30)  AS n_readmissions
    FROM fact_encounter
    WHERE exclusion_reason IS NULL
    GROUP BY patient_nbr
)
SELECT
    CASE
        WHEN n_encounters = 1 THEN '1 encounter'
        WHEN n_encounters = 2 THEN '2 encounters'
        WHEN n_encounters <= 4 THEN '3 to 4 encounters'
        ELSE '5 or more encounters'
    END                                                         AS patient_group,
    COUNT(*)                                                    AS patients,
    ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)            AS pct_of_patients,
    SUM(n_readmissions)                                         AS readmissions,
    ROUND(100 * SUM(n_readmissions) / SUM(SUM(n_readmissions)) OVER (), 1) AS pct_of_readmissions
FROM per_patient
GROUP BY patient_group
ORDER BY MIN(n_encounters);

-- Q3. Do prior inpatient visits matter?
SELECT
    prior_inpatient_band,
    COUNT(*)                        AS encounters,
    SUM(readmit_30)                 AS readmissions,
    ROUND(100 * AVG(readmit_30), 1) AS rate_pct
FROM fact_encounter
WHERE exclusion_reason IS NULL
GROUP BY prior_inpatient_band, prior_inpatient_sort
ORDER BY prior_inpatient_sort;

-- Q4. Does age matter?
SELECT
    age_band,
    COUNT(*)                        AS encounters,
    SUM(readmit_30)                 AS readmissions,
    ROUND(100 * AVG(readmit_30), 1) AS rate_pct
FROM fact_encounter
WHERE exclusion_reason IS NULL
GROUP BY age_band, age_sort
ORDER BY age_sort;

-- Q5. Which primary diagnosis groups have the highest rates?
SELECT
    diag_group,
    COUNT(*)                        AS encounters,
    SUM(readmit_30)                 AS readmissions,
    ROUND(100 * AVG(readmit_30), 1) AS rate_pct
FROM fact_encounter
WHERE exclusion_reason IS NULL
GROUP BY diag_group
ORDER BY rate_pct DESC;

-- Q6. Does admission type matter? (JOIN to the dimension table)
SELECT
    COALESCE(a.admission_type, 'Not recorded') AS admission_type,
    COUNT(*)                                   AS encounters,
    SUM(f.readmit_30)                          AS readmissions,
    ROUND(100 * AVG(f.readmit_30), 1)          AS rate_pct
FROM fact_encounter AS f
JOIN dim_admission_type AS a
    ON f.admission_type_id = a.admission_type_id
WHERE f.exclusion_reason IS NULL
GROUP BY 1
ORDER BY encounters DESC;

-- Q7. Does discharge destination matter? (CASE groups the codes)
SELECT
    CASE
        WHEN discharge_disposition_id = 1           THEN 'Home'
        WHEN discharge_disposition_id = 6           THEN 'Home with health service'
        WHEN discharge_disposition_id IN (3, 24)    THEN 'Nursing facility'
        WHEN discharge_disposition_id = 7           THEN 'Left against advice'
        WHEN discharge_disposition_id IN (18, 25, 26) THEN 'Not recorded'
        ELSE 'Transferred to other care'
    END                             AS discharge_group,
    COUNT(*)                        AS encounters,
    SUM(readmit_30)                 AS readmissions,
    ROUND(100 * AVG(readmit_30), 1) AS rate_pct
FROM fact_encounter
WHERE exclusion_reason IS NULL
GROUP BY discharge_group
ORDER BY rate_pct DESC;

-- Q8. Does medication count matter?
SELECT
    med_band,
    COUNT(*)                        AS encounters,
    SUM(readmit_30)                 AS readmissions,
    ROUND(100 * AVG(readmit_30), 1) AS rate_pct
FROM fact_encounter
WHERE exclusion_reason IS NULL
GROUP BY med_band, med_sort
ORDER BY med_sort;

-- Q9. Does length of stay matter?
SELECT
    los_band,
    COUNT(*)                        AS encounters,
    SUM(readmit_30)                 AS readmissions,
    ROUND(100 * AVG(readmit_30), 1) AS rate_pct
FROM fact_encounter
WHERE exclusion_reason IS NULL
GROUP BY los_band, los_sort
ORDER BY los_sort;

-- Q10. Are later visits riskier than a patient's first visit?
-- The data has no admission dates, so encounter_id is used as a date
-- substitute: a higher encounter_id means a later visit.
WITH ordered AS (
    SELECT
        patient_nbr,
        readmit_30,
        ROW_NUMBER() OVER (PARTITION BY patient_nbr ORDER BY encounter_id) AS visit_number
    FROM fact_encounter
    WHERE exclusion_reason IS NULL
)
SELECT
    CASE
        WHEN visit_number = 1 THEN '1st visit'
        WHEN visit_number = 2 THEN '2nd visit'
        ELSE '3rd visit or later'
    END                             AS visit_order,
    COUNT(*)                        AS encounters,
    SUM(readmit_30)                 AS readmissions,
    ROUND(100 * AVG(readmit_30), 1) AS rate_pct
FROM ordered
GROUP BY visit_order
ORDER BY MIN(visit_number);