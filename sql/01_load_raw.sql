   CREATE DATABASE meridian;
      USE meridian;
      
      /* --- Data --- */
      CREATE TABLE stg_encounter (
    encounter_id              VARCHAR(20),
    patient_nbr               VARCHAR(20),
    race                      VARCHAR(30),
    gender                    VARCHAR(30),
    age                       VARCHAR(20),
    weight                    VARCHAR(20),
    admission_type_id         VARCHAR(10),
    discharge_disposition_id  VARCHAR(10),
    admission_source_id       VARCHAR(10),
    time_in_hospital          VARCHAR(10),
    payer_code                VARCHAR(10),
    medical_specialty         VARCHAR(100),
    num_lab_procedures        VARCHAR(10),
    num_procedures            VARCHAR(10),
    num_medications           VARCHAR(10),
    number_outpatient         VARCHAR(10),
    number_emergency          VARCHAR(10),
    number_inpatient          VARCHAR(10),
    diag_1                    VARCHAR(10),
    diag_2                    VARCHAR(10),
    diag_3                    VARCHAR(10),
    number_diagnoses          VARCHAR(10),
    max_glu_serum             VARCHAR(10),
    A1Cresult                 VARCHAR(10),
    metformin                 VARCHAR(10),
    repaglinide               VARCHAR(10),
    nateglinide               VARCHAR(10),
    chlorpropamide            VARCHAR(10),
    glimepiride               VARCHAR(10),
    acetohexamide             VARCHAR(10),
    glipizide                 VARCHAR(10),
    glyburide                 VARCHAR(10),
    tolbutamide               VARCHAR(10),
    pioglitazone              VARCHAR(10),
    rosiglitazone             VARCHAR(10),
    acarbose                  VARCHAR(10),
    miglitol                  VARCHAR(10),
    troglitazone              VARCHAR(10),
    tolazamide                VARCHAR(10),
    examide                   VARCHAR(10),
    citoglipton               VARCHAR(10),
    insulin                   VARCHAR(10),
    glyburide_metformin       VARCHAR(10),
    glipizide_metformin       VARCHAR(10),
    glimepiride_pioglitazone  VARCHAR(10),
    metformin_rosiglitazone   VARCHAR(10),
    metformin_pioglitazone    VARCHAR(10),
    `change`                  VARCHAR(10),
    diabetesMed               VARCHAR(10),
    readmitted                VARCHAR(10)
);

DESCRIBE stg_encounter;
   SET GLOBAL local_infile = 1;
   
   LOAD DATA LOCAL INFILE '/Users/macbookair/Desktop/Capstone/data/raw/diabetic_data.csv'
   INTO TABLE stg_encounter
   FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
   LINES TERMINATED BY '\r\n'
   IGNORE 1 LINES;
   
   SELECT * FROM stg_encounter LIMIT 10;
   SELECT readmitted, COUNT(*) FROM stg_encounter GROUP BY readmitted;
   
   /* -- Mapping File --- */
CREATE TABLE stg_ids_mapping (
    line_no      INT AUTO_INCREMENT PRIMARY KEY,
    code         VARCHAR(50),
    description  VARCHAR(255)
);

LOAD DATA LOCAL INFILE '/Users/macbookair/Desktop/Capstone/data/raw/IDS_mapping.csv'
INTO TABLE stg_ids_mapping
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
(code, description);

SELECT * FROM stg_ids_mapping ORDER BY line_no;