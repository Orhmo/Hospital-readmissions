# Data Dictionary

Source: UCI Diabetes 130-US Hospitals for Years 1999-2008 (`diabetic_data.csv`, 101,766 rows, 50 columns) and `IDS_mapping.csv`.

**Grain:** one row is one inpatient encounter. A patient can have several encounters.

Missing % is the share of the 99,343 included encounters recorded as `?`, unless stated otherwise.

## 1. Raw encounter fields

### Identifiers

| Field | Type | Definition | Example | Missing % | Treatment |
|---|---|---|---|---|---|
| encounter_id | Integer | Unique ID for each encounter. Also used as a stand-in for visit order, because the data has no dates | 149190 | 0 | Primary key. 0 duplicates found |
| patient_nbr | Integer | Patient ID. One patient can appear several times | 88785891 | 0 | Kept. 69,990 unique patients after exclusions |

### Demographics

| Field | Type | Definition | Example | Missing % | Treatment |
|---|---|---|---|---|---|
| race | Text | Recorded race | Caucasian | 2.2 | `?` relabelled "Unknown". Used only for the fairness check |
| gender | Text | Recorded gender | Female | 0 (3 rows "Unknown/Invalid") | Kept as recorded |
| age | Text (10-year band) | Age band at admission | [70-80) | 0 | Converted to `age_band` (70-79) with `age_sort` |
| weight | Text (band) | Body weight band | [75-100) | 96.9 | **Dropped.** Too sparse to use |
| payer_code | Text | Insurance or payer code | MC | 39.7 | Not used in analysis |

### Admission and discharge (codes explained in Section 2)

| Field | Type | Definition | Example | Missing % | Treatment |
|---|---|---|---|---|---|
| admission_type_id | Integer (code) | How the patient was admitted | 1 (Emergency) | 0, but 10.2% coded as NULL, Not Available or Not Mapped | Joined to `dim_admission_type`. Unusable codes relabelled "Not recorded" |
| discharge_disposition_id | Integer (code) | Where the patient went at discharge | 1 (Home) | 0 | Joined to `dim_discharge_disposition`. Used for exclusions and grouping |
| admission_source_id | Integer (code) | Where the patient came from | 7 (Emergency Room) | 0 | Joined to `dim_admission_source` |
| medical_specialty | Text | Specialty of the admitting physician | InternalMedicine | 48.9 | Not used in analysis |

### Hospital stay

| Field | Type | Definition | Example | Missing % | Treatment |
|---|---|---|---|---|---|
| time_in_hospital | Integer (days) | Length of stay, 1 to 14 days | 3 | 0 | Converted to `los_band` with `los_sort` |
| num_lab_procedures | Integer | Lab tests during the stay | 44 | 0 | Kept |
| num_procedures | Integer | Non-lab procedures during the stay | 1 | 0 | Kept |
| num_medications | Integer | Distinct medications given | 15 | 0 | Converted to `med_band` with `med_sort` |
| number_diagnoses | Integer | Diagnoses recorded | 9 | 0 | Kept |

### Prior use (the year before the encounter)

| Field | Type | Definition | Example | Missing % | Treatment |
|---|---|---|---|---|---|
| number_outpatient | Integer | Outpatient visits in the prior year | 0 | 0 | Kept |
| number_emergency | Integer | Emergency visits in the prior year | 0 | 0 | Kept |
| number_inpatient | Integer | Inpatient stays in the prior year | 2 | 0 | **Basis of the risk tier.** Converted to `prior_inpatient_band` |

### Diagnoses

| Field | Type | Definition | Example | Missing % | Treatment |
|---|---|---|---|---|---|
| diag_1 | Text (ICD-9) | Primary diagnosis | 428 | 0 | Grouped into `diag_group` |
| diag_2 | Text (ICD-9) | Secondary diagnosis | 250.01 | 0.4 | Kept as text |
| diag_3 | Text (ICD-9) | Additional diagnosis | 401 | 1.4 | Kept as text |

### Test results

| Field | Type | Definition | Example | Missing % | Treatment |
|---|---|---|---|---|---|
| A1Cresult | Text | HbA1c result. "None" means **not tested**, not missing | >8 | 0 | "None" relabelled "Not tested" (83.1%) |
| max_glu_serum | Text | Glucose serum result. "None" means not tested | Norm | 0 | "None" relabelled "Not tested" (94.8%) |

### Medications (23 drug columns)

metformin, repaglinide, nateglinide, chlorpropamide, glimepiride, acetohexamide, glipizide, glyburide, tolbutamide, pioglitazone, rosiglitazone, acarbose, miglitol, troglitazone, tolazamide, examide, citoglipton, insulin, glyburide-metformin, glipizide-metformin, glimepiride-pioglitazone, metformin-rosiglitazone, metformin-pioglitazone.

