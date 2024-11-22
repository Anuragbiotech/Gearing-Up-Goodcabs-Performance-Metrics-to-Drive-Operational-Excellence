# Business Request 1: City-Level Fare and Trip Summary Report
> Generate a report that displays the total trips, average fare per km, average fare per trip, and the percentage contribution of each city's trips to the overall trips. This report will help in assessing trip volume, pricing efficiency, and each city's contribution to the overall trip count.

```sql
/* Before moving to the ad-hoc questions, 
	take a look at each table of trips_db and targets_db.
*/

-- trips_db schema

SELECT * FROM trips_db.dim_city;
SELECT * FROM trips_db.dim_date;
SELECT * FROM trips_db.dim_repeat_trip_distribution;
SELECT * FROM trips_db.fact_passenger_summary;
SELECT * FROM trips_db.fact_trips;

-- targets_db schema

SELECT * FROM targets_db.city_target_passenger_rating;
SELECT * FROM targets_db.monthly_target_new_passengers;
SELECT * FROM targets_db.monthly_target_trips; 
```

```sql
-- The Total Trips

SELECT  COUNT(trip_id) AS Total_Trips
FROM    trips_db.fact_trips
;
```
![image](https://github.com/user-attachments/assets/9efa708e-5ab5-412a-b66e-87e4062789b8)

**Explanation:**
- The **COUNT()** function counts the number of non-NULL values in the specified column (trip_id in this case).
- Since **trip_id** is a unique identifier for each trip, this query effectively counts the total number of trips recorded in the fact_trips table.
- If there are rows with NULL values in trip_id, they will be excluded from the count.
- The **AS** keyword is used to assign an alias to the resulting column. The output column will be named **Total_Trips**, making it clear what the value represents.

This query calculates the total number of trips recorded in the fact_trips table, providing a high-level overview of trip volume.


```sql
-- Average Fare per km

SELECT  SUM(fare_amount) / SUM(distance_travelled_km) AS avg_fare_per_km
FROM    trips_db.fact_trips
;
```
![image](https://github.com/user-attachments/assets/0c307d7b-b78a-43e5-bda8-4c3d0f417799)

**Explanation:**

The query calculates the average fare per kilometer (km) for all trips recorded in the fact_trips table. This metric provides insight into the overall pricing efficiency and passenger cost per km.

1. **SUM(fare_amount):**
    Calculates the total fare amount across all trips.
    Adds up all values in the fare_amount column.
2. **SUM(distance_travelled_km):**
    Calculates the total distance traveled (in kilometers) across all trips.
    Adds up all values in the distance_travelled_km column.
3. **SUM(fare_amount) / SUM(distance_travelled_km):**
    Divides the total fare by the total distance to calculate the average fare per km.
    This ensures the metric is aggregated at a global level for all trips.
4. **AS avg_fare_per_km:**
    Assigns an alias (avg_fare_per_km) to the calculated result.
    Makes the output more descriptive and easier to interpret.
5. **FROM trips_db.fact_trips:**
    Specifies the fact_trips table in the trips_db database as the source of data.

  **Why Use SUM Instead of AVG?**

  Using **SUM(fare_amount) / SUM(distance_travelled_km)** ensures the weighted average fare per km is calculated, accounting for variations in trip lengths.
  >The weighted average fare per kilometer (fare/km) accounts for variations in trip distances, ensuring that the average is proportional to the distance traveled. It provides a more accurate representation of the overall fare/km, especially when trips vary significantly in length.
  
  **Further explanation:**
- **Accurate Representation:** In the case of Goodcabs, some trips may be very short (e.g., 1 km), while others are long (e.g., 50 km). A simple per-trip average **(AVG(fare_amount / distance_travelled_km))** would treat all trips equally, which could distort the result.
- **Avoid Misleading Metrics:** If you calculated a direct per-trip average, a short trip with an unusually high fare/km could skew the results significantly.
- **Business Insight:** The weighted average is better for analyzing overall trends in pricing, as it balances out the contribution of trips based on their distances.

```sql
-- Average Fare per trip

SELECT  ROUND(AVG(fare_amount), 2) AS avg_fare_per_trip
FROM    trips_db.fact_trips
;
```
![image](https://github.com/user-attachments/assets/783f69e9-9a26-46ee-ba8c-95ae088add23)

**Explanation:**

This query calculates the average fare per trip in the fact_trips table and rounds the result to two decimal places for better readability.

1. **AVG(fare_amount):**
    The AVG() function calculates the average (arithmetic mean) of all values in the fare_amount column.
    It adds up all the fare amounts from the fact_trips table and divides the total by the number of trips (i.e., the number of rows with non-NULL fare_amount values).
2. **ROUND(AVG(fare_amount), 2):**
    The ROUND() function rounds the result of AVG(fare_amount) to 2 decimal places.
    Example: If the average fare is 123.45678, this will return 123.46.
3. **AS avg_fare_per_trip:**
    Assigns an alias avg_fare_per_trip to the resulting column.
    This makes the output more descriptive, showing that the value represents the average fare per trip.
4. **FROM trips_db.fact_trips:**
    Specifies the table fact_trips in the trips_db database as the data source.
   
```sql
-- Percentage contribution of each city's trips to the overall trips

SELECT  dim_city.city_name,
        ROUND(COUNT(fact_trips.trip_id) * 100.0 / (SELECT COUNT(*) FROM trips_db.fact_trips),
        2) AS percentage_contribution
FROM
        trips_db.fact_trips
INNER JOIN
        trips_db.dim_city
ON      fact_trips.city_id = dim_city.city_id
GROUP BY
        dim_city.city_name
;
```
![image](https://github.com/user-attachments/assets/25ea9904-68e3-4f72-b7da-a8a7670cff59)

# Business Request 2: Monthly City-Level Trips Target Performance Report
> Generate a report that evaluates the target performance for trips at the monthly and city level. For each city and month, compare the actual total trips with the target trips and categorize the performance as follows:

> • If actual trips are greater than target trips, mark it as "Above Target".

> • If actual trips are less or equal to target trips, mark it as "Below Target".

>Additionally, calculate the % difference between actual and target trips to quantify the performance gap

```sql
WITH actual_trips AS (
-- Aggregate actual trips by city and month
SELECT	ft.city_id,
        DATE_FORMAT(ft.date, '%Y-%m-01') AS month,
        COUNT(ft.trip_id) AS total_actual_trips
FROM 	trips_db.fact_trips ft
GROUP BY
	ft.city_id, DATE_FORMAT(ft.date, '%Y-%m-01')
),
performance_comparison AS (
-- Join aggregated trips with target trips and calculate metrics
SELECT	mt.city_id,
        mt.month,
        mt.total_target_trips,
        COALESCE(at.total_actual_trips, 0) AS total_actual_trips,
        CASE 
            WHEN COALESCE(at.total_actual_trips, 0) > mt.total_target_trips THEN 'Above Target'
            ELSE 'Below Target'
        END AS performance_category,
        ROUND(
            (COALESCE(at.total_actual_trips, 0) - mt.total_target_trips) / mt.total_target_trips * 100, 
            2
        ) AS percentage_difference
FROM targets_db.monthly_target_trips mt
LEFT JOIN
	actual_trips at
ON 	mt.city_id = at.city_id AND mt.month = at.month
)
-- Final report
SELECT	city_id,
    	month,
    	total_target_trips,
    	total_actual_trips,
    	performance_category,
    	percentage_difference
FROM 	performance_comparison
ORDER BY
	city_id, month
;
```


