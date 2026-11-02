------------------------- HOSPITAL RECORDS------------------------------
-- KPIS
-- Total encounters
SELECT COUNT(Id)
FROM encounters;
-- Total encounter is 27,891

-- Total claims
SELECT ROUND(SUM(TOTAL_CLAIM_COST), 0) AS total_claims
FROM encounters;
-- Total claims are about $101.5M

-- Average claim
SELECT ROUND(AVG(TOTAL_CLAIM_COST), 0) AS average_claim
FROM encounters;
-- The average number of encounters is 3,639

-- Amount covered by payers
SELECT ROUND(SUM(PAYER_COVERAGE), 0) AS payer_paid
FROM encounters;
-- Total amount covered by payers is 31.1M

--Amount covered by patients
SELECT ROUND(SUM(TOTAL_CLAIM_COST) - SUM(PAYER_COVERAGE), 0) AS payer_paid
FROM encounters;
-- Out of the $101.5M total claims, about $70.4M is the part not covered by payers

-- Share covered by payers
SELECT ROUND(100.0 * SUM(PAYER_COVERAGE) / SUM(TOTAL_CLAIM_COST), 1) AS covered_pct
FROM encounters;
-- Only 30.6% of total claims is covered by insurance

-- Yearly trend
SELECT strftime('%Y', START) AS year, COUNT(Id) AS encounters, 
	   ROUND(SUM(TOTAL_CLAIM_COST), 0) AS total_claims
FROM encounters
GROUP BY Year;
-- Volume peaked in 2014 at 3,885 encounters, and 2022 is only a partial year.

-- Seasonality: encounters by month
SELECT strftime('%m', START) AS month, COUNT(Id) AS encounters, 
	   ROUND(SUM(TOTAL_CLAIM_COST), 0) AS total_claims
FROM encounters
GROUP BY month;
-- February had the highest number of encounters

-- Encounter class mix and cost
SELECT ENCOUNTERCLASS, COUNT(Id) AS encounters, 
	   ROUND(SUM(TOTAL_CLAIM_COST), 0) AS total_claims, 
	   ROUND(AVG(TOTAL_CLAIM_COST), 0) AS average_claim
FROM encounters
GROUP BY ENCOUNTERCLASS
ORDER BY total_claims DESC;
-- Ambulatory visits dominate at 12,537, then urgent care at 3,666, outpatient at 6,300, emergency at 2,322, inpatient at 1,135 and wellness at 1,931.

-- Payer mix and coverage
SELECT PAYER_NAME, COUNT(*) AS encounters,
       ROUND(SUM(TOTAL_CLAIM_COST), 0) AS total_claims,
       ROUND(100.0 * SUM(PAYER_COVERAGE) / SUM(TOTAL_CLAIM_COST), 1) AS covered_pct
FROM v_encounters_full GROUP BY PAYER_NAME ORDER BY encounters DESC;
-- Most encounters were for Medicare however, care was largely covered by Medicaid

-- Age-band utilisation and average claim
SELECT CASE WHEN age < 18 THEN '0-17' WHEN age < 40 THEN '18-39'
            WHEN age < 65 THEN '40-64' ELSE '65+' END AS age_band,
       COUNT(*) AS encounters, ROUND(AVG(cost), 0) AS avg_claim
FROM (SELECT e.TOTAL_CLAIM_COST AS cost,
             (julianday(e.START) - julianday(p.BIRTHDATE)) / 365.25 AS age
      FROM encounters e JOIN patients p ON p.Id = e.PATIENT
      WHERE p.BIRTHDATE IS NOT NULL)
GROUP BY age_band ORDER BY age_band;
-- Most of the encounters were from elderly people >65 years, but age-band 18-34 had the highest average claim

-- Top 10 reasons for visit
SELECT REASONDESCRIPTION, 
	   COUNT(*) AS encounters
FROM encounters WHERE REASONCODE IS NOT NULL
GROUP BY REASONDESCRIPTION 
ORDER BY encounters DESC LIMIT 10;
-- The leaders are congestive heart failure (1,738), hyperlipidemia (1,565), normal pregnancy (1,341), viral sinusitis and breast cancer

-- Top 10 procedures by total cost
SELECT DESCRIPTION, 
	   COUNT(Id) AS times_done, 
	   ROUND(AVG(BASE_COST), 0) AS avg_cost
FROM procedures
GROUP BY DESCRIPTION
ORDER BY avg_cost desc;
-- Admission to ICU is the most costly procedure, followed by coronary artery bypass grafting, while face mask is the least expensive procedure_types

-- Frequent emergency users
-- Frequent emergency users
SELECT p.Id, 
       RTRIM(p.FIRST, '0123456789') || ' ' || RTRIM(p.LAST, '0123456789') AS patient, 
       COUNT(*) AS er_visits,
       ROUND(SUM(e.TOTAL_CLAIM_COST), 0) AS er_cost
FROM encounters e 
JOIN patients p ON p.Id = e.PATIENT
WHERE e.ENCOUNTERCLASS = 'emergency'
GROUP BY p.Id 
HAVING er_visits >= 3 
ORDER BY er_visits DESC 
LIMIT 25;

-- Inpatient length of stay (days)
SELECT COUNT(*) AS stays,
       ROUND(AVG(julianday(STOP) - julianday(START)), 1) AS avg_days,
       ROUND(MAX(julianday(STOP) - julianday(START)), 1) AS max_days
FROM encounters WHERE ENCOUNTERCLASS = 'inpatient';

-- Mortality: patients and age at death
SELECT COUNT(*) AS deaths,
       ROUND(AVG((julianday(DEATHDATE) - julianday(BIRTHDATE)) / 365.25), 1) AS avg_age_at_death
FROM patients WHERE DEATHDATE IS NOT NULL;

-- Highest out-of-pocket patients (top 10)
SELECT RTRIM(p.FIRST, '0123456789') || ' ' || RTRIM(p.LAST, '0123456789') AS patient, 
             ROUND(SUM(e.TOTAL_CLAIM_COST - e.PAYER_COVERAGE), 0) AS out_of_pocket
FROM encounters e JOIN patients p ON p.Id = e.PATIENT
GROUP BY p.Id ORDER BY out_of_pocket DESC LIMIT 10;

-- Demographics: patients by race and gender
SELECT RACE, GENDER, COUNT(*) AS patients FROM patients
WHERE BIRTHDATE IS NOT NULL GROUP BY RACE, GENDER ORDER BY patients DESC;

-- Procedures per encounter class
SELECT e.ENCOUNTERCLASS, COUNT(*) AS procedures, ROUND(SUM(pr.BASE_COST), 0) AS procedure_cost
FROM procedures pr JOIN encounters e ON e.Id = pr.ENCOUNTER
GROUP BY e.ENCOUNTERCLASS ORDER BY procedure_cost DESC;