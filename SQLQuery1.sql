--  Data Cleaning

DELETE FROM OnlineRetail
WHERE CustomerID IS NULL; -- Removed 

SELECT COUNT(*)
FROM OnlineRetail;

-- Data Transformation
SELECT COLUMN_NAME, DATA_TYPE 
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME = 'OnlineRetail' AND COLUMN_NAME = 'InvoiceDate';

-- Hence Data_type is datetime

WITH DuplicateRecords AS (
    SELECT 
        CustomerID, InvoiceNo, StockCode, Description, InvoiceDate, UnitPrice, Country,
        ROW_NUMBER() OVER (PARTITION BY CustomerID, InvoiceNo, StockCode, InvoiceDate ORDER BY InvoiceDate) AS row_num
    FROM OnlineRetail
)
SELECT * FROM DuplicateRecords WHERE row_num > 1;

-- Remove Duplicate Transactions

WITH DuplicateRecords AS (
    SELECT 
        CustomerID, InvoiceNo, StockCode, Description, InvoiceDate, UnitPrice, Country,
        ROW_NUMBER() OVER (PARTITION BY CustomerID, InvoiceNo, StockCode, InvoiceDate ORDER BY InvoiceDate) AS row_num
    FROM OnlineRetail
)
DELETE FROM OnlineRetail
WHERE CustomerID IN (SELECT CustomerID FROM DuplicateRecords WHERE row_num > 1)
AND InvoiceNo IN (SELECT InvoiceNo FROM DuplicateRecords WHERE row_num > 1)
AND StockCode IN (SELECT StockCode FROM DuplicateRecords WHERE row_num > 1)
AND InvoiceDate IN (SELECT InvoiceDate FROM DuplicateRecords WHERE row_num > 1);

-- Validate after deletion

SELECT CustomerID, InvoiceNo, StockCode, InvoiceDate, COUNT(*) 
FROM OnlineRetail
GROUP BY CustomerID, InvoiceNo, StockCode, InvoiceDate
HAVING COUNT(*) > 1;

-- Fixing incorrect UnitPrice values (negative or zero).
--  Detect Incorrect UnitPrice Values

SELECT *
FROM OnlineRetail
WHERE UnitPrice <= 0;

-- Analyze the Impact of Incorrect Values

SELECT 
    COUNT(*) AS CountOfIncorrectPrices,
    SUM(UnitPrice * Quantity) AS TotalSalesImpact
FROM OnlineRetail
WHERE UnitPrice <= 0;

-- it shows countofcorrect prices are 32 and TotalSalesImpact are 0.

-- Decide How to Fix the Issue

UPDATE OnlineRetail
SET UnitPrice = (
    SELECT AVG(UnitPrice) 
    FROM OnlineRetail AS sub
    WHERE sub.StockCode = OnlineRetail.StockCode AND sub.UnitPrice > 0
)
WHERE UnitPrice <= 0;

-- Replace Incorrect UnitPrice with the Median Price of the Product

WITH RankedPrices AS (
    SELECT 
        StockCode,
        UnitPrice,
        ROW_NUMBER() OVER (PARTITION BY StockCode ORDER BY UnitPrice) AS rn_asc,
        ROW_NUMBER() OVER (PARTITION BY StockCode ORDER BY UnitPrice DESC) AS rn_desc
    FROM OnlineRetail
    WHERE UnitPrice > 0
)
SELECT StockCode, UnitPrice
FROM RankedPrices
WHERE rn_asc = rn_desc OR rn_asc + 1 = rn_desc;


-- Set UnitPrice to a Minimum Threshold (e.g., $1)

UPDATE OnlineRetail
SET UnitPrice = 1
WHERE UnitPrice <= 0;

-- Validate the Fix

SELECT *
FROM OnlineRetail
WHERE UnitPrice <= 0;

-- Create a Trigger to Prevent Future Issues