| Property | Detail |
|---|---|
| Type | Text |
| Values | No (not prescribed), Steady, Up (dose increased), Down (dose decreased) |
| Treatment | Hyphens in names replaced with underscores. **examide and citoglipton dropped** (only one value, "No"). The other 21 are unpivoted into `fact_medication` |

### Other flags and the outcome

| Field | Type | Definition | Values | Treatment |
|---|---|---|---|---|
| change | Text | Any change in diabetes medication | Ch, No | Kept |
| diabetesMed | Text | Any diabetes medication prescribed | Yes, No | Kept |
| readmitted | Text | **Outcome.** Readmission timing | <30, >30, NO | Converted to `readmit_30` (1 if `<30`, else 0) |

## 2. Lookup tables (from IDS_mapping.csv)

The mapping file holds three code tables stacked in one file, separated by blank lines. They were split by line position into:

| Table | Key | Rows | Example |
|---|---|---|---|
| dim_admission_type | admission_type_id | 8 | 1 = Emergency, 2 = Urgent, 3 = Elective |
| dim_discharge_disposition | discharge_disposition_id | 30 | 1 = Discharged to home, 11 = Expired |
| dim_admission_source | admission_source_id | 25 | 7 = Emergency Room |

## 3. Derived fields (created in SQL)

| Field | Table | Definition | Values |
|---|---|---|---|
| readmit_30 | fact_encounter | Outcome flag | 1 if `readmitted = '<30'`, else 0 |
| exclusion_reason | fact_encounter | Why an encounter is left out of rates | "Expired" (discharge codes 11, 19, 20, 21), "Hospice" (13, 14), NULL if included |
| age_band, age_sort | fact_encounter | 10-year age band and its sort order | 0-9 to 90-99 |
| los_band, los_sort | fact_encounter | Length of stay band | 1-2, 3-4, 5-7, 8-14 days |
| prior_inpatient_band, prior_inpatient_sort | fact_encounter | Prior inpatient visits band | 0, 1, 2, 3, 4, 5, 6+ |
| med_band, med_sort | fact_encounter | Medication count band | 1-10, 11-15, 16-20, 21-30, 31+ |
| diag_group | fact_encounter | Primary diagnosis grouped by ICD-9 range (see below) | 9 groups |
| in_tier | fact_encounter | Risk tier flag | 1 if number_inpatient is 2 or more, else 0 |
| sample_split | 05_risk_tier.sql | Build or test group, by patient | Build if `MOD(patient_nbr, 10) < 7`, else Test |

### Diagnosis groups (from diag_1)

| Group | ICD-9 codes | Included encounters |
|---|---|---|
| Circulatory | 390 to 459, 785 | 29,681 |
| Respiratory | 460 to 519, 786 | 13,934 |
| Digestive | 520 to 579, 787 | 9,333 |
| Diabetes | 250.xx | 8,661 |
| Injury | 800 to 999 | 6,853 |
| Genitourinary | 580 to 629, 788 | 5,002 |
| Musculoskeletal | 710 to 739 | 4,935 |
| Neoplasms | 140 to 239 | 3,131 |
| Other | All other codes, including V and E codes | 17,813 |

## 4. Final model tables

| Table | Grain | Rows |
|---|---|---|
| fact_encounter | One row per encounter | 101,766 (99,343 included) |
| fact_medication | One row per encounter per drug prescribed | 120,054 |
| dim_admission_type | One row per admission type code | 8 |
| dim_discharge_disposition | One row per discharge code | 30 |
| dim_admission_source | One row per admission source code | 25 |
| dim_diag_group | One row per diagnosis group, with image URL | 9 |
| dim_drug | One row per drug | 21 |

## 5. Power BI fields

| Field | Table | Definition |
|---|---|---|
| Readmission Outcome | Encounters | Within 30d, After 30d or None, from `readmitted` |
| Tier Status | Encounters | In tier or Outside tier, from `in_tier` |
| Discharge Group | Encounters | Discharge codes grouped: Home (1), Home with health service (6), Nursing facility (3, 24), Left against advice (7), Not recorded (18, 25, 26), Excluded (11, 13, 14, 19, 20, 21), Transferred to other care (all others) |
| HbA1c Tested | Encounters | Tested or Not tested |
| Prior Visits Group | Encounters | 0, 1, 2, 3+, used on the Explorer page |
| Admission Group | Admission Type | Emergency, Urgent, Elective, Other or unknown |
| image_url | Diagnosis Group | Link to each group's image on GitHub |

The full list of DAX measures is in `powerbi/dax_measures.txt`.
