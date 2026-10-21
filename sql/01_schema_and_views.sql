DROP TABLE IF EXISTS staging_credit_card CASCADE;

CREATE TABLE staging_credit_card (
    id INT PRIMARY KEY,
    limit_bal NUMERIC(12, 2),
    sex INT,
    education INT,
    marriage INT,
    age INT,
    pay_0 INT,
    pay_2 INT,
    pay_3 INT,
    pay_4 INT,
    pay_5 INT,
    pay_6 INT,
    bill_amt1 NUMERIC(12, 2),
    bill_amt2 NUMERIC(12, 2),
    bill_amt3 NUMERIC(12, 2),
    bill_amt4 NUMERIC(12, 2),
    bill_amt5 NUMERIC(12, 2),
    bill_amt6 NUMERIC(12, 2),
    pay_amt1 NUMERIC(12, 2),
    pay_amt2 NUMERIC(12, 2),
    pay_amt3 NUMERIC(12, 2),
    pay_amt4 NUMERIC(12, 2),
    pay_amt5 NUMERIC(12, 2),
    pay_amt6 NUMERIC(12, 2),
    default_payment_next_month INT
);

INSERT INTO staging_credit_card VALUES 
(1, 20000, 2, 2, 1, 24, 2, 2, -1, -1, -2, -2, 3913, 3102, 689, 0, 0, 0, 0, 689, 0, 0, 0, 0, 1),
(2, 120000, 2, 2, 2, 26, -1, 2, 0, 0, 0, 2, 2682, 1725, 2682, 3272, 3455, 3261, 0, 1000, 1000, 1000, 0, 2000, 1),
(3, 90000, 2, 2, 2, 34, 0, 0, 0, 0, 0, 0, 29239, 14027, 13559, 14331, 14948, 15549, 1518, 1500, 1000, 1000, 1000, 5000, 0),
(4, 50000, 1, 1, 2, 37, 0, 0, 0, 0, 0, 0, 46990, 48233, 49291, 28314, 28959, 29547, 2000, 2019, 1200, 1100, 1069, 1000, 0),
(5, 50000, 1, 1, 1, 57, -1, 0, -1, 0, 0, -1, 8617, 5670, 35835, 20940, 19146, 19131, 2000, 36681, 10000, 9000, 689, 679, 0);

DROP TABLE IF EXISTS fact_statements CASCADE;

CREATE TABLE fact_statements AS
SELECT
	s.id AS customer_id,
	u.month_index,
	u.statement_month,
	u.bill_amount,
	u.paid_amount,
	u.delay_status
FROM staging_credit_card s
CROSS JOIN LATERAL (
	VALUES
		(1, '2005-09', s.bill_amt1, s.pay_amt1, s.pay_0),
		(2, '2005-08', s.bill_amt2, s.pay_amt2, s.pay_2),
		(3, '2005-07', s.bill_amt3, s.pay_amt3, s.pay_3),
		(4, '2005-06', s.bill_amt4, s.pay_amt4, s.pay_4),
		(5, '2005-05', s.bill_amt5, s.pay_amt5, s.pay_5),
		(6, '2005-04', s.bill_amt6, s.pay_amt6, s.pay_6)
) AS u(month_index, statement_month, bill_amount, paid_amount, delay_status);

CREATE OR REPLACE VIEW v_roll_rate_matrix AS
WITH lagged_statements AS (
	SELECT
		customer_id,
		statement_month,
		delay_status,
		LAG(delay_status, 1) OVER (PARTITION BY customer_id ORDER BY statement_month) AS prev_delay_status
	FROM fact_statements
),
bucketed_transitions AS (
	SELECT
		customer_id,
		statement_month,
		delay_status,
		prev_delay_status,
		CASE
			WHEN delay_status <= 0 THEN 'Current'
			WHEN delay_status = 1 THEN '1-30 DPD'
			WHEN delay_status = 2 THEN '31-60 DPD'
			WHEN delay_status >= 3 THEN '60+ DPD'
			ELSE 'Unknown'
		END AS current_bucket,
		CASE
			WHEN prev_delay_status <= 0 THEN 'Current'
			WHEN prev_delay_status = 1 THEN '1-30 DPD'
			WHEN prev_delay_status = 2 THEN '31-60 DPD'
			WHEN prev_delay_status >= 3 THEN '60+ DPD'
			ELSE NULL
		END AS prev_bucket
	FROM lagged_statements
),
matrix_counts AS (
	SELECT 
		prev_bucket,
		COUNT(CASE WHEN current_bucket = 'Current' THEN 1 END) AS to_current,
		COUNT(CASE WHEN current_bucket = '1-30 DPD' THEN 1 END) AS to_dpd_1_30,
		COUNT(CASE WHEN current_bucket = '31-60 DPD' THEN 1 END) AS to_dpd_31_60,
		COUNT(CASE WHEN current_bucket = '60+ DPD' THEN 1 END) AS to_dpd_60_plus,
		COUNT(*) AS total_starting_accounts
	FROM bucketed_transitions
	WHERE prev_bucket IS NOT NULL
	GROUP BY prev_bucket
)
SELECT 
	prev_bucket,
	total_starting_accounts,
	ROUND(100.0 * to_current / total_starting_accounts, 2) AS pct_to_current,
	ROUND(100.0 * to_dpd_1_30 / total_starting_accounts, 2) AS pct_to_1_30,
	ROUND(100.0 * to_dpd_31_60 / total_starting_accounts, 2) AS pct_to_31_60,
	ROUND(100.0 * to_dpd_60_plus / total_starting_accounts, 2) AS pct_to_60_plus
FROM matrix_counts;

CREATE OR REPLACE VIEW v_ecl_calculation AS
WITH latest_portfolio AS (
	SELECT
		CASE
			WHEN delay_status <= 0 THEN 'Current'
			WHEN delay_status = 1 THEN '1-30 DPD'
			WHEN delay_status = 2 THEN '31-60 DPD'
			WHEN delay_status >= 3 THEN '60+ DPD'
		END AS risk_bucket,
		SUM(bill_amount) AS ead,
		CASE
			WHEN delay_status <= 0 THEN 0.0000
			WHEN delay_status = 1 THEN 0.0000
			WHEN delay_status = 2 THEN 0.0505
			WHEN delay_status >= 3 THEN 0.6434
		END AS pd,
		0.70 AS lgd
	FROM fact_statements
	WHERE statement_month = '2005-09'
	  AND bill_amount > 0
	GROUP BY 
		CASE
			WHEN delay_status <= 0 THEN 'Current'
			WHEN delay_status = 1 THEN '1-30 DPD'
			WHEN delay_status = 2 THEN '31-60 DPD'
			WHEN delay_status >= 3 THEN '60+ DPD'
		END,
		CASE
			WHEN delay_status <= 0 THEN 0.0000
			WHEN delay_status = 1 THEN 0.0000
			WHEN delay_status = 2 THEN 0.0505
			WHEN delay_status >= 3 THEN 0.6434
		END
)
SELECT
	risk_bucket,
	ead,
	pd,
	lgd,
	ROUND(ead * pd * lgd, 2) AS ecl
FROM latest_portfolio;