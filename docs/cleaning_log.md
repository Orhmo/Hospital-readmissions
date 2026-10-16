# Cleaning Log and Data Lineage

Every change made between the raw files and the dashboard, in the order it happened, with the reason.

## 1. Data lineage

```
diabetic_data.csv ─┐
                   ├─► 01_load_raw.sql ─► stg_encounter, stg_ids_mapping   (exact copies, all text)
IDS_mapping.csv ───┘
                         │
                         ▼
                   02_clean.sql ─► clean_encounter + 3 lookup tables        (types, missing values, exclusions)
                         │
                         ▼
                   03_model.sql ─► fact_encounter, fact_medication,         (bands, groups, star schema)
                                   dim_* tables
                         │
                         ▼
                   04_quality_checks.sql                                    (counts, nulls, keys, indexes)
                         │
                         ▼
                   05_risk_tier.sql, 06_analysis.sql                        (tier, validation, insights)
                         │
                         ▼
                   data/clean/*.csv ─► Power BI (Power Query, DAX) ─► dashboard
```

## 2. Loading (01_load_raw.sql)

| # | Issue found | Action | Reason |
|---|---|---|---|
| 1 | First load returned 0 rows, then 381,602 scrambled rows | Set `LINES TERMINATED BY '\r\n'` | The files use Windows line endings. Correct load: 101,766 rows, 0 warnings |
| 2 | Hyphenated column names (for example glyburide-metformin) | Renamed with underscores | Hyphens break SQL column names |
| 3 | `change` is a reserved word in MySQL | Wrapped in backticks | Avoids syntax errors |
| 4 | Values such as `?`, `None` and `NULL` could be altered on load | Every staging column loaded as text | Keeps the raw values exactly as they arrived, so nothing is changed before it is understood |
| 5 | The mapping file holds three tables stacked together | Loaded with an auto-numbered `line_no` column | Preserves row order so each section can be split out later |

**Check:** 101,766 encounter rows; outcome split NO 54,864, >30 35,545, <30 11,357.

## 3. Cleaning (02_clean.sql)

| # | Field | Issue | Action | Reason |
|---|---|---|---|---|
| 6 | IDS_mapping | Three tables in one file | Split by line position: admission type (lines 2 to 9), discharge disposition (12 to 41), admission source (44 to 68) | Gives three proper lookup tables. A wrong first attempt on admission source was dropped and rebuilt |
| 7 | IDs and counts | Stored as text | Cast to integers | Allows joins, sorting and arithmetic |
| 8 | race, payer_code, medical_specialty, diag_2, diag_3 | `?` used for missing | Converted to NULL or "Unknown" | Makes missing values explicit and countable |
| 9 | A1Cresult, max_glu_serum | "None" means the test was not done | Relabelled "Not tested" | "None" is a real answer, not a missing value. Treating it as missing would hide that 83.1% of encounters had no HbA1c test |
| 10 | weight | 96.9% missing | Dropped | Too sparse to analyse or impute honestly |
| 11 | examide, citoglipton | Only one value ("No") | Dropped | Carry no information |
| 12 | readmitted | Three classes | Added `readmit_30` (1 for `<30`, else 0) | Matches the project definition of the outcome. `>30` is not merged into `<30` |
| 13 | discharge_disposition_id | Expired (11, 19, 20, 21) and hospice (13, 14) patients cannot or rarely return | Added `exclusion_reason` instead of deleting rows | Keeps the rows for transparency, while removing 2,423 encounters from rate calculations |
| 14 | encounter_id | Needed a unique key | Set as primary key | 0 duplicates found |

**Effect of exclusions:** 101,766 rows become 99,343 included encounters from 69,990 patients. The rate moves from 11.16% (all rows) to 11.39%; keeping hospice in would give 11.34%.

## 4. Modelling (03_model.sql)

| # | Action | Reason |
|---|---|---|
| 15 | Built `fact_encounter` with age, length of stay, prior visits and medication bands, each with a sort column | Bands make patterns readable; sort columns keep them in order in SQL and Power BI |
| 16 | Grouped `diag_1` into 9 diagnosis groups by ICD-9 range | 700+ raw codes are too many to compare |
| 17 | Unpivoted 21 drug columns into `fact_medication` with a `CROSS JOIN` (120,054 rows) | One row per drug per encounter is easier to count and filter |
| 18 | Created `dim_diag_group` and `dim_drug` | Completes the star schema |

## 5. Quality checks (04_quality_checks.sql)

| Check | Result |
|---|---|
| Row counts, staging vs model | Match (101,766) |
| Duplicate encounter IDs | 0 |
| Nulls in key fields | 0 |
| Fact rows without a matching dimension row (referential integrity) | 0 for every dimension |
| Primary keys and indexes | Added on IDs used for joins |

## 6. Outliers

| Field | Finding | Decision |
|---|---|---|
| number_emergency | Up to 76 prior visits (99th percentile is 3) | **Kept.** Plausible for frequent attenders, and these are the patients the analysis is trying to find |
| number_outpatient | Up to 42 (99th percentile is 5) | Kept, same reason |
| number_inpatient | Up to 21 (99th percentile is 6) | Kept, and capped at "6+" in the band so a few extreme values do not dominate charts |
| num_medications | Up to 81 (99th percentile is 43) | Kept, grouped into "31+" |
| time_in_hospital | 1 to 14 days, no impossible values | Kept |

No values were deleted as outliers. Extreme values are real encounters, so they were handled with bands rather than removed.

## 7. Power BI (Power Query and DAX)

| # | Step | Reason |
|---|---|---|
| 19 | Renamed tables (Encounters, Medications, Admission Type, Discharge Destination, Admission Source, Diagnosis Group, Drugs) | Readable names for report users |
| 20 | Replaced blank text with null, and null descriptions with "Not recorded" | Consistent labels in slicers and charts |
| 21 | Added `image_url` to Diagnosis Group, pointing at images hosted on GitHub | Powers the Explorer page image |
| 22 | Added `Prior Visits Label` as a text column | Power BI turned "6+" into the number 6 |
| 23 | Measures filter on `exclusion_reason` being blank | Every rate uses included encounters only |
| 24 | `Rate (min 30)` hides rates based on fewer than 30 encounters | Stops small groups (for example 15 encounters) showing misleading rates |
| 25 | Turned off Auto date/time | No date fields; reduces model size and freezes |

Power Query step screenshots are in `PowerBi/powerQuery/`.

## 8. Refresh instructions

1. Re-run the SQL scripts if the raw data changes, then re-export the seven tables to `data/clean/`.
2. In Power BI Desktop, go to **Home**, then **Transform data**, then **Data source settings**, and point each source at the files in `data/clean/`.
3. Click **Refresh**. Check the Overview page shows 99,343 encounters and an 11.4% rate.
