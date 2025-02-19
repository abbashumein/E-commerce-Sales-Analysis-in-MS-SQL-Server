# E-commerce-Sales-Analysis-in-MS-SQL-Server

This project simulates a real-world Data Analyst & Data Engineer role using an OnlineRetail dataset in MS SQL Server. The goal is to clean, transform, analyze, and extract meaningful business insights. 
The dataset contains transactional sales data with the following columns:

CustomerID – Unique identifier for customers.
InvoiceNo – Unique transaction number.
StockCode – Product ID.
Description – Product name.
InvoiceDate – Date and time of the transaction.
UnitPrice – Price of each unit.
Country – Country of purchase.
🎯 Project Goals & Business Problems Solved
✅ Data Cleaning & Transformation (ETL Process)
✔ Convert InvoiceDate to DATETIME format for accurate time-based analysis.
✔ Remove NULL values in CustomerID to maintain data integrity.
✔ Identify and remove duplicate transactions to prevent redundancy.
✔ Fix incorrect UnitPrice values (negative or zero) to ensure accurate revenue calculations.
✔ Create a Category column based on StockCode for product segmentation.

✅ Exploratory Data Analysis (EDA) & Business Insights
✔ Find Top 10 Best-Selling Products based on total sales volume.
✔ Identify Top 5 High-Value Customers based on total purchase amount.
✔ Analyze Sales Trends Over Time (Weekly, Monthly) to detect seasonality.
✔ Identify Seasonal Trends (highest sales months for promotional planning).
✔ Detect Fraudulent Orders (unusually high transactions by a single customer).

📌 Key SQL Skills Demonstrated
🔹 Data Cleaning & Transformation: UPDATE, DELETE, CASE, ALTER TABLE, CAST(), ISNULL().
🔹 Data Analysis & Reporting: GROUP BY, HAVING, ORDER BY, DATEPART(), WINDOW FUNCTIONS.
🔹 Database Optimization: INDEXING, VIEWS, STORED PROCEDURES, CTE, TEMP TABLES.
🔹 ETL Automation: SQL Server Agent, Triggers, Stored Procedures for reporting.
