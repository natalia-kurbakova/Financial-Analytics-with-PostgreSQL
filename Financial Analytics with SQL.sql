-- Welcome to the PostgreSQL workshop histed by Baruch Association for Information Systems


--												BASICS

-- Let's create an empty table

CREATE TABLE fortune500(rank_position INT NOT NULL,
						title VARCHAR PRIMARY KEY,
						company_name VARCHAR NOT NULL,
						ticker VARCHAR(5),
						url VARCHAR,
						hq VARCHAR,
						sector VARCHAR NOT NULL,
						industry VARCHAR,
						employees INT,
						revenues INT,
						revenues_change REAL,
						profits NUMERIC,
						profits_change REAL,
						assets NUMERIC,
						equity NUMERIC
					   ); -- a SQL query has to end with a semicolon!
					   
-- Next, load the fortune500 dataset into this table: right-click fortune500 -> import data 
-- Let's print out the whole table to see if it worked

SELECT * FROM fortune500;


-- Example of a simple query

SELECT title, ticker, revenues, sector 
FROM fortune500 
WHERE sector = 'Technology';



-- Take a look at the logical operators in the slides (p.12)



-- Retrieving (reading) data from the fortune500 dataset
-- Let's see some examples:

SELECT * FROM fortune500;							-- From fortune500 table, retrieve all rows

SELECT title, ticker, hq, sector, revenues, profits 
FROM fortune500;									-- From fortune500, retrieve all rows specified fields

SELECT title, revenues, sector FROM fortune500
WHERE sector = 'Technology';						-- From fortune500, find rows that meet condition: sector = Technology, retrieve title, revenue and sector columns 

SELECT title, ticker, industry FROM fortune500
WHERE revenues <= 10000 OR profits < 0;				-- From fortune500, find rows that have negative profits or revenues no more than 10,000 

SELECT title, profits/revenues AS gross_profit_margin
FROM fortune500 WHERE profits/revenues > 0.1;		-- From fortune500, find rows that meet condition: profits/revenues>0.1, retrieve title and gross profit margin


-- Casting. You can change the displayed datatype of a column using the CAST() function. 

SELECT title, CAST(gross_profit_margin AS REAL)
FROM(												-- The following query uses a previous query as a subquery inside the FROM statement
	SELECT title, profits/revenues AS gross_profit_margin
	FROM fortune500 WHERE profits/revenues > 0.1) 
AS subquery;

-- Casting is also possible with ::

SELECT title, gross_profit_margin::REAL
FROM(												
	SELECT title, profits/revenues AS gross_profit_margin
	FROM fortune500 WHERE profits/revenues > 0.1) 
AS subquery;


-- Sometimes, you might want to perform computations on existing columns. 
-- Postgres has built-in functions for that!
SELECT 	MIN(profits) AS least_profit, 
		MAX(revenues) AS most_revenue, 
		AVG(equity) AS mean_equity,
		SUM(assets) AS fortune500_total_assets,
		COUNT(ticker) AS number_of_tickers
FROM fortune500;


--When we are using aggregate functions, we must add a GROUP BY statement to the query if we additionally select regular columns as well
-- 	get minimum, mean, and maximum profit values for each sector in the fortune500 
SELECT 	sector,							
		MIN(profits), 
		AVG(profits),
		MAX(profits)
FROM fortune500 
GROUP BY sector;


-- PostgreSQL allows you to count observations, order them by the most frequent values or in alphabetical order 
-- Let’s explore these capabilities!

-- Determine how many fortune500 companies belong to each sector?
SELECT sector, COUNT(*) FROM fortune500						
GROUP BY sector ORDER BY COUNT DESC;

-- How many are headquartered in the same location?
SELECT hq, COUNT(*) FROM fortune500		
GROUP BY hq ORDER BY COUNT DESC;

-- Case-insensitive search with ILIKE() keyword:

SELECT * FROM fortune500 WHERE company_name ILIKE('%bank%');




-- 											SPECIAL TOPICS

-- You are welcome to use queries from this part of the workshop for your personal research and data analysis! 


-- For demonstration, let's repeat the process of creating tables by creating a table schema and importing a new CSV file

