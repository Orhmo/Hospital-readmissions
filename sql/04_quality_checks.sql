-- Row counts for every table in the pipeline
SELECT 'stg_encounter' AS table_name, COUNT(*) AS row_count FROM stg_encounter
UNION ALL SELECT 'clean_encounter',           COUNT(*) FROM clean_encounter
UNION ALL SELECT 'fact_encounter',            COUNT(*) FROM fact_encounter
UNION ALL SELECT 'fact_medication',           COUNT(*) FROM fact_medication
UNION ALL SELECT 'stg_ids_mapping',           COUNT(*) FROM stg_ids_mapping
UNION ALL SELECT 'dim_admission_type',        COUNT(*) FROM dim_admission_type
UNION ALL SELECT 'dim_discharge_disposition', COUNT(*) FROM dim_discharge_disposition
UNION ALL SELECT 'dim_admission_source',      COUNT(*) FROM dim_admission_source
UNION ALL SELECT 'dim_diag_group',            COUNT(*) FROM dim_diag_group
UNION ALL SELECT 'dim_drug',                  COUNT(*) FROM dim_drug;

-- Null check: key columns in the fact table
SELECT
    SUM(encounter_id IS NULL)  AS null_encounter_id,
    SUM(patient_nbr IS NULL)   AS null_patient_nbr,
    SUM(readmit_30 IS NULL)    AS null_readmit_30,
    SUM(diag_group IS NULL)    AS null_diag_group,
    SUM(diag_1 IS NULL)        AS null_diag_1
FROM fact_encounter;

-- Duplicate check: encounters and patients
SELECT
    COUNT(*)                     AS total_rows,
    COUNT(DISTINCT encounter_id) AS unique_encounters,
    COUNT(DISTINCT patient_nbr)  AS unique_patients
FROM fact_encounter;

-- Primary key and indexes to speed up joins and filters
ALTER TABLE fact_encounter ADD PRIMARY KEY (encounter_id);
CREATE INDEX idx_fact_admission_type  ON fact_encounter (admission_type_id);
CREATE INDEX idx_fact_discharge       ON fact_encounter (discharge_disposition_id);
CREATE INDEX idx_fact_admission_src   ON fact_encounter (admission_source_id);
CREATE INDEX idx_fact_diag_group      ON fact_encounter (diag_group);
CREATE INDEX idx_med_encounter        ON fact_medication (encounter_id);
