CREATE TABLE users_data (
    id INTEGER PRIMARY KEY,
    current_age INTEGER,
    retirement_age INTEGER,
    birth_year INTEGER,
    birth_month INTEGER,
    gender TEXT,
    address TEXT,
    latitude NUMERIC,
    longitude NUMERIC,
    per_capita_income NUMERIC,
    yearly_income NUMERIC,
    total_debt NUMERIC,
    credit_score INTEGER,
    num_credit_cards INTEGER
);

CREATE TABLE cards_data (
    id INTEGER PRIMARY KEY,
    client_id INTEGER REFERENCES users_data(id),
    card_brand TEXT,
    card_type TEXT,
    card_number TEXT,
    expires TEXT,
    cvv INTEGER,
    has_chip TEXT,
    num_cards_issued INTEGER,
    credit_limit NUMERIC,
    acct_open_date TEXT,
    year_pin_last_changed INTEGER,
    card_on_dark_web TEXT
);

CREATE TABLE mcc_codes (
    mcc INTEGER PRIMARY KEY,
    category TEXT
);

CREATE TABLE transactions_data (
    id BIGINT PRIMARY KEY,
    client_id INTEGER REFERENCES users_data(id),
    card_id INTEGER REFERENCES cards_data(id),
    amount NUMERIC,
    use_chip TEXT,
    merchant_id INTEGER,
    merchant_city TEXT,
    merchant_state TEXT,
    zip TEXT,
    mcc INTEGER REFERENCES mcc_codes(mcc),
    errors TEXT,
    transaction_date TIMESTAMP
);

CREATE TABLE fraud_labels (
    transaction_id BIGINT PRIMARY KEY REFERENCES transactions_data(id),
    is_fraud TEXT
);

/* changing datatype of amount because it includes $ sign */
alter table transactions_data alter column amount type TEXT;

select * from mcc_codes;
select * from users_data;

SELECT COUNT(*) FROM cards_data;
SELECT COUNT(*) FROM fraud_labels;
SELECT COUNT(*) FROM mcc_codes;
SELECT COUNT(*) FROM transactions_data;
SELECT COUNT(*) FROM users_data;

delete from fraud_labels ;

-- Add a clean numeric column
ALTER TABLE transactions_data ADD COLUMN amount_clean NUMERIC;

-- Strip $ and commas (some dollar formats have commas too) then populate
UPDATE transactions_data
SET amount_clean = REPLACE(REPLACE(amount, '$', ''), ',', '')::NUMERIC;

SELECT amount, amount_clean FROM transactions_data LIMIT 10;