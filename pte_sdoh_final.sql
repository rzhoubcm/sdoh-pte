USE CDWWork
GO

--Determining who has PTE based on ICD-9 and ICD-10
DROP TABLE IF EXISTS #cohort_trauma_icd_records
SELECT DISTINCT
	coh.PatientICN
INTO #cohort_trauma_icd_records
FROM SCS_EEGUtil.EEG.rz_PTE_all_epileptic AS coh
	INNER JOIN SPatient.SPatient AS sp
	ON sp.PatientICN = coh.PatientICN
	INNER JOIN Outpat.WorkloadVDiagnosis AS v
	ON sp.PatientSID = v.PatientSID AND sp.Sta3n = v.Sta3n
	INNER JOIN Dim.ICD10 AS icd10
	ON icd10.ICD10SID = v.ICD10SID
	INNER JOIN Dim.ICD9 AS icd9
	ON icd9.ICD9SID = v.ICD9SID
WHERE
	(
	icd9.ICD9Code IN (SELECT ICDCode FROM SCS_EEGUtil.Concepts.tbi_icd)
	OR
	icd10.ICD10Code IN (SELECT ICDCode FROM SCS_EEGUtil.Concepts.tbi_icd)
	)
	AND v.VisitDateTime < FIRST_DX_DATE

