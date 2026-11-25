-- sales
SELECT 'DimCustomer' AS object, count(*) FROM public.dimcustomer
UNION ALL SELECT 'DimProducts', count(*) FROM public.dimproducts
UNION ALL SELECT 'DimDate', count(*) FROM public.dimdate
UNION ALL SELECT 'FactSales', count(*) FROM public.factsales;

SELECT sum(quantity) AS units, sum(amount) AS revenue,
       CASE WHEN (SELECT count(*) FROM public.dimcustomer)=15
             AND (SELECT count(*) FROM public.dimproducts)=20
             AND (SELECT count(*) FROM public.dimdate)=25
             AND count(*)=53 AND sum(quantity)=62 AND sum(amount)=2279410
            THEN 'READY_FOR_LAB03' ELSE 'CHECK_LAB02' END AS status
FROM public.factsales;

CREATE SCHEMA IF NOT EXISTS mart;

-- sales by month
-- grain - year + month + category
-- measures - orders, units, revenue, average per order
-- dimensions - year, month, category
CREATE OR REPLACE VIEW mart.vw_SalesByMonthCategory AS
SELECT d.year AS year, d.month AS monthnumber, d.monthname, p.category,
       count(DISTINCT f.orderid) AS orderscount,
       sum(f.quantity) AS unitssold, sum(f.amount) AS revenue,
       round(sum(f.amount)/count(DISTINCT f.orderid),2) AS avgrevenueperorder
FROM public.factsales f
JOIN public.dimdate d ON d.datekey=f.datekey
JOIN public.dimproducts p ON p.productkey=f.productkey
GROUP BY d.year,d.month,d.monthname,p.category;

-- product sales
-- grain - product
-- measures - orders, units, revenue, average unit price
-- dimensions - product, category
CREATE OR REPLACE VIEW mart.vw_ProductPerformance AS
SELECT p.productid,p.productname,p.category,
       count(DISTINCT f.orderid) AS orderscount,
       sum(f.quantity) AS unitssold, sum(f.amount) AS revenue,
       round(sum(f.amount)/sum(f.quantity),2) AS avghistoricalunitprice
FROM public.factsales f
JOIN public.dimproducts p ON p.productkey=f.productkey
GROUP BY p.productid,p.productname,p.category;

-- customer sales
-- grain - customer
-- measures - orders, units, spending, average order
-- dimensions - customer, city
CREATE OR REPLACE VIEW mart.vw_CustomerValue AS
SELECT c.customerid,c.firstname,c.lastname,c.city,
       count(DISTINCT f.orderid) AS orderscount,
       sum(f.quantity) AS unitspurchased, sum(f.amount) AS totalspent,
       round(sum(f.amount)/count(DISTINCT f.orderid),2) AS avgordervalue
FROM public.factsales f
JOIN public.dimcustomer c ON c.customerkey=f.customerkey
GROUP BY c.customerid,c.firstname,c.lastname,c.city;

-- city sales
-- grain - city
-- measures - customers, orders, units, revenue, average order
-- dimensions - city
CREATE OR REPLACE VIEW mart.vw_SalesByCity AS
SELECT c.city,count(DISTINCT c.customerid) AS customerscount,
       count(DISTINCT f.orderid) AS orderscount,
       sum(f.quantity) AS unitssold, sum(f.amount) AS revenue,
       round(sum(f.amount)/count(DISTINCT f.orderid),2) AS avgordervalue
FROM public.factsales f
JOIN public.dimcustomer c ON c.customerkey=f.customerkey
GROUP BY c.city;

SELECT schemaname,viewname
FROM pg_catalog.pg_views
WHERE schemaname='mart'
  AND viewname IN ('vw_salesbymonthcategory','vw_productperformance','vw_customervalue','vw_salesbycity')
ORDER BY viewname;

SELECT column_name,data_type,numeric_precision,numeric_scale
FROM information_schema.columns
WHERE table_schema='mart' AND table_name='vw_salesbymonthcategory'
ORDER BY ordinal_position;

SELECT productid,productname,category,orderscount,unitssold,revenue,avghistoricalunitprice
FROM mart.vw_ProductPerformance
ORDER BY revenue DESC,productid LIMIT 5;

SELECT customerid,firstname,lastname,city,orderscount,unitspurchased,totalspent,avgordervalue
FROM mart.vw_CustomerValue
ORDER BY totalspent DESC,customerid LIMIT 3;

SELECT city,customerscount,orderscount,unitssold,revenue,avgordervalue
FROM mart.vw_SalesByCity
ORDER BY revenue DESC,city LIMIT 1;

SELECT year,monthnumber,monthname,category,orderscount,unitssold,revenue,avgrevenueperorder
FROM mart.vw_SalesByMonthCategory
ORDER BY revenue DESC,year,monthnumber,category LIMIT 1;

SELECT 'SalesByMonthCategory' AS viewname,count(*) AS rows,sum(unitssold) AS units,sum(revenue) AS revenue
FROM mart.vw_SalesByMonthCategory
UNION ALL
SELECT 'ProductPerformance',count(*),sum(unitssold),sum(revenue) FROM mart.vw_ProductPerformance
UNION ALL
SELECT 'CustomerValue',count(*),sum(unitspurchased),sum(totalspent) FROM mart.vw_CustomerValue
UNION ALL
SELECT 'SalesByCity',count(*),sum(unitssold),sum(revenue) FROM mart.vw_SalesByCity;

SELECT 'Product' AS control,productname AS leader,unitssold AS units,orderscount,revenue
FROM (SELECT productname,unitssold,orderscount,revenue FROM mart.vw_ProductPerformance ORDER BY revenue DESC,productid LIMIT 1)t
UNION ALL
SELECT 'Customer',firstname || ' ' || lastname,unitspurchased,orderscount,totalspent
FROM (SELECT firstname,lastname,unitspurchased,orderscount,totalspent FROM mart.vw_CustomerValue ORDER BY totalspent DESC,customerid LIMIT 1)t
UNION ALL
SELECT 'City',city,unitssold,orderscount,revenue
FROM (SELECT city,unitssold,orderscount,revenue FROM mart.vw_SalesByCity ORDER BY revenue DESC,city LIMIT 1)t
UNION ALL
SELECT 'MonthCategory',year || '-' || lpad(monthnumber::text,2,'0') || ' / ' || category,unitssold,orderscount,revenue
FROM (SELECT year,monthnumber,category,unitssold,orderscount,revenue FROM mart.vw_SalesByMonthCategory ORDER BY revenue DESC,year,monthnumber,category LIMIT 1)t;
