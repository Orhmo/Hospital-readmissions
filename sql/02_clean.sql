/* -- Lookup Tables --- */

-- Admission Type Lookup
CREATE TABLE dim_admission_type AS
SELECT
    CAST(code AS UNSIGNED)  AS admission_type_id,
    TRIM(description)       AS admission_type
FROM stg_ids_mapping
WHERE line_no BETWEEN 2 AND 9;

SELECT * FROM dim_admission_type;

-- Discharge disposition lookup
CREATE TABLE dim_discharge_disposition AS
SELECT
    CAST(code AS UNSIGNED)  AS discharge_disposition_id,
    TRIM(description)       AS discharge_disposition
FROM stg_ids_mapping
WHERE line_no BETWEEN 12 AND 41;

SELECT * FROM dim_discharge_disposition;

-- Admission Source lookup
CREATE TABLE dim_admission_source AS
SELECT
    CAST(code AS UNSIGNED)  AS admission_source_id,
    TRIM(description)       AS admission_source
FROM stg_ids_mapping
WHERE line_no BETWEEN 44 AND 68;

SELECT * FROM dim_admission_source;

/* -- Placeholder values -- */
SELECT
    SUM(race = '?')                 AS race_unknown,
    SUM(gender = 'Unknown/Invalid') AS gender_unknown,
    SUM(weight = '?')               AS weight_missing,
    SUM(payer_code = '?')           AS payer_missing,
    SUM(medical_specialty = '?')    AS specialty_missing,
    SUM(diag_1 = '?')               AS diag1_missing,
    SUM(A1Cresult = 'None')         AS a1c_not_tested,
    SUM(max_glu_serum = 'None')     AS glucose_not_tested
FROM stg_encounter;

/* -- Build the clean encounter table --- */
DROP TABLE IF EXISTS clean_encounter;
CREATE TABLE clean_encounter AS
SELECT
    CAST(encounter_id AS UNSIGNED)              AS encounter_id,
    CAST(patient_nbr AS UNSIGNED)               AS patient_nbr,
    CASE WHEN race = '?' THEN 'Unknown' ELSE race END                 AS race,
    CASE WHEN gender = 'Unknown/Invalid' THEN 'Unknown' ELSE gender END AS gender,
    age,
    CAST(admission_type_id AS UNSIGNED)         AS admission_type_id,
    CAST(discharge_disposition_id AS UNSIGNED)  AS discharge_disposition_id,
    CAST(admission_source_id AS UNSIGNED)       AS admission_source_id,
    CAST(time_in_hospital AS UNSIGNED)          AS time_in_hospital,
    CASE WHEN payer_code = '?' THEN 'Unknown' ELSE payer_code END     AS payer_code,
    CASE WHEN medical_specialty = '?' THEN 'Unknown' ELSE medical_specialty END AS medical_specialty,
    CAST(num_lab_procedures AS UNSIGNED)        AS num_lab_procedures,
    CAST(num_procedures AS UNSIGNED)            AS num_procedures,
    CAST(num_medications AS UNSIGNED)           AS num_medications,
    CAST(number_outpatient AS UNSIGNED)         AS number_outpatient,
    CAST(number_emergency AS UNSIGNED)          AS number_emergency,
    CAST(number_inpatient AS UNSIGNED)          AS number_inpatient,
    NULLIF(diag_1, '?')                         AS diag_1,
    NULLIF(diag_2, '?')                         AS diag_2,
    NULLIF(diag_3, '?')                         AS diag_3,
    CAST(number_diagnoses AS UNSIGNED)          AS number_diagnoses,
    CASE WHEN max_glu_serum = 'None' THEN 'Not tested' ELSE max_glu_serum END AS max_glu_serum,
    CASE WHEN A1Cresult = 'None' THEN 'Not tested' ELSE A1Cresult END         AS a1c_result,
    metformin, repaglinide, nateglinide, chlorpropamide, glimepiride,
    acetohexamide, glipizide, glyburide, tolbutamide, pioglitazone,
    rosiglitazone, acarbose, miglitol, troglitazone, tolazamide, insulin,
    glyburide_metformin, glipizide_metformin, glimepiride_pioglitazone,
    metformin_rosiglitazone, metformin_pioglitazone,
    `change`                                    AS med_change,
    diabetesMed                                 AS diabetes_med,
    readmitted
FROM stg_encounter;

/* --- Create a unique identifier --- */
ALTER TABLE clean_encounter ADD PRIMARY KEY (encounter_id);

/* --- Add the outcome flag and the exclusion flag --- */
ALTER TABLE clean_encounter
    ADD COLUMN readmit_30 TINYINT,
    ADD COLUMN exclusion_reason VARCHAR(20);
    
/* --- if readmitted <= 30 days then 1 , otherwise 0 --- */
UPDATE clean_encounter
SET readmit_30 = CASE WHEN readmitted = '<30' THEN 1 ELSE 0 END
WHERE encounter_id > 0;

/* --- Flag discharges that cannot be readmitted (expired) or should not (hospice) count --- */
UPDATE clean_encounter
SET exclusion_reason = CASE
        WHEN discharge_disposition_id IN (11, 19, 20, 21) THEN 'Expired'
        WHEN discharge_disposition_id IN (13, 14)         THEN 'Hospice'
        ELSE NULL
    END
WHERE encounter_id > 0;

SELECT exclusion_reason,
       COUNT(*)        AS encounters,
       SUM(readmit_30) AS readmitted_30
FROM clean_encounter
GROUP BY exclusion_reason;

SELECT ROUND(AVG(readmit_30) * 100, 2) AS readmission_rate_pct
FROM clean_encounter
WHERE exclusion_reason IS NULL;