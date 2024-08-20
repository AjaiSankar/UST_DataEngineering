-- Create a database with condition to test if it exist -- 
-- Declare a variable with name Databasename -- 
DECLARE @Databasename VARCHAR(128) = 'taxidb';
-- Test condition to check if database exists --
IF NOT EXISTS(select 1 from sys.databases where name = @Databasename)
BEGIN
	DECLARE @SQL NVARCHAR(MAX) = 'CREATE DATABASE ' + QUOTENAME(@Databasename)
	EXEC sp_executesql @SQL;
END

USE taxidb
drop table taxi_trips
CREATE TABLE [dbo].taxi_trips (
    VendorID INT,
    lpep_pickup_datetime Datetime,
    lpep_dropoff_datetime Datetime,
    store_and_fwd_flag VARCHAR(10),
    RatecodeID INT,
    PULocationID INT,
    DOLocationID INT,
    passenger_count INT,
    trip_distance float,
    fare_amount DECIMAL(6, 2),
    extra DECIMAL(3, 2),
    mta_tax DECIMAL(3, 2),
    tip_amount DECIMAL(5, 2),
    tolls_amount DECIMAL(5, 2),
    ehail_fee DECIMAL(5, 2),
    improvement_surcharge DECIMAL(3, 2),
    total_amount DECIMAL(7, 2),
    payment_type INT,
    trip_type INT,
    congestion_surcharge DECIMAL(3, 2)
);



BULK INSERT taxi_trips FROM 'D:/greentaxi.csv'
WITH 
(
	FIELDTERMINATOR = ',', -- |	 ;	\t	' '		
	ROWTERMINATOR = '0x0a',	-- Carriage & New Line character \r\n,\n,\r,\0x0a (linefeed) 
	FIRSTROW = 2	--Skip the header from records
);

select * from taxi_trips

-- 13) Rank the Pickup Locations by Average Trip Distance and Average Total Amount.
select PULocationID as PickUpLocationID,
dense_rank() over(order by avg(trip_distance)) as Distance_rank,
dense_rank() over(order by avg(total_amount)) as Amount_rank 
from taxi_trips
where trip_distance > 0 and total_amount > 0
group by PULocationID
order by Distance_rank

-- 14) Find the Relationship Between Trip Distance & Fare Amount
select PuLocationID,avg(trip_distance) as Avg_Distance,avg(fare_amount) as Avg_Fare
from taxi_trips
where trip_distance > 0 and total_amount > 0
group by PULocationID
order by avg(trip_distance)

-- Insight: As Trip Distance increases Fare amount also increases
--	Both are linearly dependent

-- 15) Identify Trips with Outlier Fare Amounts within Each Pickup Location

-- 16) Categorize Trips Based on Distance Travelled 334303
select *,
	case 
		when groups = 4 then 'Very Long Trip'
		when groups = 3 then 'Long Trip'
		when groups = 2 then 'Short Trip'
		else 'Very Short Trip'
	end as Trip_type from
	(select PULocationID,DOLocationID,trip_distance,
	ntile(4) over(order by trip_distance)
	as groups
	from taxi_trips) 
	as type
		where trip_distance > 0

-- 17) Top 5 Busiest Pickup Locations, Drop Locations with Fare less than median total fare
WITH MedianCTE AS (
    SELECT PULocationId,DOLocationID,passenger_count,total_amount, PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total_amount) OVER () AS MedianAmount
    FROM taxi_trips
	where trip_distance > 0 AND total_amount > 0
)
select PULocationId,DOLocationID,passenger_count,total_amount from MedianCTE
where passenger_count > 0 and Total_amount < MedianAmount
order by passenger_count desc


-- 18) Distribution of Payment Types
SELECT payment_type,COUNT(*) AS Count,(COUNT(*) * 100.0 / 1068755 ) AS Percentage
FROM taxi_trips
where payment_type is not NULL
GROUP BY payment_type
ORDER BY Count DESC;

-- 19) Trips with Congestion Surcharge Applied and Its Percentage Count.
with SurchargeTrips AS (
    SELECT COUNT(*) AS SurchargeCount
    FROM taxi_trips
    WHERE congestion_surcharge IS NOT NULL AND congestion_surcharge > 0
)
SELECT SurchargeCount AS TripsWithSurcharge,
       (SurchargeCount * 100.0 / 1068755) AS PercentageTripsWithSurcharge
FROM SurchargeTrips;


-- 20) Top 10 Longest Trip by Distance and Its summary about total amount.
Select top(10) PULocationID,DOLocationID,trip_distance,total_amount
from taxi_trips
order by trip_distance desc

-- 21) Trips with a Tip Greater than 20% of the Fare
select * from 
(SELECT PULocationID,DOLocationID, fare_amount, (20 * fare_amount)/100 as twenty_percent,tip_amount
FROM taxi_trips where fare_amount > 0 ) as Compare
where tip_amount > twenty_percent

-- 22) Average Trip Duration by Rate Code
SELECT RatecodeID,AVG(DATEDIFF(second, lpep_pickup_datetime, lpep_dropoff_datetime)) AS AvgTripDurationSeconds
FROM 
taxi_trips
GROUP BY RatecodeID;


-- 23) Total Trips per Hour of the Day
SELECT DATEPART(hour, lpep_pickup_datetime) AS DayHour,COUNT(*) AS TotalTrips
FROM taxi_trips
where trip_distance > 0
GROUP BY DATEPART(hour, lpep_pickup_datetime)
ORDER BY DayHour;

-- 24 )Show the Distribution about Busiest Time in a Day.
SELECT DATEPART(hour, lpep_pickup_datetime) AS Busiest_hour,COUNT(*) AS TotalTrips
FROM taxi_trips
where trip_distance > 0
GROUP BY DATEPART(hour, lpep_pickup_datetime)
ORDER BY TotalTrips desc;