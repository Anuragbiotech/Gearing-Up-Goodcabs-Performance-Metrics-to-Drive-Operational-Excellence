# Business Request 1: City-Level Fare and Trip Summary Report
> Generate a report that displays the total trips, average fare per km, average fare per trip, and the percentage contribution of each city's trips to the overall trips. This report will help in assessing trip volume, pricing efficiency, and each city's contribution to the overall trip count.

```sql
/* Before moving to the ad-hoc questions, 
	take a look at each table of trips_db.
*/

-- trips_db schema

SELECT * FROM trips_db.dim_city;
SELECT * FROM trips_db.dim_date;
SELECT * FROM trips_db.dim_repeat_trip_distribution;
SELECT * FROM trips_db.fact_passenger_summary;
SELECT * FROM trips_db.fact_trips;
```

```sql
-- The Total Trips

SELECT  COUNT(trip_id) AS Total_Trips
FROM    trips_db.fact_trips
;
```
![image](https://github.com/user-attachments/assets/9efa708e-5ab5-412a-b66e-87e4062789b8)


```sql
-- Average Fare per km

SELECT  SUM(fare_amount) / SUM(distance_travelled_km) AS avg_fare_per_km
FROM    trips_db.fact_trips
;
```
![image](https://github.com/user-attachments/assets/0c307d7b-b78a-43e5-bda8-4c3d0f417799)


```sql
-- Average Fare per trip

SELECT  ROUND(AVG(fare_amount), 2) AS avg_fare_per_trip
FROM    trips_db.fact_trips
;
```
![image](https://github.com/user-attachments/assets/783f69e9-9a26-46ee-ba8c-95ae088add23)


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
/* Before moving to the questions, 
	take a look at each table of targets_db.
*/

-- targets_db schema

SELECT * FROM targets_db.city_target_passenger_rating;
SELECT * FROM targets_db.monthly_target_new_passengers;
SELECT * FROM targets_db.monthly_target_trips;
```