--Updating our permanent table
UPDATE SCS_EEGUtil.EEG.rz_PTE_all_epileptic
SET IS_PTE = CASE WHEN PatientICN IN (SELECT PatientICN FROM #cohort_trauma_icd_records) THEN 1 ELSE 0 END;

--Creating PTE only table for usage
DROP TABLE IF EXISTS #pte
SELECT PERSON_ID, PatientICN, FIRST_DX_DATE
INTO #pte
FROM SCS_EEGUtil.EEG.rz_PTE_all_epileptic 
WHERE IS_PTE = 1

SELECT * FROM #pte

--Getting cohort demographics and SDoH
--Get SDoH ICD Codes
DROP TABLE IF EXISTS #cohort_sdoh_records
SELECT DISTINCT
	coh.PERSON_ID,
	v.VisitDateTime,
	m.ICD10Code,
	descr.ICD10Description
INTO #cohort_sdoh_records
FROM #pte AS coh
INNER JOIN SPatient.SPatient AS sp
ON sp.PatientICN = coh.PatientICN
INNER JOIN Outpat.WorkloadVDiagnosis AS v
ON sp.PatientSID = v.PatientSID AND sp.Sta3n = v.Sta3n
INNER JOIN Dim.ICD10 AS m
ON m.ICD10SID = v.ICD10SID
INNER JOIN Dim.ICD10DescriptionVersion AS descr
ON descr.ICD10SID = v.ICD10SID
WHERE
	1=1
	AND m.ICD10Code IN (SELECT ICDCode FROM SCS_EEGUtil.Concepts.sdoh_icd)

SELECT PERSON_ID, VisitDateTime, ICD10Code FROM #cohort_sdoh_records

--Get the ADI
DROP TABLE IF EXISTS #cohort_zip4
SELECT DISTINCT
	coh.PERSON_ID,
	ad.Zip4,
	ad.AddressChangeDateTime
INTO #cohort_zip4
FROM #pte AS coh
LEFT JOIN CDWWork.SPatient.SPatient AS sp
	ON sp.PatientICN = coh.PatientICN
LEFT JOIN CDWWork.SPatient.SPatientAddress AS ad
	--ON ad.PatientICN = coh.PatientICN
	ON ad.Sta3n = sp.Sta3n AND ad.PatientSID = sp.PatientSID

WITH ZipCode9 AS (
	SELECT PERSON_ID, Zip4
	FROM #cohort_zip4
	WHERE LEN(Zip4) = 9
),
ZipCode5 AS (
	SELECT PERSON_ID, Zip4
	FROM #cohort_zip4
	WHERE LEN(Zip4) = 5
),
Matched5 AS (
	SELECT z5.PERSON_ID, z5.Zip4
	FROM ZipCode5 AS z5
	INNER JOIN ZipCode9 AS z9
		ON z5.PERSON_ID = z9.PERSON_ID AND z5.Zip4 = LEFT(z9.Zip4, 5)
)
SELECT DISTINCT coh.PERSON_ID, coh.Zip4
FROM #cohort_zip4 AS coh
LEFT JOIN Matched5 AS m
	ON coh.PERSON_ID = m.PERSON_ID AND coh.Zip4 = m.Zip4
WHERE LEN(coh.Zip4) = 9 OR m.Zip4 IS NULL AND coh.Zip4 IS NOT NULL

--Get demographics
DROP TABLE IF EXISTS #demographics
SELECT DISTINCT
	coh.*,
	sp.Gender,
	sp.BirthDateTime,
	r.Race
INTO #demographics
FROM #pte AS coh
	INNER JOIN SPatient.SPatient AS sp
	ON sp.PatientICN = coh.PatientICN
	INNER JOIN PatSub.PatientEthnicity AS eth
	ON eth.PatientSID = sp.PatientSID AND eth.Sta3n = sp.Sta3n
	INNER JOIN PatSub.PatientRace AS r
	ON r.PatientSID = sp.PatientSID AND r.Sta3n = sp.Sta3n

SELECT * FROM #demographics

--Getting utilization variables
--Imaging
--Get MRI
DROP TABLE IF EXISTS #mri
SELECT DISTINCT
	coh.PERSON_ID
INTO #mri
FROM #pte AS coh
	INNER JOIN CDWWork.SPatient.SPatient AS sp
	ON sp.PatientICN = coh.PatientICN
	INNER JOIN CDWWork.Outpat.WorkloadVProcedure AS p
	ON p.PatientSID = sp.PatientSID AND p.Sta3n = sp.Sta3n
	INNER JOIN CDWWork.Dim.CPT AS cpt
	ON cpt.CPTSID = p.CPTSID
WHERE cpt.CPTCode IN ('70551', '70552', '70553', '70557', '70558', '70559') AND p.VProcedureDateTime < '2023-01-01'

SELECT PERSON_ID FROM #mri

--Get EEG
DROP TABLE IF EXISTS #eeg
SELECT DISTINCT
	coh.PERSON_ID
INTO #eeg
FROM #pte AS coh
	LEFT JOIN OMOPV5.VISIT_OCCURRENCE AS vo
	ON vo.PERSON_ID = coh.PERSON_ID
	LEFT JOIN OUTPAT.Visit AS v
	ON v.VisitSID = vo.x_Source_ID_Primary
	LEFT JOIN DIM.StopCode AS psc
	ON psc.StopCodeSID = v.PrimaryStopCodeSID
	LEFT JOIN DIM.StopCode AS ssc
	ON ssc.StopCodeSID = v.SecondaryStopCodeSID
WHERE
	1=1
	AND (psc.StopCode = 106
	OR psc.StopCode = 128
	OR ssc.StopCode = 106
	OR ssc.StopCode = 128)
	AND v.VisitDateTime < '2023-01-01'
;

SELECT * FROM #eeg

--Get CT
DROP TABLE IF EXISTS #ct
SELECT DISTINCT
	coh.PERSON_ID
INTO #ct
FROM #pte AS coh
	INNER JOIN CDWWork.SPatient.SPatient AS sp
	ON sp.PatientICN = coh.PatientICN
	INNER JOIN CDWWork.Outpat.WorkloadVProcedure AS p
	ON p.PatientSID = sp.PatientSID AND p.Sta3n = sp.Sta3n
	INNER JOIN CDWWork.Dim.CPT AS cpt
	ON cpt.CPTSID = p.CPTSID
WHERE cpt.CPTCode IN ('70450', '70460', '70470') AND p.VProcedureDateTime < '2023-01-01'

SELECT * FROM #ct

--Hospital and clinic utilization
--Get ECoE usage
DROP TABLE IF EXISTS #ecoe_stops
SELECT DISTINCT
	coh.PERSON_ID,
	COUNT(DISTINCT vo.VISIT_START_DATE) AS N_ECoE_VISITS
INTO #ecoe_stops
FROM #pte AS coh
	LEFT JOIN OMOPV5.VISIT_OCCURRENCE AS vo
	ON vo.PERSON_ID = coh.PERSON_ID
	LEFT JOIN OUTPAT.Visit AS v
	ON v.VisitSID = vo.x_Source_ID_Primary
	LEFT JOIN DIM.StopCode AS psc
	ON psc.StopCodeSID = v.PrimaryStopCodeSID
	LEFT JOIN DIM.StopCode AS ssc
	ON ssc.StopCodeSID = v.SecondaryStopCodeSID
WHERE 
	1=1
	AND psc.StopCode = 345 OR ssc.StopCode = 345
	AND v.Sta3n IN ('523', '689', '512', '558', '652', '521', '546', '573', '607', '580', '671', '648', '663', '662', '501', '691', '618')
	AND vo.VISIT_START_DATE < '2023-01-01'
GROUP BY coh.PERSON_ID

SELECT * FROM #ecoe_stops

--Get neurology clinic usage
--Save counts of neurology clinic visits

DROP TABLE IF EXISTS #neuro_stops
SELECT DISTINCT
coh.PERSON_ID,
CAST(COUNT(DISTINCT vo.VISIT_START_DATE) AS DECIMAL) / ((DATEDIFF(DAY, MIN(coh.FIRST_DX_DATE), '2023-01-01') + 1) / 365.25)  AS N_NEURO_VISITS
--MIN(CAST(coh.FIRST_DX_DATE AS DATE)) AS DX,
--MIN(CAST(vo.VISIT_START_DATE AS DATE)) AS VSD,
--MIN(CAST(v.VisitDateTime AS DATE)) AS VDT
INTO #neuro_stops
FROM #pte AS coh
	LEFT JOIN OMOPV5.VISIT_OCCURRENCE AS vo
	ON vo.PERSON_ID = coh.PERSON_ID
	LEFT JOIN OUTPAT.Visit AS v
	ON v.VisitSID = vo.x_Source_ID_Primary
	LEFT JOIN DIM.StopCode AS psc
	ON psc.StopCodeSID = v.PrimaryStopCodeSID
	LEFT JOIN DIM.StopCode AS ssc
	ON ssc.StopCodeSID = v.SecondaryStopCodeSID
WHERE 
	(psc.StopCode = 315 OR ssc.StopCode = 315)
	AND CAST(v.VisitDateTime AS DATE) > CAST(coh.FIRST_DX_DATE AS DATE)
	AND CAST(v.VisitDateTime AS DATE) < CAST('2023-01-01' AS DATE)
GROUP BY coh.PERSON_ID

SELECT * FROM #neuro_stops

--Get primary care clinic usage
--Save counts of primary care clinic visits
DROP TABLE IF EXISTS #pcp_stops
SELECT DISTINCT
coh.PERSON_ID,
CAST(COUNT(DISTINCT vo.VISIT_START_DATE) AS DECIMAL) / ((DATEDIFF(DAY, MIN(coh.FIRST_DX_DATE), '2023-01-01') + 1) / 365.25) AS PCP_VISITS_PER_YEAR
--MIN(coh.FIRST_DX_DATE) AS FIRST_DX_DATE
INTO #pcp_stops
FROM #pte AS coh
	LEFT JOIN OMOPV5.VISIT_OCCURRENCE AS vo
	ON vo.PERSON_ID = coh.PERSON_ID
	LEFT JOIN OUTPAT.Visit AS v
	ON v.VisitSID = vo.x_Source_ID_Primary
	LEFT JOIN DIM.StopCode AS psc
	ON psc.StopCodeSID = v.PrimaryStopCodeSID
	LEFT JOIN DIM.StopCode AS ssc
	ON ssc.StopCodeSID = v.SecondaryStopCodeSID
WHERE 
	((psc.StopCode = 301 OR ssc.StopCode = 301) --General IM
	OR (psc.StopCode = 323 OR ssc.StopCode = 323)) --Primary Care Medicine
	AND vo.VISIT_START_DATE > CAST(coh.FIRST_DX_DATE AS DATE)
	AND vo.VISIT_START_DATE < CAST('2023-01-01' AS DATE)
GROUP BY coh.PERSON_ID

SELECT * FROM #pcp_stops

--ED
DROP TABLE IF EXISTS #ed
SELECT
	coh.PERSON_ID,
	CAST(COUNT(DISTINCT vo.VISIT_START_DATE) AS DECIMAL) / ((DATEDIFF(DAY, MIN(coh.FIRST_DX_DATE), '2023-01-01') + 1) / 365.25) AS ED_PER_YEAR
INTO #ed
FROM #pte AS coh
LEFT JOIN CDWWork.OMOPV5.CONDITION_OCCURRENCE AS co
	ON co.PERSON_ID = coh.PERSON_ID
LEFT JOIN CDWWork.OMOPV5.VISIT_OCCURRENCE AS vo
	ON vo.VISIT_OCCURRENCE_ID = co.VISIT_OCCURRENCE_ID
WHERE 
	co.CONDITION_CONCEPT_ID IN (SELECT CONCEPT_ID FROM SCS_EEGUtil.Concepts.seizure_concepts)
	AND vo.VISIT_CONCEPT_ID = 9203 --ED
	AND vo.VISIT_START_DATE > CAST(coh.FIRST_DX_DATE AS DATE)
	AND vo.VISIT_START_DATE < '2023-01-01'
GROUP BY coh.PERSON_ID

SELECT * FROM #ed

--Inpat
DROP TABLE IF EXISTS #inpat
SELECT
	vo.VISIT_START_DATE,
	vo.VISIT_END_DATE,
	coh.PERSON_ID,
	coh.FIRST_DX_DATE
INTO #inpat
FROM #pte AS coh
LEFT JOIN CDWWork.OMOPV5.CONDITION_OCCURRENCE AS co
	ON co.PERSON_ID = coh.PERSON_ID
LEFT JOIN CDWWork.OMOPV5.VISIT_OCCURRENCE AS vo
	ON vo.VISIT_OCCURRENCE_ID = co.VISIT_OCCURRENCE_ID
WHERE 
	co.CONDITION_CONCEPT_ID IN (SELECT CONCEPT_ID FROM SCS_EEGUtil.Concepts.seizure_concepts)
	AND vo.VISIT_CONCEPT_ID = 9201
	AND vo.VISIT_START_DATE > CAST(coh.FIRST_DX_DATE AS DATE)
	AND vo.VISIT_START_DATE < '2023-01-01'

SELECT * FROM #inpat

--CC data
--USE [ORD_Haneef_202402056D]
--GO

DROP TABLE IF EXISTS #cc_all_claims
SELECT DISTINCT
	CAST(COUNT(cl.Adjudication_Date) AS DECIMAL) / ((DATEDIFF(DAY, MIN(coh.FIRST_DX_DATE), '2023-01-01') + 1) / 365.25) AS N_CLAIMS,
	CAST(
		COUNT(
			CASE WHEN 
			cl.Primary_ICD LIKE 'G40%' 
			OR cl.Primary_ICD = 'R404' 
			OR cl.Primary_ICD = 'R561' 
			OR cl.Primary_ICD = 'R569' 
			THEN 1 END)
		AS DECIMAL) / ((DATEDIFF(DAY, MIN(coh.FIRST_DX_DATE), '2023-01-01') + 1) / 365.25) AS N_SZ_RELATED,
	coh.PERSON_ID
	--MIN(cl.Adjudication_Date) AS Adjudication_Date,
	--MIN(coh.FIRST_DX_DATE) AS FIRST_DX_DATE
INTO #cc_all_claims
FROM #pte AS coh
	LEFT JOIN [ORD_Haneef_202402056D].Src.IVC_CDS_CDS_Claim_Header AS cl
	ON cl.Patient_ICN = coh.PatientICN
WHERE 1=1
	AND cl.Adjudication_Date >= coh.FIRST_DX_DATE
GROUP BY coh.PERSON_ID

SELECT * FROM #cc_all_claims

DROP TABLE IF EXISTS #pte_eci
SELECT 
	PERSON_ID,
	(
		MAX(CONVERT(int,CHF))*9 +
		MAX(CONVERT(int,PULMCIRC))*0 +
		MAX(CONVERT(int,PERIVASC))*6 +
		MAX(CONVERT(int,HTN))*3 +
		MAX(CONVERT(int,HTNCX))*-1 +
		MAX(CONVERT(int,PARA))*-1 +
		MAX(CONVERT(int,NEURO))*5 +
		MAX(CONVERT(int,CHRNLUNG))*5 +
		MAX(CONVERT(int,DM))*3 +
		MAX(CONVERT(int,DMCX))*0 +
		MAX(CONVERT(int,HYPOTHY))*-3 +
		MAX(CONVERT(int,RENLFAIL))*6 +
		MAX(CONVERT(int,LIVER))*4 +
		MAX(CONVERT(int,ULCER))*0 +
		MAX(CONVERT(int,AIDS))*0 +
		MAX(CONVERT(int,LYMPH))*6 +
		MAX(CONVERT(int,METS))*14 +
		MAX(CONVERT(int,TUMOR))*7 +
		MAX(CONVERT(int,ARTH))*0 +
		MAX(CONVERT(int,COAG))*11 +
		MAX(CONVERT(int,OBESE))*-5 +
		MAX(CONVERT(int,WGHTLOSS))*9 +
		MAX(CONVERT(int,LYTES))*11 +
		MAX(CONVERT(int,BLDLOSS))*-3 +
		MAX(CONVERT(int,ANEMDEF))*-2 +
		MAX(CONVERT(int,ALCOHOL))*-1 +
		MAX(CONVERT(int,DRUG))*-7 +
		MAX(CONVERT(int,PSYCH))*6 +
		MAX(CONVERT(int,DEPRESS))*-5
	) AS ECI
INTO #pte_eci
FROM SCS_EEGUtil.Cohort.comorbidities
WHERE
	PERSON_ID IN (SELECT PERSON_ID FROM #pte)
	AND FIRST_DX_DATE < '2023-01-01'
GROUP BY PERSON_ID

SELECT * FROM #pte_eci