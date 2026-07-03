-- How many transactions have NO fraud label?
SELECT COUNT(*) FROM transactions_data t
LEFT JOIN fraud_labels f ON t.id = f.transaction_id
WHERE f.transaction_id IS NULL;

-- Label coverage rate
SELECT
    COUNT(*) AS total_txns,
    COUNT(f.transaction_id) AS labeled,
    ROUND(100.0 * COUNT(f.transaction_id) / COUNT(*), 2) AS coverage_pct
FROM transactions_data t
LEFT JOIN fraud_labels f ON t.id = f.transaction_id;

-- Fraud breakdown
SELECT is_fraud, COUNT(*) AS count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 3) AS pct
FROM fraud_labels
GROUP BY is_fraud;