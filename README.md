# Diabetic 30-Day Readmission Analysis

Identifying which diabetic patients are at elevated risk of readmission before they leave hospital, and where a limited care-coordination budget would do the most good.

![Dashboard overview](Screenshots/PowerBi/01_overview.png)

## Contents

1. [Executive summary](#executive-summary)
2. [Project overview](#project-overview)
3. [Data source](#data-source)
4. [Problem statement](#problem-statement)
5. [Tools and methodology](#tools-and-methodology)
6. [Exploratory data analysis](#exploratory-data-analysis)
7. [Key insights](#key-insights)
8. [Dashboard](#dashboard)
9. [Recommendations](#recommendations)
10. [Implementation](#implementation)
11. [Limitations](#limitations)
12. [Conclusion](#conclusion)
13. [Documentation and links](#documentation-and-links)
14. [Repository structure](#repository-structure)
15. [How to reproduce](#how-to-reproduce)

## Executive summary

This project analyses 99,343 hospital encounters for diabetic patients to find who is most likely to be readmitted within 30 days, and how a care-coordination team with limited time should respond. About 1 in 9 encounters (11.4%) ended in a 30-day readmission, and most readmissions came from a small group of returning patients. A simple rule, **flag patients with 2 or more inpatient stays in the past year**, picks out 14.2% of encounters that hold 27.5% of readmissions, at a 22.0% rate against 9.6% for everyone else. The rule held up on patients it was not built on, and targeting it needs about 9,409 staff hours instead of 66,229 to contact everyone. The recommendation is a small pilot on one ward, with fairness monitored throughout.

## Project overview

**Domain:** healthcare, population health and hospital discharge planning.

**Context:** Meridian Care Network (a fictional healthcare network) has seen diabetic readmissions flagged again by its quality committee. Readmissions within 30 days are costly, often avoidable, and a common measure of hospital quality. The network has a care-coordination team that can follow up with patients after discharge, but not enough capacity to contact everyone.

**Why it matters:** the VP of Population Health did not want another chart showing that the number went up. The aim was something the discharge planning team can use on a Tuesday morning: a clear, explainable way to decide who gets follow-up, with the cost in staff time.

## Data source

| | |
|---|---|
| **Source** | [Diabetes 130-US Hospitals for Years 1999-2008](https://archive.ics.uci.edu/dataset/296/diabetes+130-us+hospitals+for+years+1999-2008), UCI Machine Learning Repository |
| **Citation** | Clore, J., Cios, K., DeShazo, J. and Strack, B. (2014). DOI: [10.24432/C5230J](https://doi.org/10.24432/C5230J) |
| **Licence** | CC BY 4.0 |
| **Type** | De-identified clinical encounter records |
| **Size** | 101,766 inpatient encounters, 50 columns, 71,518 unique patients, 130 US hospitals |
| **Lookup file** | IDS_mapping.csv, holding three code tables (admission type, discharge disposition, admission source) stacked in one file |
| **Grain** | One row is one hospital encounter, not one patient |

**Outcome:** an encounter counts as readmitted when `readmitted = "<30"` (readmitted within 30 days of discharge). Readmissions after 30 days are treated as not readmitted.

**Exclusions:** 2,423 encounters ending in death (discharge codes 11, 19, 20, 21) or hospice (13, 14) are excluded, because these patients cannot or are very unlikely to return. This leaves **99,343 included encounters from 69,990 patients**.

**Known limitations of the data:** no admission dates, records from 1999 to 2008, readmissions to other hospitals not captured, and several sparse fields (for example weight is 96.9% missing).

## Problem statement

The stakeholder needed answers to three questions:

1. **Number:** how often are diabetic patients readmitted within 30 days?
2. **Pattern:** which characteristics are associated with higher readmission rates?
3. **Action:** how should a limited care-coordination team target its time, and how much work would that involve?

## Tools and methodology

### Tools

- **MySQL 8 (MySQL Workbench):** loading, cleaning, modelling, quality checks and analysis
- **Python (Google Colab, pandas, SciPy, matplotlib):** summary statistics, correlation, significance tests and EDA charts
- **Power BI Desktop:** Power Query, DAX measures and the interactive dashboard
- **GitHub:** version control and hosting the images used in the dashboard

### Workflow

```
Raw CSVs ─► Load (staging) ─► Clean ─► Model (star schema) ─► Quality checks
        ─► Analysis (SQL + Python) ─► Risk tier and validation ─► Power BI dashboard ─► Recommendations
```

| File | What it does |
|---|---|
| `01_load_raw.sql` | Loads both CSV files into text-only staging tables, exactly as they arrive |
| `02_clean.sql` | Splits the mapping file into three lookup tables, converts data types, standardises missing values and flags exclusions |
| `03_model.sql` | Builds a star schema with analysis bands (age, length of stay, prior visits, medications, diagnosis group) and unpivots the drug columns into a medication fact table |
| `04_quality_checks.sql` | Checks row counts, nulls, duplicates and referential integrity, then adds primary keys and indexes |
| `05_risk_tier.sql` | Compares tier cutoffs, validates the chosen tier on held-out patients, builds the capture curve and estimates workload |
| `06_analysis.sql` | Ten exploratory questions behind the insights |

SQL techniques used include CTEs, window functions (`ROW_NUMBER`, `RANK`, `SUM OVER`), `CASE`, `COALESCE`, joins, `CROSS JOIN` for unpivoting, primary keys and indexes. Query results are in [`sql/Sample_Outputs.docx`](sql/Sample_Outputs.docx).

### Data cleaning and preparation

| Issue | Decision |
|---|---|
| `?` used for missing values | Converted to NULL or "Unknown", depending on the column |
| `None` in the HbA1c field means the test was not done | Relabelled "Not tested" rather than treated as missing (83.1% of included encounters) |
| `weight` is 96.9% missing | Column dropped |
| `examide` and `citoglipton` hold a single value | Columns dropped |
| Mapping file has three tables stacked in one | Split by line position into three lookup tables |
| Admission type 6 is labelled "NULL" in the mapping | Relabelled "Not recorded". With "Not Available" and "Not Mapped", 10.2% of encounters have no usable admission type |
| Raw files use Windows line endings | Loaded with `LINES TERMINATED BY '\r\n'` |

### Data transformation

- Age, length of stay, prior inpatient visits and medication count grouped into bands, each with a sort order.
- Over 700 primary diagnosis codes grouped into 9 diagnosis groups by ICD-9 range.
- 21 drug columns unpivoted into one row per encounter per drug (120,054 rows).
- A 30-day readmission flag and an exclusion flag added to every encounter.

### Data model

A star schema with two fact tables (`fact_encounter`, `fact_medication`) and five dimensions (admission type, discharge disposition, admission source, diagnosis group, drug).

![Data model](PowerBi/powerQuery/model_view.png)

### DAX measures

48 measures in total. Key ones include Readmission Rate, Tier Rate, Rest Rate, Capture Rate, Lift, Staff Hours (Tier and All), Hours per Readmission (Tier and All), Option measures for comparing cutoffs, and Rate (min 30), which hides rates based on fewer than 30 encounters. Every rate counts included encounters only. The full list is in [`PowerBi/dax_measures.txt`](PowerBi/dax_measures.txt), and the Power Query steps are in [`PowerBi/powerQuery/`](PowerBi/powerQuery/).

### Data validation

- Row counts matched between staging and model tables (101,766), with 0 duplicate encounter IDs and 0 orphaned keys.
- Every headline figure matched across SQL, Python and Power BI (99,343 encounters, 11,314 readmissions, 11.39%).
- The risk tier was built on 70% of patients and tested on the other 30% (`MOD(patient_nbr, 10) < 7`), so no patient appears in both groups.

### Workload assumptions

Staff hours assume **2 contacts per patient at 20 minutes each**. Both values are adjustable with what-if sliders on the Workload page of the dashboard.

## Exploratory data analysis

| | Finding |
|---|---|
| **Distributions** | Length of stay and medication count are right-skewed (median 4 days and 15 medications). 66.7% of encounters have no prior inpatient visits |
| **Outliers** | Prior visits reach up to 76 emergency and 21 inpatient. These are real frequent attenders, so they were kept and grouped into open-ended bands ("6+", "31+") rather than removed |
| **Missing values** | Weight 96.9%, medical specialty 48.9%, payer code 39.7%, race 2.2% |
| **Correlations** | Prior inpatient visits has the strongest link with readmission (Spearman 0.14), more than twice any other numeric field. Length of stay and medications move together (0.46) |
| **Trends** | The data has no dates, so trends over time cannot be measured. Visit order (using `encounter_id`) shows risk rising with each return |

![Correlation with readmission](Screenshots/EDA/eda_correlation_outcome.png)

The full EDA, with distributions, missing values, outliers and the correlation matrix, is in [`docs/eda_report.md`](docs/eda_report.md).

## Key insights

All insights describe **associations in historical data**, not causes.

**1. Readmissions are concentrated in returning patients.**
Patients with 2 or more encounters are 23.4% of patients but account for 79.8% of readmissions. This suggests the problem sits with a recognisable group rather than being spread evenly, so targeting can reach many readmissions with limited effort.

**2. Previous hospital stays are the clearest warning sign.**
The 30-day rate rises steadily from 8.6% with no prior inpatient visits to 40.6% with 6 or more, and the same pattern holds within every diagnosis group. Prior stays likely reflect more complex or less stable health, which makes this field a practical, already-recorded signal for discharge planning.

**3. Where patients go after discharge matters.**
Encounters transferred to other care had a 20.0% rate, compared with 9.3% for those discharged home. Transfers may signal higher need and more hand-offs between services, which points to discharge destination as a useful second prompt.

**4. Most other factors move the rate only a little.**
Age (adults 30 to 99: 9.8% to 12.6%), diagnosis group (9.5% to 13.1%), admission type (10.5% to 11.8%), medications and length of stay each shift the rate by under 5 points. They are useful context for a care plan, but too weak to target on.

**5. A one-line rule works on unseen patients.**
Encounters with 2 or more prior inpatient visits have a 22.0% rate against 9.6% for the rest (chi-square 1,841, p < 0.001). On the 30% of patients held back for testing, the flagged group still had 2.07 times the rate of others and held 25.6% of readmissions, so the rule is not just fitted to the data it came from.

**6. Targeting halves the effort per readmission reached.**
Contacting everyone would take about 66,229 staff hours, or 5.9 hours per readmission reached. The flagged group takes 9,409 hours, or 3.0 hours per readmission, which makes the case for a limited budget.

## Dashboard

Five pages, built in Power BI:

| Page | Question it answers |
|---|---|
| **Overview** | How big is the problem? |
| **Patterns** | Which characteristics go with higher rates? |
| **Risk Tier** | Who should be flagged, and how well does the flag work? |
| **Workload** | What would targeting cost in staff time? |
| **Explorer** | How do the patterns look within each diagnosis group? |

**KPIs shown:** encounters, unique patients, 30-day readmission rate, average length of stay, tier share, tier rate, readmissions captured, staff hours and hours per readmission reached.

**Filters and interaction:** an admission type filter synced across all pages, a Filters panel (age, discharge destination, HbA1c testing), an Insights panel on every page, what-if sliders for staffing assumptions, and diagnosis group buttons. Rates based on fewer than 30 encounters are hidden so small groups do not mislead.

| | |
|---|---|
| ![Patterns](Screenshots/PowerBi/02_patterns.png) | ![Risk Tier](Screenshots/PowerBi/03_risk_tier.png) |
| ![Workload](Screenshots/PowerBi/04_workload.png) | ![Explorer](Screenshots/PowerBi/05_explorer.png) |

A PDF of every page is in [`PowerBi/Meridian_Readmissions_Dashboard.pdf`](PowerBi/Meridian_Readmissions_Dashboard.pdf).

## Recommendations

**1. Flag patients with 2 or more inpatient stays in the past year at discharge** (insights 2 and 5).
Add the question to the discharge checklist and give flagged patients two follow-up contacts within 30 days. It uses a field already in the record, needs no model, and anyone can see why a patient was flagged.

**2. Use discharge destination as a second prompt** (insight 3).
For patients transferred to other care, confirm the hand-over with the receiving service, as this group had double the rate of patients sent home.

**3. Match the cutoff to capacity** (insight 6).
Start with 2 or more stays. If capacity is tighter, the 3+ option reaches 15.9% of readmissions for 4,543 hours; with more budget, 1+ reaches 49.7% for 22,065 hours.

**4. Improve recording of admission type** (data quality).
10.2% of encounters have no usable admission type. Better recording would make future analysis more reliable.

**5. Monitor fairness** (insight 5).
The rule uses no demographic fields, but the share flagged ranges from 6.7% to 15.8% by race. Review who is flagged, and their outcomes, every quarter.

**Illustrative impact:** if follow-up prevented 1 in 10 readmissions in the flagged group, that would be around 311 fewer readmissions across this data. This is an assumption to test, not a measured effect.

## Implementation

| | Pilot plan |
|---|---|
| **What** | Pilot the 2+ flag and two follow-up contacts on one ward |
| **Who** | Discharge planning lead (flagging), care-coordination team (follow-up), Population Health analytics (measurement), VP of Population Health (decision to scale) |
| **When** | Month 1: add the question to the discharge checklist and train staff. Months 1 to 3: run the pilot. Month 4: compare results and decide whether to scale |
| **Success measures** | Lower 30-day readmission rate on the pilot ward than a similar comparison ward; at least 80% of flagged patients contacted; hours per readmission reached at or below 3.0 |
| **Resources** | About 40 minutes of staff time per flagged patient, plus the existing dashboard for monitoring |
| **Risks** | Patterns from older data may not hold today (re-check on current local data first); the flag misses 72.5% of readmissions (keep clinical judgement and allow staff referrals); unequal flagging by group (quarterly fairness review) |

## Limitations

- **Association, not causation.** The patterns describe what was observed, not why it happened.
- **Historical data.** Encounters date from 1999 to 2008, so absolute rates may not reflect current practice.
- **No admission dates.** `encounter_id` is used as a stand-in for visit order, and trends over time cannot be measured.
- **Readmissions are only those recorded** in this dataset. Returns to other hospitals are not captured.
- **Encounters, not patients.** Most figures count encounters, and one patient can appear several times.
- **Concentration is partly built in.** Patients who are readmitted naturally have more encounters on record.
- **Not clinically validated.** The tier is an analytical flag for prioritising follow-up, not a prediction model or a diagnosis.

## Conclusion

Diabetic readmissions in this data cluster among patients who have already been in hospital. A simple rule, two or more inpatient stays in the past year, picks out one encounter in seven at more than double the usual risk, and lets a care-coordination team reach over a quarter of readmissions for about a seventh of the effort of contacting everyone. The value of the project is not the dashboard itself but a clear, explainable and costed decision: who to follow up, and why. The next step is a small pilot on current local data, measured carefully, with fairness monitored throughout.

## Documentation and links

| Document | What it covers |
|---|---|
| [Full report](docs/REPORT.md) | Executive summary, methods, results, action plan, ethics |
| [Exploratory analysis](docs/eda_report.md) | Summary statistics, missing values, correlation, outliers, ten insights |
| [Data dictionary](docs/data_dictionary.md) | Every field, its type, definition and handling |
| [Cleaning log](docs/cleaning_log.md) | Each cleaning decision, data lineage and refresh steps |
| [Dataset source](https://archive.ics.uci.edu/dataset/296/diabetes+130-us+hospitals+for+years+1999-2008) | UCI Machine Learning Repository |

## Repository structure

```
Hospital-readmissions/
├── README.md
├── eda_stats.ipynb     EDA statistics and charts (Python, Google Colab)
├── data/
│   ├── raw/            original UCI files
│   └── clean/          the seven tables exported from MySQL
├── sql/                01_load_raw.sql to 06_analysis.sql, plus Sample_Outputs.docx
├── PowerBi/            .pbix, PDF, DAX measures, Power Query screenshots (powerQuery/)
├── Screenshots/
│   ├── PowerBi/        dashboard pages
│   └── EDA/            EDA charts from the notebook
├── images/             diagnosis group images used in the Explorer page
└── docs/               final report, EDA report, data dictionary, cleaning log
```

## How to reproduce

1. Download the dataset from UCI (link above) into `data/raw/`.
2. In MySQL 8, enable local file loading (`SET GLOBAL local_infile = 1;`).
3. Update the file paths at the top of `01_load_raw.sql`, then run the scripts `01` to `06` in order.
4. For the EDA statistics and charts, open `eda_stats.ipynb` in Google Colab, upload `diabetic_data.csv` and run all cells.
5. Open `PowerBi/Meridian_Readmissions_Dashboard.pbix` in Power BI Desktop. If prompted, point the data source to the CSV files in `data/clean/` (Transform data, then Data source settings).

## Image credits

The anatomy illustration on the Overview page is AI-generated, using an illustration from [St. Paul’s Hospital, Hong Kong](https://www.stpaul.org.hk/en/center-and-service/other-content/detail/understanding-liver-gallbladder-and-pancreas-functions-health) as a visual reference. It is not the original image.

The diagnosis group illustrations on the Explorer page (in `images/`) are also AI-generated.

## Author

Valentina · Orhmo