CREATE TRIGGER PreventNegativePrice
ON OnlineRetail
AFTER INSERT, UPDATE
AS
BEGIN
    -- If any new or updated row has UnitPrice <= 0, rollback the transaction
    IF EXISTS (SELECT 1 FROM inserted WHERE UnitPrice <= 0)
    BEGIN
        RAISERROR ('UnitPrice cannot be negative or zero.', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;

-- Creating a Category column based on StockCode

ALTER TABLE OnlineRetail  
ADD Category VARCHAR(50);  -- New Column

-- Updating the column using a CASE statement:

UPDATE OnlineRetail  
SET Category =  
    CASE  
        WHEN StockCode LIKE '1%' THEN 'Electronics'  
        WHEN StockCode LIKE '2%' THEN 'Clothing'  
        WHEN StockCode LIKE '3%' THEN 'Home & Kitchen'  
        WHEN StockCode IN ('99999', '88888') THEN 'Gift Items'  
        ELSE 'Other'  
    END;


-- Verify the Update

SELECT TOP 10 StockCode, Description, Category, Country
FROM OnlineRetail;

-- 2. Exploratory Data Analysis (EDA)

-- Find Top 10 Best-Selling Products.

SELECT TOP 10 
    StockCode, 
    Description, 
    SUM(Quantity) AS Total_Units_Sold
FROM OnlineRetail
WHERE Quantity > 0  -- Exclude returns (negative quantities)
GROUP BY StockCode, Description
ORDER BY Total_Units_Sold DESC;  -- Sorting in descending order

-- Identify Top 5 High-Value Customers.

SELECT TOP 5 
    CustomerID,
    SUM(UnitPrice * Quantity) AS TotalRevenue
FROM OnlineRetail
WHERE CustomerID IS NOT NULL  -- Exclude null customer records
GROUP BY CustomerID
ORDER BY TotalRevenue DESC;

-- Aggregate Sales by Month

SELECT 
    YEAR(InvoiceDate) AS SalesYear, 
    MONTH(InvoiceDate) AS SalesMonth,
    COUNT(DISTINCT InvoiceNo) AS TotalOrders,
    SUM(UnitPrice) AS TotalRevenue
FROM OnlineRetail
GROUP BY YEAR(InvoiceDate), MONTH(InvoiceDate)
ORDER BY SalesYear, SalesMonth;

-- Aggregate Sales by Week

SELECT 
    YEAR(InvoiceDate) AS SalesYear, 
    DATEPART(WEEK, InvoiceDate) AS SalesWeek,
    COUNT(DISTINCT InvoiceNo) AS TotalOrders,
    SUM(UnitPrice) AS TotalRevenue
FROM OnlineRetail
GROUP BY YEAR(InvoiceDate), DATEPART(WEEK, InvoiceDate)
ORDER BY SalesYear, SalesWeek;

-- Create a Running Total of Monthly Sales

SELECT 
    YEAR(InvoiceDate) AS SalesYear, 
    MONTH(InvoiceDate) AS SalesMonth,
    SUM(UnitPrice) AS MonthlyRevenue,
    SUM(SUM(UnitPrice)) OVER (PARTITION BY YEAR(InvoiceDate) ORDER BY MONTH(InvoiceDate)) AS RunningTotalRevenue
FROM OnlineRetail
GROUP BY YEAR(InvoiceDate), MONTH(InvoiceDate)
ORDER BY SalesYear, SalesMonth;


-- Compare Current Month with Previous Month

SELECT 
    YEAR(InvoiceDate) AS SalesYear, 
    MONTH(InvoiceDate) AS SalesMonth,
    SUM(UnitPrice) AS MonthlyRevenue,
    LAG(SUM(UnitPrice), 1, 0) OVER (PARTITION BY YEAR(InvoiceDate) ORDER BY MONTH(InvoiceDate)) AS PreviousMonthRevenue,
    SUM(UnitPrice) - LAG(SUM(UnitPrice), 1, 0) OVER (PARTITION BY YEAR(InvoiceDate) ORDER BY MONTH(InvoiceDate)) AS RevenueChange
FROM OnlineRetail
GROUP BY YEAR(InvoiceDate), MONTH(InvoiceDate)
ORDER BY SalesYear, SalesMonth;

-- Identify Seasonal Trends (Highest sales month).

SELECT 
    YEAR(InvoiceDate) AS SalesYear,  
    MONTH(InvoiceDate) AS SalesMonth,  
    COUNT(InvoiceNo) AS TotalOrders,  
    SUM(UnitPrice * Quantity) AS TotalRevenue,  
    RANK() OVER (ORDER BY SUM(UnitPrice * Quantity) DESC) AS SalesRank  
FROM OnlineRetail
GROUP BY YEAR(InvoiceDate), MONTH(InvoiceDate);


-- Detect Fraudulent Orders

SELECT 
    CustomerID, 
    InvoiceNo, 
    SUM(UnitPrice * Quantity) AS TotalOrderValue
FROM OnlineRetail
GROUP BY CustomerID, InvoiceNo
ORDER BY TotalOrderValue DESC;


-- Identify Orders That Are 3x Above Average

WITH AvgOrder AS (
    SELECT AVG(UnitPrice * Quantity) AS AvgOrderValue
    FROM OnlineRetail
)
SELECT 
    o.CustomerID, 
    o.InvoiceNo, 
    SUM(o.UnitPrice * o.Quantity) AS TotalOrderValue,
    a.AvgOrderValue  -- Add this to the SELECT clause
FROM OnlineRetail o
CROSS JOIN AvgOrder a
GROUP BY 
    o.CustomerID, 
    o.InvoiceNo,
    a.AvgOrderValue  -- Add this to the GROUP BY clause
HAVING SUM(o.UnitPrice * o.Quantity) > (3 * a.AvgOrderValue)
ORDER BY TotalOrderValue DESC;

-- Find Customers with Unusually High Purchases in a Short Time

WITH OrderTimes AS (
    SELECT 
        CustomerID, 
        InvoiceNo, 
        InvoiceDate,
        SUM(UnitPrice * Quantity) AS TotalOrderValue,
        LAG(InvoiceDate) OVER (PARTITION BY CustomerID ORDER BY InvoiceDate) AS PrevInvoiceDate
    FROM OnlineRetail
    GROUP BY CustomerID, InvoiceNo, InvoiceDate
)
SELECT 
    CustomerID, 
    InvoiceNo, 
    TotalOrderValue,
    InvoiceDate,
    PrevInvoiceDate,
    DATEDIFF(MINUTE, PrevInvoiceDate, InvoiceDate) AS TimeDifference
FROM OrderTimes
WHERE DATEDIFF(MINUTE, PrevInvoiceDate, InvoiceDate) < 10
AND TotalOrderValue > (SELECT AVG(UnitPrice * Quantity) * 3 FROM OnlineRetail)
ORDER BY TotalOrderValue DESC;


-- Detect Refund Fraud (Negative Quantities)

SELECT 
    CustomerID, 
    InvoiceNo, 
    SUM(UnitPrice * Quantity) AS TotalOrderValue
FROM OnlineRetail
WHERE Quantity < 0
GROUP BY CustomerID, InvoiceNo
HAVING SUM(UnitPrice * Quantity) < -100  -- Large refunds
ORDER BY TotalOrderValue ASC;

-- Finalizing & Storing Results

CREATE TABLE FraudulentOrders (
    FraudID INT IDENTITY(1,1) PRIMARY KEY,
    CustomerID INT,
    InvoiceNo NVARCHAR(50),
    TotalOrderValue FLOAT,
    InvoiceDate DATETIME,
    TimeDifference INT NULL,
    FraudReason NVARCHAR(255)
);

WITH OrderValues AS (
    SELECT 
        CustomerID,
        InvoiceNo,
        InvoiceDate,
        SUM(UnitPrice * Quantity) AS TotalOrderValue,
        LEAD(InvoiceDate) OVER (PARTITION BY CustomerID ORDER BY InvoiceDate) AS NextOrderDate
    FROM OnlineRetail
    GROUP BY CustomerID, InvoiceNo, InvoiceDate
),
SuspiciousOrders AS (
    SELECT 
        CustomerID,
        InvoiceNo,
        TotalOrderValue,
        InvoiceDate,
        DATEDIFF(MINUTE, InvoiceDate, NextOrderDate) AS TimeDifference
    FROM OrderValues
    WHERE TotalOrderValue > (
        SELECT 3 * AVG(UnitPrice * Quantity)
        FROM OnlineRetail
    )
)

INSERT INTO FraudulentOrders (CustomerID, InvoiceNo, TotalOrderValue, InvoiceDate, TimeDifference, FraudReason)
SELECT 
    CustomerID,
    InvoiceNo,
    TotalOrderValue,
    InvoiceDate,
    TimeDifference,
    'Multiple High-Value Orders in Short Time' AS FraudReason
FROM SuspiciousOrders
WHERE TimeDifference < 1440; -- Orders within 24 hours (1440 minutes)








