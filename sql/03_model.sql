/* --- Future Engineering --- */
DROP TABLE IF EXISTS fact_encounter;
CREATE TABLE fact_encounter AS
SELECT
    encounter_id,
    patient_nbr,
    admission_type_id,
    discharge_disposition_id,
    admission_source_id,
    race,
    gender,

    -- Age: turn '[70-80)' into a label '70-79' and a sort number 70
    CAST(SUBSTRING_INDEX(SUBSTRING(age, 2), '-', 1) AS UNSIGNED) AS age_sort,
    CONCAT(
        CAST(SUBSTRING_INDEX(SUBSTRING(age, 2), '-', 1) AS UNSIGNED), '-',
        CAST(SUBSTRING_INDEX(SUBSTRING(age, 2), '-', 1) AS UNSIGNED) + 9
    ) AS age_band,

    -- Length of stay, raw and banded
    time_in_hospital,
    CASE
        WHEN time_in_hospital <= 2 THEN '1-2 days'
        WHEN time_in_hospital <= 4 THEN '3-4 days'
        WHEN time_in_hospital <= 7 THEN '5-7 days'
        ELSE '8-14 days'
    END AS los_band,
    CASE
        WHEN time_in_hospital <= 2 THEN 1
        WHEN time_in_hospital <= 4 THEN 2
        WHEN time_in_hospital <= 7 THEN 3
        ELSE 4
    END AS los_sort,

    -- Prior-year inpatient visits, raw and banded (6 or more grouped)
    number_inpatient,
    CASE WHEN number_inpatient >= 6 THEN '6+'
         ELSE CAST(number_inpatient AS CHAR) END AS prior_inpatient_band,
    LEAST(number_inpatient, 6) AS prior_inpatient_sort,

    -- Medication count, raw and banded
    num_medications,
    CASE
        WHEN num_medications <= 10 THEN '1-10'
        WHEN num_medications <= 15 THEN '11-15'
        WHEN num_medications <= 20 THEN '16-20'
        WHEN num_medications <= 30 THEN '21-30'
        ELSE '31+'
    END AS med_band,
    CASE
        WHEN num_medications <= 10 THEN 1
        WHEN num_medications <= 15 THEN 2
        WHEN num_medications <= 20 THEN 3
        WHEN num_medications <= 30 THEN 4
        ELSE 5
    END AS med_sort,

    -- Primary diagnosis grouped by ICD-9 code range
    diag_1,
    CASE
        WHEN diag_1 IS NULL OR diag_1 LIKE 'V%' OR diag_1 LIKE 'E%' THEN 'Other'
        WHEN FLOOR(CAST(diag_1 AS DECIMAL(6,2))) = 250                 THEN 'Diabetes'
        WHEN CAST(diag_1 AS DECIMAL(6,2)) BETWEEN 390 AND 459.99
          OR FLOOR(CAST(diag_1 AS DECIMAL(6,2))) = 785                 THEN 'Circulatory'
        WHEN CAST(diag_1 AS DECIMAL(6,2)) BETWEEN 460 AND 519.99
          OR FLOOR(CAST(diag_1 AS DECIMAL(6,2))) = 786                 THEN 'Respiratory'
        WHEN CAST(diag_1 AS DECIMAL(6,2)) BETWEEN 520 AND 579.99
          OR FLOOR(CAST(diag_1 AS DECIMAL(6,2))) = 787                 THEN 'Digestive'
        WHEN CAST(diag_1 AS DECIMAL(6,2)) BETWEEN 800 AND 999.99       THEN 'Injury'
        WHEN CAST(diag_1 AS DECIMAL(6,2)) BETWEEN 710 AND 739.99       THEN 'Musculoskeletal'
        WHEN CAST(diag_1 AS DECIMAL(6,2)) BETWEEN 580 AND 629.99
          OR FLOOR(CAST(diag_1 AS DECIMAL(6,2))) = 788                 THEN 'Genitourinary'
        WHEN CAST(diag_1 AS DECIMAL(6,2)) BETWEEN 140 AND 239.99       THEN 'Neoplasms'
        ELSE 'Other'
    END AS diag_group,

    -- Other measures and test results
    num_lab_procedures,
    num_procedures,
    number_outpatient,
    number_emergency,
    number_diagnoses,
    a1c_result,
    max_glu_serum,
    med_change,
    diabetes_med,

    -- Outcome and exclusion
    readmitted,
    readmit_30,
    exclusion_reason
FROM clean_encounter;

SELECT COUNT(*) FROM fact_encounter;

SELECT diag_group,
       COUNT(*)                         AS encounters,
       ROUND(AVG(readmit_30) * 100, 1)  AS rate_pct
FROM fact_encounter
WHERE exclusion_reason IS NULL
GROUP BY diag_group
ORDER BY rate_pct DESC;

/* --- Diagnosis group lookup table --- */
DROP TABLE IF EXISTS dim_diag_group;
CREATE TABLE dim_diag_group (
    diag_group   VARCHAR(20) PRIMARY KEY,
    diag_sort    TINYINT,
    icd9_codes   VARCHAR(60),
    image_url    VARCHAR(255)
);

INSERT INTO dim_diag_group (diag_group, diag_sort, icd9_codes) VALUES
    ('Diabetes',        1, '250.xx'),
    ('Circulatory',     2, '390-459, 785'),
    ('Respiratory',     3, '460-519, 786'),
    ('Digestive',       4, '520-579, 787'),
    ('Genitourinary',   5, '580-629, 788'),
    ('Musculoskeletal', 6, '710-739'),
    ('Injury',          7, '800-999'),
    ('Neoplasms',       8, '140-239'),
    ('Other',           9, 'All other codes, V and E codes, missing');
    
