/*
SQL Task 1
==========
Write script for selecting of sales sums for the periods:

   - YTD – from the beginning of current year until the current date, including it,
   - MTD – from the beginning of current month until the current date, including it,
   - QTD – from the beginning of current quarter until the current date, including it,
   - PYTD – from the beginning of the previous year until the same as today date of
     previous year,
   - PMTD – from the beginning of the same month of previous year until the same
     as today date of previous year,
   - PQTD – from the beginning of the same quarter of previous year until the same
     as today date of previous year, Show results ignoring time.

Include into results columns [good_name], YTD, MTD, QTD, PYTD, PMTD, PQTD.
*/

-- Solve the problem using a function.

-- 1. Remove function if it already exists
IF OBJECT_ID (N'dbo.ufnCheckDateIsInRange', N'FN') IS NOT NULL
    DROP FUNCTION ufnCheckDateIsInRange;
GO

-- 2. Create a function
/* This function checks whether a record's date falls into some time range

The time range is defined by the "base date" as upper bound.
`@Period` parameter defines the lower bound of it.
At the moment, 3 period types are available: year, quarter, month.
See examples below to learn more.

Returns: 1 if a given record lays inside of the range, 0 otherwise.

Example scenario:
  * compute YTD, QTD, MTD
  * @BaseDate 2022-05-15
  * @RecordDate 2021-12-15, 2022-02-28, 2022-04-13, 2022-05-14

For a given BaseDate, the Period Dates would be:
  * 2022-01-01 - year start
  * 2022-04-01 - quarter start
  * 2022-05-01 - month start
  * 2022-05-15 - period end

If we map these dates onto a time scale, the idea becomes clear:

-------------- Time -------------- >>>

Record Dates | 2021-12-15   2022-02-28   2022-04-13      2022-05-14    2022-05-31
             |      |           |             |               |             |
   year      |      0     |---- 1 ----------- 1 ------------- 1 ----|       0
quarter      |      0     |     0      |----- 1 ------------- 1 ----|       0
  month      |      0     |     0      |      0       |------ 1 ----|       0
             |            |            |              |             |
Period Dates |       2022-01-01   2022-04-01     2022-05-01    2022-05-15

The output flags can be used as *multipliers* to detect correct records in aggregations.
*/
GO

CREATE FUNCTION dbo.ufnCheckDateIsInRange(@RecordDate DATETIME, @BaseDate DATETIME, @Period NVARCHAR(10))
RETURNS INT
AS

BEGIN
	DECLARE @ret INT;
	DECLARE @Month INT;
	DECLARE @StartOfThePeriod DATE;

    -- Set the start month depending on a period
	IF lower(@Period) = 'year'
	    -- Year always starts in the 1st month
		SET @Month = 1
	IF lower(@Period) = 'month'
	    -- For month, it will always be the same as base date's one
		SET @Month = MONTH(@BaseDate)
	IF lower(@Period) = 'quarter'
	    -- For quarter, we first find the number of completed quarter before a given one (the division part).
	    -- After that, compute the total number of months in completed quarters.
	    -- The next month should be the start of the period.
		SET @Month = FLOOR((MONTH(@BaseDate) - 1) / 3) * 3 + 1

    SET @StartOfThePeriod = DATEFROMPARTS(YEAR(@BaseDate), @Month, 1)

	SELECT
	@ret = CASE
		WHEN CAST(@RecordDate AS DATE) BETWEEN @StartOfThePeriod AND @BaseDate THEN 1
		else 0
	end
    RETURN COALESCE(@ret, 0)
END;
GO

-- 3. Set the variables
--- As soon as the data contains no rows for 2023, it will produce 0-sums.
--- To work around this, you may consider swapping current date with any date.

DECLARE @CustomBaseDate DATE
-- SET @CustomBaseDate = '20200824'  -- the last available date

DECLARE @Today AS DATE
DECLARE @TodayYearAgo AS DATE

-- Set this date to the last available date in the sales table
IF @CustomBaseDate IS NOT NULL
    SET @Today = @CustomBaseDate
ELSE
    SET @Today = GETDATE()
SET @TodayYearAgo = DATEADD(YEAR, -1, @Today)

-- Output the base date
SELECT @Today AS BaseDate

-- Final query
SELECT
	good_name,
	SUM(amount * dbo.ufnCheckDateIsInRange(s_date, @Today, 'year')) AS YTD,
	SUM(amount * dbo.ufnCheckDateIsInRange(s_date, @Today, 'month')) AS MTD,
	SUM(amount * dbo.ufnCheckDateIsInRange(s_date, @Today, 'quarter')) AS QTD,
	SUM(amount * dbo.ufnCheckDateIsInRange(s_date, @TodayYearAgo, 'year')) AS PYTD,
	SUM(amount * dbo.ufnCheckDateIsInRange(s_date, @TodayYearAgo, 'month')) AS PMTD,
	SUM(amount * dbo.ufnCheckDateIsInRange(s_date, @TodayYearAgo, 'quarter')) AS PQTD
FROM
	sales LEFT JOIN ref_goods ON sales.id_good = ref_goods.id
GROUP BY
	good_name
ORDER BY good_name