CREATE TABLE IPO_dataset(IPO_date DATE NOT NULL,
						company_name VARCHAR PRIMARY KEY,
						IPO_proceeds NUMERIC NOT NULL,
						currency VARCHAR(3),
						industry VARCHAR,
						exchange VARCHAR,
						high_price_MM NUMERIC,
						low_price_MM NUMERIC
					   );
					   
					   
-- Next, load the IPO_dataset into this table: right-click ipo_dataset -> import data
-- Let's print out the first 10 rows of the table to see if it worked

SELECT * FROM IPO_dataset LIMIT 10;



-- IPO_dataset is a TIMESERIES dataset (time frame: December 2015 - October 2022)
-- Let’s write the following queries and discuss the results!

-- extracting and summarizing by month
-- the date_part function extracts the month from values in 'IPO_date' column and stores it as 'IPO_month'
-- this query groups rows by month 1-12:  observations from 12/2015 and 12/2021 would be grouped together
SELECT 	date_part('month', IPO_date) AS IPO_month, 
		SUM(IPO_proceeds) AS total_proceeds
FROM IPO_dataset 
GROUP BY IPO_month 
ORDER BY IPO_month;


-- grouping by fiscal quarter
-- the date_part function can extract the quarter from the timeseries! 
SELECT 	date_part('quarter', IPO_date) AS IPO_quarter, 
		SUM(IPO_proceeds) AS total_proceeds
FROM IPO_dataset 
GROUP BY IPO_quarter 
ORDER BY IPO_quarter;


-- truncate to keep larger units: months
-- the date_trunc function keeps the months in the IPO_date and cuts of smaller units: 2015-12-29 -> 2015-12-01
-- this will be useful when we join the result with data containing macroeconomic indices (released monthly)
SELECT 	date_trunc('month', IPO_date) AS IPO_month, 
		SUM(IPO_proceeds) AS total_proceeds
FROM IPO_dataset 
GROUP BY IPO_month 
ORDER BY IPO_month;


-- zooming in on a year
SELECT * FROM IPO_dataset 
WHERE IPO_date BETWEEN '2021-01-01' AND '2021-12-31';



-- SQL JOINS - take a look at the slides (p. 21)



-- Timeseries & Joins
-- Let’s do an inner join between two datasets: IPO data and Macro trends 


-- creating a table with truncated month
-- reusing the query from line 166
CREATE TABLE proceeds_each_month AS 					
	SELECT 	date_trunc('month', IPO_date) AS IPO_month, 
			SUM(IPO_proceeds) AS total_proceeds_MM, 
			COUNT(company_name) AS IPO_num
	FROM IPO_dataset 
	GROUP BY IPO_month 
	ORDER BY IPO_month;

-- printing out the table
SELECT * FROM proceeds_each_month;
-- as you can see from the results, the year 2021 experienced a boom in the number of companies going public and IPO proceeds 


-- define table containing percentage changes of macroeconomic indices: CPI, M2, House Price Index, Unemployment Rate. Source: Bloomberg
-- release month is the first day of each month
CREATE TABLE macro_trends(	release_month DATE NOT NULL, 	
							CPI_pct_change NUMERIC,
							M2_pct_change NUMERIC,
						  	House_price_pct_change NUMERIC,
						  	Unemployment_pct_change NUMERIC);

-- import another CSV


-- join the tables above using the month column in both tables
SELECT * FROM proceeds_each_month INNER JOIN macro_trends 
ON proceeds_each_month.IPO_month=macro_trends.release_month;

-- we can create another table from the last query, to reference results in the future
CREATE TABLE ipo_join_macro AS 						
	SELECT * FROM proceeds_each_month INNER JOIN macro_trends 
	ON proceeds_each_month.IPO_month=macro_trends.release_month;

SELECT * FROM ipo_join_macro;



-- Lead and Lag columns
-- When we have a time series dataset, we can create lag and lead columns to compute PERCENTAGE CHANGES!  


-- create lag columns of IPO proceeds
-- display month and IPO proceeds, the lagged version of the IPO proceeds column, difference between the original and lagged values / 100
SELECT IPO_month, total_proceeds_MM, 
LAG(total_proceeds_MM) OVER (ORDER BY IPO_month),
(total_proceeds_MM - LAG(total_proceeds_MM) OVER (ORDER BY IPO_month))/100 AS pct_change
FROM proceeds_each_month ORDER BY IPO_month;

