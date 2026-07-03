-- Customer Summary
CREATE OR REPLACE VIEW customer_summary AS
SELECT
    u.id AS client_id,
    u.current_age,
    u.yearly_income,
    u.total_debt,
    u.credit_score,
    COUNT(t.id) AS txn_count,
    SUM(t.amount_clean) AS total_spend,
    AVG(t.amount_clean) AS avg_txn_amount,
    COUNT(DISTINCT t.merchant_id) AS unique_merchants,
    MAX(t.transaction_date) AS last_txn_date,
    -- fraud stats only on labeled transactions
    COUNT(f.transaction_id) AS labeled_txn_count,
    SUM(CASE WHEN f.is_fraud = 'Yes' THEN 1 ELSE 0 END) AS fraud_count,
    ROUND(
        100.0 * SUM(CASE WHEN f.is_fraud = 'Yes' THEN 1 ELSE 0 END)
        / NULLIF(COUNT(f.transaction_id), 0), 3
    ) AS fraud_rate_pct
FROM users_data u
LEFT JOIN transactions_data t ON u.id = t.client_id
LEFT JOIN fraud_labels f ON t.id = f.transaction_id
GROUP BY u.id, u.current_age, u.yearly_income, u.total_debt, u.credit_score;

-- hourly trend 
CREATE OR REPLACE VIEW hourly_trends AS
SELECT
    EXTRACT(HOUR FROM transaction_date) AS hour,
    EXTRACT(DOW FROM transaction_date) AS day_of_week,
    COUNT(*) AS txn_count,
    SUM(amount_clean) AS total_amount,
    AVG(amount_clean) AS avg_amount,
    -- separate labeled vs unlabeled
    COUNT(f.transaction_id) AS labeled_count,
    SUM(CASE WHEN f.is_fraud = 'Yes' THEN 1 ELSE 0 END) AS fraud_count
FROM transactions_data t
LEFT JOIN fraud_labels f ON t.id = f.transaction_id
GROUP BY hour, day_of_week;

-- marchant risk
CREATE OR REPLACE VIEW merchant_risk AS
SELECT
    m.category,
    COUNT(t.id) AS total_txn_count,
    SUM(t.amount_clean) AS total_amount,
    COUNT(f.transaction_id) AS labeled_count,
    SUM(CASE WHEN f.is_fraud = 'Yes' THEN 1 ELSE 0 END) AS fraud_count,
    -- fraud rate only among labeled transactions for accuracy
    ROUND(
        100.0 * SUM(CASE WHEN f.is_fraud = 'Yes' THEN 1 ELSE 0 END)
        / NULLIF(COUNT(f.transaction_id), 0), 3
    ) AS fraud_rate_pct,
    -- what % of this category's transactions are unlabeled
    ROUND(
        100.0 * (COUNT(t.id) - COUNT(f.transaction_id))
        / NULLIF(COUNT(t.id), 0), 1
    ) AS unlabeled_pct
FROM transactions_data t
JOIN mcc_codes m ON t.mcc = m.mcc
LEFT JOIN fraud_labels f ON t.id = f.transaction_id
GROUP BY m.category
ORDER BY fraud_rate_pct DESC;

-- fraud master
CREATE OR REPLACE VIEW fraud_master AS
SELECT
    t.id AS transaction_id,
    t.client_id,
    t.card_id,
    t.amount_clean AS amount,
    t.use_chip,
    t.merchant_id,
    t.merchant_city,
    t.merchant_state,
    t.mcc,
    m.category AS mcc_category,
    t.errors,
    t.transaction_date,
    EXTRACT(HOUR FROM t.transaction_date) AS hour,
    EXTRACT(DOW FROM t.transaction_date) AS day_of_week,
    -- three-way label: Yes / No / Unlabeled
    COALESCE(f.is_fraud, 'Unlabeled') AS is_fraud,
    u.current_age,
    u.yearly_income,
    u.total_debt,
    u.credit_score,
    CASE WHEN u.total_debt > u.yearly_income THEN 'Yes' ELSE 'No' END AS debt_exceeds_income,
    c.card_brand,
    c.card_type,
    c.has_chip,
    c.card_on_dark_web
FROM transactions_data t
LEFT JOIN fraud_labels f ON t.id = f.transaction_id
LEFT JOIN users_data u ON t.client_id = u.id
LEFT JOIN cards_data c ON t.card_id = c.id
LEFT JOIN mcc_codes m ON t.mcc = m.mcc;

-- verifying views
SELECT * FROM customer_summary LIMIT 10;
SELECT * FROM hourly_trends LIMIT 10;
SELECT * FROM merchant_risk LIMIT 10;
SELECT * FROM fraud_master LIMIT 10;

-- Check what your actual column names are in transactions_data
SELECT column_name, data_type 
FROM information_schema.columns
WHERE table_name = 'transactions_data';

-- Check if any date-looking column has values
SELECT * FROM transactions_data LIMIT 3;

-- Populate transaction_date from the date column
UPDATE transactions_data
SET transaction_date = date::timestamp
WHERE date IS NOT NULL;

-- Verify it worked
SELECT date, transaction_date FROM transactions_data LIMIT 5;

-- Confirm no NULLs remain
SELECT COUNT(*) FROM transactions_data WHERE transaction_date IS NULL;

-- Then drop and recreate the two affected views
DROP VIEW hourly_trends;
DROP VIEW fraud_master;

-- Recreate hourly_trends (same SQL as before, will now work correctly)
CREATE VIEW hourly_trends AS
SELECT
    EXTRACT(HOUR FROM transaction_date) AS hour,
    EXTRACT(DOW FROM transaction_date) AS day_of_week,
    COUNT(*) AS txn_count,
    SUM(amount_clean) AS total_amount,
    AVG(amount_clean) AS avg_amount,
    COUNT(f.transaction_id) AS labeled_count,
    SUM(CASE WHEN f.is_fraud = 'Yes' THEN 1 ELSE 0 END) AS fraud_count
FROM transactions_data t
LEFT JOIN fraud_labels f ON t.id = f.transaction_id
GROUP BY hour, day_of_week;

-- Recreate fraud_master
CREATE VIEW fraud_master AS
SELECT
    t.id AS transaction_id,
    t.client_id,
    t.card_id,
    t.amount_clean AS amount,
    t.use_chip,
    t.merchant_id,
    t.merchant_city,
    t.merchant_state,
    t.mcc,
    m.category AS mcc_category,
    t.errors,
    t.transaction_date,
    EXTRACT(HOUR FROM t.transaction_date) AS hour,
    EXTRACT(DOW FROM t.transaction_date) AS day_of_week,
    COALESCE(f.is_fraud, 'Unlabeled') AS is_fraud,
    u.current_age,
    u.yearly_income,
    u.total_debt,
    u.credit_score,
    CASE WHEN u.total_debt > u.yearly_income THEN 'Yes' ELSE 'No' END AS debt_exceeds_income,
    c.card_brand,
    c.card_type,
    c.has_chip,
    c.card_on_dark_web
FROM transactions_data t
LEFT JOIN fraud_labels f ON t.id = f.transaction_id
LEFT JOIN users_data u ON t.client_id = u.id
LEFT JOIN cards_data c ON t.card_id = c.id
LEFT JOIN mcc_codes m ON t.mcc = m.mcc;

-- Verify both now show proper hours
SELECT * FROM hourly_trends ORDER BY hour LIMIT 5;
SELECT transaction_date, hour, day_of_week FROM fraud_master LIMIT 5;