create database if not exists retail_analytics;
use retail_analytics;

-- 1) staging table (raw copy of CSV). Types chosen per PDF (TRIAL.pdf).
DROP TABLE IF EXISTS raw_staging_sales;
CREATE TABLE raw_staging_sales (
  ordernumber VARCHAR(50),
  quantityordered INT,
  priceeach DECIMAL(12,2),
  orderlinenumber INT,
  sales DECIMAL(14,2),
  orderdate DATE,
  status VARCHAR(50),
  qtr_id INT,
  month_id INT,
  year_id INT,
  productline VARCHAR(100),
  msrp DECIMAL(12,2),
  productcode VARCHAR(50),
  customername VARCHAR(255),
  phone VARCHAR(50),
  addressline1 VARCHAR(255),
  addressline2 VARCHAR(255),
  city VARCHAR(100),
  state VARCHAR(100),
  postalcode VARCHAR(50),
  country VARCHAR(100),
  territory VARCHAR(100),
  contactlastname VARCHAR(100),
  contactfirstname VARCHAR(100),
  dealsize VARCHAR(20),
  -- ingestion metadata
  _source_filename VARCHAR(255),
  _ingested_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  _row_hash VARCHAR(64),
  PRIMARY KEY (ordernumber, orderlinenumber) -- assuming CSV provides uniqueness at order+line
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
select * from raw_staging_sales;
-- 2) ingestion logs (one row per ingestion run)
DROP TABLE IF EXISTS ingestion_logs;
CREATE TABLE ingestion_logs (
  ingestion_id INT AUTO_INCREMENT PRIMARY KEY,
  run_started_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  run_completed_at DATETIME NULL,
  source_filename VARCHAR(255),
  rows_seen BIGINT DEFAULT 0,
  rows_loaded BIGINT DEFAULT 0,
  rows_rejected BIGINT DEFAULT 0,
  warnings TEXT,
  error_message TEXT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
select * from ingestion_logs;
-- 3) Ingesion errors   
DROP TABLE IF EXISTS ingestion_errors;
CREATE TABLE ingestion_errors (
  error_id INT AUTO_INCREMENT PRIMARY KEY,
  ingestion_id INT,
  error_type VARCHAR(100), -- e.g. 'missing_column','invalid_date','negative_price','dup_pk'
  ordernumber VARCHAR(50),
  orderlinenumber INT,
  raw_row TEXT,
  error_details TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  INDEX (ingestion_id),
  CONSTRAINT fk_ingest FOREIGN KEY (ingestion_id) REFERENCES ingestion_logs(ingestion_id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
select * from ingestion_errors;
-- Helpful index for later queries by territory + product
CREATE INDEX idx_raw_prod_terr ON raw_staging_sales (productcode(20), territory(50));
-- Expected rows count > 0:
SELECT COUNT(*) AS total_rows FROM raw_staging_sales;

-- Check null counts for important columns:
SELECT
  SUM(ordernumber IS NULL) AS null_ordernumber,
  SUM(quantityordered IS NULL) AS null_quantity,
  SUM(priceeach IS NULL) AS null_priceeach,
  SUM(orderdate IS NULL) AS null_orderdate
FROM raw_staging_sales;

-- Duplicate primary-key check (ordernumber + orderlinenumber)
SELECT ordernumber, orderlinenumber, COUNT(*) AS cnt
FROM raw_staging_sales
GROUP BY ordernumber, orderlinenumber
HAVING cnt > 1;
 
-- Invalid / future dates
-- ORDERDATE NULL or not a date already checked by loader, but check for future dates:
SELECT COUNT(*) AS future_dates
FROM raw_staging_sales
WHERE orderdate > CURDATE();

-- Negative or zero quantity or price
SELECT COUNT(*) AS neg_quantity FROM raw_staging_sales WHERE quantityordered <= 0 OR quantityordered IS NULL;
SELECT COUNT(*) AS neg_price FROM raw_staging_sales WHERE priceeach < 0 OR priceeach IS NULL;

-- Sales consistency check (if SALES column present)
SELECT ordernumber, orderlinenumber, sales, quantityordered, priceeach,
       ROUND(quantityordered * priceeach,2) AS computed_sales,
       ROUND(ABS(sales - (quantityordered * priceeach)),2) AS diff
FROM raw_staging_sales
WHERE sales IS NOT NULL
  AND ROUND(ABS(sales - (quantityordered * priceeach)),2) > 0.01
LIMIT 200;

-- Territory / Country standardization checks
SELECT territory, COUNT(*) AS cnt
FROM raw_staging_sales
GROUP BY territory
ORDER BY cnt DESC
LIMIT 50;

-- Missing critical columns check
SELECT COUNT(*) AS missing_critical
FROM raw_staging_sales
WHERE ordernumber IS NULL OR orderdate IS NULL OR productcode IS NULL OR priceeach IS NULL;
-- Spot check top negative-profit SKUs (using the cost = MSRP * 0.6 assumption)
-- Use the PDF's assumption: cost_each = msrp * 0.6 if cost is not provided
SELECT productcode, territory,
       SUM(quantityordered * priceeach) AS total_sales,
       SUM(quantityordered * (priceeach - COALESCE(msrp * 0.6, 0))) AS est_profit
FROM raw_staging_sales
GROUP BY productcode, territory
HAVING SUM(quantityordered * (priceeach - COALESCE(msrp * 0.6, 0))) < 0
ORDER BY est_profit ASC
LIMIT 100;