-- create lead columns of IPO proceeds
-- display month and IPO proceeds, the leading version of the IPO proceeds column, difference between the original and leading values / 100
SELECT IPO_month, total_proceeds_MM, 
LEAD(total_proceeds_MM) OVER (ORDER BY IPO_month),
(total_proceeds_MM - LEAD(total_proceeds_MM) OVER (ORDER BY IPO_month))/100 AS pct_change
FROM proceeds_each_month ORDER BY IPO_month;



-- Anomaly detection: skewness and kurtosis - review the slides (p. 24)



-- Skewness. Source: Dejan Sarka (2017)
WITH SkewCTE AS
(SELECT SUM(1.0*total_proceeds_MM) AS rx,
 SUM(POWER(1.0*total_proceeds_MM,2)) AS rx2,
 SUM(POWER(1.0*total_proceeds_MM,3)) AS rx3,
 COUNT(1.0*total_proceeds_MM) AS rn,
 STDDEV_SAMP(1.0*total_proceeds_MM) AS stdv,
 AVG(1.0*total_proceeds_MM) AS av
FROM proceeds_each_month
)
SELECT
   (rx3 - 3*rx2*av + 3*rx*av*av - rn*av*av*av)
   / (stdv*stdv*stdv) * rn / (rn-1) / (rn-2) AS Skewness
FROM SkewCTE;


-- Kurtosis. Source: Dejan Sarka (2017)
WITH KurtCTE AS
(
SELECT SUM(1.0*total_proceeds_MM) AS rx,
 SUM(POWER(1.0*total_proceeds_MM,2)) AS rx2,
 SUM(POWER(1.0*total_proceeds_MM,3)) AS rx3,
 SUM(POWER(1.0*total_proceeds_MM,4)) AS rx4,
 COUNT(1.0*total_proceeds_MM) AS rn,
 STDDEV_SAMP(1.0*total_proceeds_MM) AS stdv,
 AVG(1.*total_proceeds_MM) AS av
FROM proceeds_each_month
)
SELECT
   (rx4 - 4*rx3*av + 6*rx2*av*av - 4*rx*av*av*av + rn*av*av*av*av)
   / (stdv*stdv*stdv*stdv) * rn * (rn+1) / (rn-1) / (rn-2) / (rn-3)
   - 3.0 * (rn-1) * (rn-1) / (rn-2) / (rn-3) AS Kurtosis
FROM KurtCTE;



-- OUTLIERS: review the slides (p.27)
-- Identifying outliers is more transparent when using SQL


-- To separate the outliers from inliers, let’s create bins!
WITH iqr_table AS (
SELECT pct_25, pct_75, (pct_75 - pct_25) AS iqr
FROM (SELECT 
	  percentile_disc(0.25) WITHIN GROUP (ORDER BY total_proceeds_MM) AS pct_25,  
	  percentile_disc(0.75) WITHIN GROUP (ORDER BY total_proceeds_MM) AS pct_75
	  FROM proceeds_each_month) AS iqr_proceeds
)
-- once we created bins, we can move to the main part of the query
-- we print out the IPO month, Total proceeds, Number of IPOs, and the type of outlier
SELECT IPO_month, total_proceeds_MM, IPO_num, 
CASE
	WHEN total_proceeds_MM>=pct_75 + iqr*1.5 THEN 'positive_outlier'
	WHEN total_proceeds_MM<=pct_75 - iqr*1.5 THEN 'negative_outlier'
	ELSE 'inlier'
END AS outlier_type
FROM proceeds_each_month, iqr_table;


-- the query above uses this subquery:
SELECT 
	  percentile_disc(0.25) WITHIN GROUP (ORDER BY total_proceeds_MM) AS pct_25,  
	  percentile_disc(0.75) WITHIN GROUP (ORDER BY total_proceeds_MM) AS pct_75
FROM proceeds_each_month;




-- 														THANK YOU

-- End of the workshop
SELECT 'I LOVE SQL' AS FEEDBACK;



