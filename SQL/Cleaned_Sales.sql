-- cleaned sales
DROP TABLE IF EXISTS cleaned_sales;
CREATE TABLE cleaned_sales AS
SELECT
    ordernumber,
    quantityordered,
    priceeach,
    orderlinenumber,
    COALESCE(sales, quantityordered*priceeach) AS sales,
    orderdate,
    status,
    qtr_id,
    month_id,
    year_id,
    productline,
    msrp,
    productcode,
    customername,
    phone,
    addressline1,
    addressline2,
    city,
    state,
    postalcode,
    country,
    territory,
    contactlastname,
    contactfirstname,
    dealsize,
    -- Derived columns
    (msrp * 0.6) AS cost_each,
    (priceeach - (msrp*0.6)) * quantityordered AS profit_est,
    CASE WHEN msrp > 0 THEN ROUND((msrp - priceeach)/msrp,4) ELSE 0 END AS discount_pct,
    FLOOR(RAND()*365) AS inventory_age_days,
    CASE WHEN ((priceeach - (msrp*0.6)) * quantityordered) > 0 THEN 1 ELSE 0 END AS is_profitable
FROM raw_staging_sales
WHERE orderdate IS NOT NULL;
select * from cleaned_sales;