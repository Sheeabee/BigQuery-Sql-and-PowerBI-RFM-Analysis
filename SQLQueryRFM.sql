--Step 1 : Append all monthly sales tables together

CREATE OR REPLACE TABLE rff-analysis.Sales.sales_2025 AS
SELECT * FROM rff-analysis.Sales.202501
UNION ALL SELECT * FROM rff-analysis.Sales.202502
UNION ALL SELECT * FROM rff-analysis.Sales.202503
UNION ALL SELECT * FROM rff-analysis.Sales.202504
UNION ALL SELECT * FROM rff-analysis.Sales.202505
UNION ALL SELECT * FROM rff-analysis.Sales.202506
UNION ALL SELECT * FROM rff-analysis.Sales.202507
UNION ALL SELECT * FROM rff-analysis.Sales.202508
UNION ALL SELECT * FROM rff-analysis.Sales.202509
UNION ALL SELECT * FROM rff-analysis.Sales.202510
UNION ALL SELECT * FROM rff-analysis.Sales.202511
UNION ALL SELECT OrderID,CustomerID,OrderDate,ProductType,OrderValue FROM rff-analysis.Sales.202512;

-- Step 2: Calculate recency, frequency, monetary, r, f, m ranks with views & CTE.
CREATE OR REPLACE VIEW rff-analysis.Sales.rfm_metrics
AS
WITH current_date AS (
SELECT DATE('2026-04-06') AS analysis_date -- todays' date
),
rfm AS (
SELECT
	CustomerID,
	MAX(OrderDate) AS last_order_date,
	date_diff((SELECT analysis_date FROM current_date), MAX(OrderDate), DAY) AS recency,
	COUNT(*) AS frequency,
	SUM(OrderValue) AS monetary
FROM rff-analysis.Sales.sales_2025
GROUP BY CustomerID
)
SELECT
 rfm.*,
	ROW_NUMBER() OVER(ORDER BY recency ASC) AS r_rank,
	ROW_NUMBER() OVER(ORDER BY frequency ASC) AS f_rank,
	ROW_NUMBER() OVER(ORDER BY monetary ASC) AS m_rank,
FROM rfm;

-- STEP 3: Deciles (10=best, 1=worst)

CREATE OR REPLACE VIEW rff-analysis.Sales.rfm_scores
AS
SELECT
	*,
	NTILE(10) OVER(ORDER BY r_rank DESC) AS r_score,
	NTILE(10) OVER(ORDER BY f_rank DESC) AS f_score,
	NTILE(10) OVER(ORDER BY M_rank DESC) AS m_score,
FROM rff-analysis.Sales.rfm_metrics;

-- STEP 4 total score
CREATE OR REPLACE VIEW rff-analysis.Sales.rfm_total_scores
AS
SELECT
	CustomerID,
	recency,
	frequency,
	monetary,
	r_score,
	f_score,
	m_score,
  (r_score + f_score + m_score) as rfm_total_score
FROM rff-analysis.Sales.rfm_scores
ORDER BY rfm_total_score desc; 

-- STEP 5: BI RFM TABLE

CREATE OR REPLACE TABLE rff-analysis.Sales.rfm_segments_final
AS
SELECT
	CustomerID,
	recency,
	frequency,
	monetary,
	r_score,
	f_score,
	m_score,
	rfm_total_score,
	CASE
		WHEN rfm_total_score >= 28 THEN 'Champions'
		WHEN rfm_total_score >= 24 THEN 'VIPS'
		WHEN rfm_total_score >= 20 THEN 'Potental VIPS'
		WHEN rfm_total_score >= 16 THEN 'Promising'
		WHEN rfm_total_score >= 12 THEN 'Engaged'
		WHEN rfm_total_score >= 8 THEN 'Require Attention'
		WHEN rfm_total_score >= 4 THEN 'High Risk'
		ELSE 'Lost/Inactive'
	END AS rfm_segment
FROM rff-analysis.Sales.rfm_total_scores
ORDER BY rfm_total_score DESC;

SELECT * from rff-analysis.Sales.rfm_total_scores;

SELECT * FROM rff-analysis.Sales.rfm_segments_final;

SELECT rfm_segment, COUNT(*) FROM rff-analysis.Sales.rfm_segments_final
GROUP BY rfm_segment;

