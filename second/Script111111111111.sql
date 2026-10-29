-- XXXXX
CREATE SCHEMA IF NOT EXISTS stg;

CREATE TABLE IF NOT EXISTS stg.CustomersImportRaw (
    CustomerID text,
    FirstName text,
    LastName text,
    Email text,
    City text
);

CREATE TABLE IF NOT EXISTS stg.ProductsImportRaw (
    ProductID text,
    ProductName text,
    Category text,
    Price text
);

CREATE TABLE IF NOT EXISTS stg.OrdersImportRaw (
    OrderID text,
    CustomerID text,
    OrderDate text
);

CREATE TABLE IF NOT EXISTS stg.OrderItemsImportRaw (
    OrderItemID text,
    OrderID text,
    ProductID text,
    Quantity text,
    Price text
);

BEGIN;

TRUNCATE stg.CustomersImportRaw;

COPY stg.CustomersImportRaw 
FROM 'C:/TechStoreCSV/01_Customers_import.csv' 
WITH (FORMAT csv, HEADER true, DELIMITER ';', ENCODING 'UTF8');

TRUNCATE stg.ProductsImportRaw;

COPY stg.ProductsImportRaw 
FROM 'C:/TechStoreCSV/02_Products_import.csv' 
WITH (FORMAT csv, HEADER true, DELIMITER ';', ENCODING 'UTF8');

TRUNCATE stg.OrdersImportRaw;

COPY stg.OrdersImportRaw 
FROM 'C:/TechStoreCSV/03_Orders_import.csv' 
WITH (FORMAT csv, HEADER true, DELIMITER ';', ENCODING 'UTF8');

TRUNCATE stg.OrderItemsImportRaw;

COPY stg.OrderItemsImportRaw 
FROM 'C:/TechStoreCSV/04_OrderItems_import.csv' 
WITH (FORMAT csv, HEADER true, DELIMITER ';', ENCODING 'UTF8');

COMMIT;

SELECT 'Customers' AS source, count(*) 
FROM stg.CustomersImportRaw;

SELECT * 
FROM stg.CustomersImportRaw;

SELECT 'Products' AS source, count(*) 
FROM stg.ProductsImportRaw;

SELECT * 
FROM stg.ProductsImportRaw;

SELECT 'Orders' AS source, count(*) 
FROM stg.OrdersImportRaw;

SELECT * 
FROM stg.OrdersImportRaw;

SELECT 'OrderItems' AS source, count(*) 
FROM stg.OrderItemsImportRaw;

SELECT * 
FROM stg.OrderItemsImportRaw;


-- XXXXX
CREATE
    OR REPLACE VIEW stg.customers_clean AS
SELECT nullif(trim(customerid), '')::int customerid, nullif(trim(firstname), '') firstname, nullif(trim(lastname), '') lastname, nullif(trim(email), '') email, nullif(trim(city), '') city

FROM stg.customersimportraw;

CREATE
    OR REPLACE VIEW stg.products_clean AS
SELECT nullif(trim(productid), '')::int productid, nullif(trim(productname), '') productname, nullif(trim(category), '') category, replace(translate(price, ' ₽' || chr(160), ''), ',', '.')::numeric(12, 2) price

FROM stg.productsimportraw;

CREATE
    OR REPLACE VIEW stg.orders_clean AS
SELECT nullif(trim(orderid), '')::int orderid, nullif(trim(customerid), '')::int customerid, to_date(nullif(trim(orderdate), ''), 'DD.MM.YYYY') orderdate

FROM stg.ordersimportraw;

CREATE
    OR REPLACE VIEW stg.orderitems_clean AS
SELECT nullif(trim(orderitemid), '')::int orderitemid, nullif(trim(orderid), '')::int orderid, nullif(trim(productid), '')::int productid, nullif(trim(quantity), '')::int quantity, replace(translate(price, ' ₽' || chr(160), ''), ',', '.')::numeric(12, 2) price

FROM stg.orderitemsimportraw;

SELECT * 
FROM stg.customers_clean;

SELECT * 
FROM stg.products_clean;

SELECT * 
FROM stg.orders_clean;

SELECT * 
FROM stg.orderitems_clean;


-- XXXXX 3
CREATE
    OR REPLACE VIEW stg.errors AS
SELECT 'Customers' AS source, count(*) AS errors

FROM stg.customers_clean

WHERE customerid IS NULL
    OR firstname IS NULL
    OR lastname IS NULL
    OR city IS NULL

UNION ALL
SELECT 'Products', count(*) 
FROM stg.products_clean

WHERE productid IS NULL
    OR productname IS NULL
    OR category IS NULL
    OR price IS NULL
    OR price < 0

UNION ALL
SELECT 'Orders', count(*) 
FROM stg.orders_clean

WHERE orderid IS NULL
    OR customerid IS NULL
    OR orderdate IS NULL

UNION ALL
SELECT 'OrderItems', count(*) 
FROM stg.orderitems_clean

WHERE orderitemid IS NULL
    OR orderid IS NULL
    OR productid IS NULL
    OR quantity IS NULL
    OR quantity <= 0
    OR price IS NULL
    OR price < 0;

SELECT * 
FROM stg.errors;


-- XXXXX 4
BEGIN;

DO $$
BEGIN
IF EXISTS (SELECT 1 FROM stg.errors WHERE errors>0) THEN
RAISE EXCEPTION 'Исправьте ошибки Validation';
END IF;
END $$;

INSERT INTO public.customers (customerid, firstname, lastname, email, city)
SELECT customerid, firstname, lastname, email, city 
FROM stg.customers_clean

ON CONFLICT (customerid) DO NOTHING;

SELECT setval(pg_get_serial_sequence('public.customers', 'customerid'), (SELECT max(customerid) 
FROM public.customers), true);

INSERT INTO public.products (productid, productname, category, price)
SELECT productid, productname, category, price 
FROM stg.products_clean

ON CONFLICT (productid) DO NOTHING;

SELECT setval(pg_get_serial_sequence('public.products', 'productid'), (SELECT max(productid) 
FROM public.products), true);

INSERT INTO public.orders (orderid, customerid, orderdate)
SELECT orderid, customerid, orderdate 
FROM stg.orders_clean

ON CONFLICT (orderid) DO NOTHING;

SELECT setval(pg_get_serial_sequence('public.orders', 'orderid'), (SELECT max(orderid) 
FROM public.orders), true);

INSERT INTO public.orderitems (orderitemid, orderid, productid, quantity, price)
SELECT orderitemid, orderid, productid, quantity, price 
FROM stg.orderitems_clean

ON CONFLICT (orderitemid) DO NOTHING;

SELECT setval(pg_get_serial_sequence('public.orderitems', 'orderitemid'), (SELECT max(orderitemid) 
FROM public.orderitems), true);

COMMIT;

-- XXX
SELECT 'Customers' AS name, count(*) 
FROM public.customers

UNION ALL SELECT 'Products', count(*) 
FROM public.products

UNION ALL SELECT 'Orders', count(*) 
FROM public.orders

UNION ALL SELECT 'OrderItems', count(*) 
FROM public.orderitems;

SELECT sum(quantity) AS units, sum(quantity*price) AS revenue 
FROM public.orderitems;






TRUNCATE stg.customersimportraw;

COPY stg.customersimportraw
FROM 'C:/TechStoreCSV/01_Customers_import.csv'
WITH (
    FORMAT csv,
    HEADER true,
    DELIMITER ';',
    ENCODING 'UTF8'
);




