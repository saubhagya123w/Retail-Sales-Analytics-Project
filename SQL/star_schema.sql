-- Dimension Product
CREATE TABLE dim_product AS
SELECT DISTINCT productcode, productline, msrp
FROM cleaned_sales;
select * from dim_product;
-- Dimension Customer
CREATE TABLE dim_customer AS
SELECT DISTINCT customername, contactfirstname, contactlastname, 
       phone, addressline1, city, state, country, postalcode, dealsize
FROM cleaned_sales;
select * from dim_customer;
-- Fact Sales
CREATE TABLE fact_sales AS
SELECT
  ordernumber, orderdate, productcode,
  quantityordered, priceeach, sales, profit_est, discount_pct,
  inventory_age_days, is_profitable,
  territory, city, state, year_id, month_id, qtr_id
FROM cleaned_sales;
select * from fact_sales;