/* -- Referential integrity: no matching diagnosis group -- */
SELECT COUNT(*) AS unmatched
FROM fact_encounter f
LEFT JOIN dim_diag_group d
       ON f.diag_group = d.diag_group
WHERE d.diag_group IS NULL;

/* -- Referential integrity: admission type -- */
SELECT COUNT(*) AS unmatched
FROM fact_encounter f
LEFT JOIN dim_admission_type d
       ON f.admission_type_id = d.admission_type_id
WHERE d.admission_type_id IS NULL;

/* -- Referential integrity: discharge disposition -- */
SELECT COUNT(*) AS unmatched
FROM fact_encounter f
LEFT JOIN dim_discharge_disposition d
       ON f.discharge_disposition_id = d.discharge_disposition_id
WHERE d.discharge_disposition_id IS NULL;

/* -- Referential integrity: admission source -- */
SELECT COUNT(*) AS unmatched
FROM fact_encounter f
LEFT JOIN dim_admission_source d
       ON f.admission_source_id = d.admission_source_id
WHERE d.admission_source_id IS NULL;

/* -- 30-day readmission rate by admission type -- */
SELECT
    d.admission_type,
    COUNT(*)                         AS encounters,
    SUM(f.readmit_30)                AS readmitted_30,
    ROUND(AVG(f.readmit_30) * 100, 1) AS rate_pct
FROM fact_encounter f
INNER JOIN dim_admission_type d
        ON f.admission_type_id = d.admission_type_id
WHERE f.exclusion_reason IS NULL
GROUP BY d.admission_type
ORDER BY encounters DESC;

/* -- Lookup table: the 21 diabetes drugs and their classes -- */
DROP TABLE IF EXISTS dim_drug;
CREATE TABLE dim_drug (
    drug        VARCHAR(30) PRIMARY KEY,
    drug_class  VARCHAR(40)
);

INSERT INTO dim_drug (drug, drug_class) VALUES
    ('metformin',                'Biguanide'),
    ('repaglinide',              'Meglitinide'),
    ('nateglinide',              'Meglitinide'),
    ('chlorpropamide',           'Sulfonylurea'),
    ('glimepiride',              'Sulfonylurea'),
    ('acetohexamide',            'Sulfonylurea'),
    ('glipizide',                'Sulfonylurea'),
    ('glyburide',                'Sulfonylurea'),
    ('tolbutamide',              'Sulfonylurea'),
    ('tolazamide',               'Sulfonylurea'),
    ('pioglitazone',             'Thiazolidinedione'),
    ('rosiglitazone',            'Thiazolidinedione'),
    ('troglitazone',             'Thiazolidinedione'),
    ('acarbose',                 'Alpha-glucosidase inhibitor'),
    ('miglitol',                 'Alpha-glucosidase inhibitor'),
    ('insulin',                  'Insulin'),
    ('glyburide_metformin',      'Combination'),
    ('glipizide_metformin',      'Combination'),
    ('glimepiride_pioglitazone', 'Combination'),
    ('metformin_rosiglitazone',  'Combination'),
    ('metformin_pioglitazone',   'Combination');
    
  /*  -- Medication table: one row per drug a patient was on during the encounter -- */
DROP TABLE IF EXISTS fact_medication;
CREATE TABLE fact_medication AS
SELECT encounter_id, drug, status
FROM (
    SELECT
        c.encounter_id,
        m.drug,
        CASE m.drug
            WHEN 'metformin'                THEN c.metformin
            WHEN 'repaglinide'              THEN c.repaglinide
            WHEN 'nateglinide'              THEN c.nateglinide
            WHEN 'chlorpropamide'           THEN c.chlorpropamide
            WHEN 'glimepiride'              THEN c.glimepiride
            WHEN 'acetohexamide'            THEN c.acetohexamide
            WHEN 'glipizide'                THEN c.glipizide
            WHEN 'glyburide'                THEN c.glyburide
            WHEN 'tolbutamide'              THEN c.tolbutamide
            WHEN 'tolazamide'               THEN c.tolazamide
            WHEN 'pioglitazone'             THEN c.pioglitazone
            WHEN 'rosiglitazone'            THEN c.rosiglitazone
            WHEN 'troglitazone'             THEN c.troglitazone
            WHEN 'acarbose'                 THEN c.acarbose
            WHEN 'miglitol'                 THEN c.miglitol
            WHEN 'insulin'                  THEN c.insulin
            WHEN 'glyburide_metformin'      THEN c.glyburide_metformin
            WHEN 'glipizide_metformin'      THEN c.glipizide_metformin
            WHEN 'glimepiride_pioglitazone' THEN c.glimepiride_pioglitazone
            WHEN 'metformin_rosiglitazone'  THEN c.metformin_rosiglitazone
            WHEN 'metformin_pioglitazone'   THEN c.metformin_pioglitazone
        END AS status
    FROM clean_encounter c
    CROSS JOIN dim_drug m
) AS all_drugs
WHERE status <> 'No';

/* -- Most commonly prescribed drugs -- */
SELECT m.drug, d.drug_class, COUNT(*) AS encounters
FROM fact_medication m
INNER JOIN dim_drug d ON m.drug = d.drug
GROUP BY m.drug, d.drug_class
ORDER BY encounters DESC
LIMIT 6;

