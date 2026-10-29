-- XXXXX 
BEGIN;

TRUNCATE public.factsales, public.dimcustomer, public.dimproducts, public.dimdate RESTART IDENTITY;

INSERT INTO public.dimcustomer(customerid, firstname, lastname, city)
SELECT customerid, firstname, lastname, city 
FROM public.customers;

INSERT INTO public.dimproducts(productid, productname, category)
SELECT productid, productname, category 
FROM public.products;

INSERT INTO public.dimdate(datekey, fulldate, day, month, monthname, quarter, year)
SELECT to_char(d, 'YYYYMMDD')::int, d, extract(day 
from d)::int, extract(month 
from d)::int, to_char(d, 'TMMonth'), extract(quarter 
from d)::int, extract(year 
from d)::int

FROM(SELECT DISTINCT orderdate d 
FROM public.orders)t;

INSERT INTO public.factsales(orderid, datekey, customerkey, productkey, quantity, price, amount)
SELECT i.orderid, d.datekey, c.customerkey, p.productkey, i.quantity, i.price, i.quantity*i.price

FROM public.orderitems i 
JOIN public.orders o ON o.orderid = i.orderid

JOIN public.dimdate d ON d.fulldate = o.orderdate

JOIN public.dimcustomer c ON c.customerid = o.customerid

JOIN public.dimproducts p ON p.productid = i.productid;

DO $$ BEGIN
IF (SELECT count(*) FROM public.factsales)<>(SELECT count(*) FROM public.orderitems)
OR (SELECT sum(amount) FROM public.factsales) IS DISTINCT FROM (SELECT sum(quantity*price) FROM public.orderitems)
THEN RAISE EXCEPTION 'DWH reconciliation failed'; END IF;
END $$;

COMMIT;

SELECT 'DimCustomer' object, count(*) 
FROM public.dimcustomer

UNION ALL SELECT 'DimProducts', count(*) 
FROM public.dimproducts

UNION ALL SELECT 'DimDate', count(*) 
FROM public.dimdate

UNION ALL SELECT 'FactSales', count(*) 
FROM public.factsales;

SELECT sum(quantity) units, sum(amount) revenue 
FROM public.factsales;

SELECT p.productid, p.productname, sum(f.quantity) units, sum(f.amount) revenue

FROM public.factsales f 
JOIN public.dimproducts p USING(productkey)

GROUP BY p.productid, p.productname 
ORDER BY revenue DESC;

SELECT p.category, sum(f.amount) revenue 
FROM public.factsales f

JOIN public.dimproducts p USING(productkey) 
GROUP BY p.category 
ORDER BY revenue DESC;

SELECT c.customerid, c.firstname, c.lastname, sum(f.amount) totalspent 
FROM public.factsales f

JOIN public.dimcustomer c USING(customerkey)

GROUP BY c.customerid, c.firstname, c.lastname 
ORDER BY totalspent DESC;

SELECT d.year, d.month, sum(f.amount) revenue 
FROM public.factsales f

JOIN public.dimdate d USING(datekey) 
GROUP BY d.year, d.month 
ORDER BY d.year, d.month;

SELECT count(*) importedrows, sum(quantity) importedunits, sum(amount) importedrevenue

FROM public.factsales 
WHERE orderid BETWEEN 1021 AND 1025;

---

