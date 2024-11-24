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
> 
>> • If actual trips are greater than target trips, mark it as "Above Target".
>
>> • If actual trips are less or equal to target trips, mark it as "Below Target".
>
>Additionally, calculate the % difference between actual and target trips to quantify the performance gap

```sql
WITH actual_trips AS (
	-- Aggregate actual trips by city and month
	SELECT	fact_trips.city_id,
	        DATE_FORMAT(fact_trips.date, '%Y-%m-01') AS month,
	        COUNT(fact_trips.trip_id) AS total_actual_trips
	FROM 	trips_db.fact_trips
	GROUP BY
		fact_trips.city_id, DATE_FORMAT(fact_trips.date, '%Y-%m-01')
),
performance_comparison AS (
	-- Join aggregated trips with target trips and calculate metrics
	SELECT	monthly_target_trips.city_id,
		monthly_target_trips.month,
		monthly_target_trips.total_target_trips,
		COALESCE(actual_trips.total_actual_trips, 0) AS total_actual_trips,
		CASE
			WHEN COALESCE(actual_trips.total_actual_trips, 0) > monthly_target_trips.total_target_trips THEN 'Above Target'
			ELSE 'Below Target'
		END AS performance_status,
		ROUND(
		(COALESCE(actual_trips.total_actual_trips, 0) - monthly_target_trips.total_target_trips) / monthly_target_trips.total_target_trips * 100, 
                2) AS percentage_difference
	FROM 	targets_db.monthly_target_trips
	LEFT JOIN 
		actual_trips
	ON	monthly_target_trips.city_id = actual_trips.city_id AND monthly_target_trips.month = actual_trips.month
	)
	-- Final report
SELECT	dc.city_name,
	DATE_FORMAT(pc.month, '%M') AS month_name,
	pc.total_target_trips,
	pc.total_actual_trips,
	pc.performance_status,
	pc.percentage_difference
FROM 	performance_comparison pc
INNER JOIN
	trips_db.dim_city dc
ON 	pc.city_id = dc.city_id
ORDER BY
	dc.city_name, month_name
;


|city_name	|month_name	|total_target_trips	|total_actual_trips	|performance_status	|percentage_difference|
|---------------|---------------|-----------------------|-----------------------|-----------------------|---------------------|
|Chandigarh	|April		|6000			|5566			|Below Target		|-7.23
|Chandigarh	|February	|7000			|7387			|Above Target		|5.53
|Chandigarh	|January	|7000			|6810			|Below Target		|-2.71
|Chandigarh	|June		|6000			|6029			|Above Target		|0.48
|Chandigarh	|March		|7000			|6569			|Below Target		|-6.16
|Chandigarh	|May		|6000			|6620			|Above Target		|10.33
|Coimbatore	|April		|3500			|3661			|Above Target		|4.60
|Coimbatore	|February	|3500			|3404			|Below Target		|-2.74
|Coimbatore	|January	|3500			|3651			|Above Target		|4.31
|Coimbatore	|June		|3500			|3158			|Below Target		|-9.77
|Coimbatore	|March		|3500			|3680			|Above Target		|5.14
|Coimbatore	|May		|3500			|3550			|Above Target		|1.43
|Indore		|April		|7500			|7415			|Below Target		|-1.13
|Indore		|February	|7000			|7210			|Above Target		|3.00
|Indore		|January	|7000			|6737			|Below Target		|-3.76
|Indore		|June		|7500			|6288			|Below Target		|-16.16
|Indore		|March		|7000			|7019			|Above Target		|0.27
|Indore		|May		|7500			|7787			|Above Target		|3.83
|Jaipur		|April		|9500			|11406			|Above Target		|20.06
|Jaipur		|February	|13000			|15872			|Above Target		|22.09
|Jaipur		|January	|13000			|14976			|Above Target		|15.20
|Jaipur		|June		|9500			|9842			|Above Target		|3.60
|Jaipur		|March		|13000			|13317			|Above Target		|2.44
|Jaipur		|May		|9500			|11475			|Above Target		|20.79
|Kochi		|April		|9000			|9762			|Above Target		|8.47
|Kochi		|February	|7500			|7688			|Above Target		|2.51
|Kochi		|January	|7500			|7344			|Below Target		|-2.08
|Kochi		|June		|9000			|6399			|Below Target		|-28.90
|Kochi		|March		|7500			|9495			|Above Target		|26.60
|Kochi		|May		|9000			|10014			|Above Target		|11.27
|Lucknow	|April		|11000			|10212			|Below Target		|-7.16
|Lucknow	|February	|13000			|12060			|Below Target		|-7.23
|Lucknow	|January	|13000			|10858			|Below Target		|-16.48
|Lucknow	|June		|11000			|10240			|Below Target		|-6.91
|Lucknow	|March		|13000			|11224			|Below Target		|-13.66
|Lucknow	|May		|11000			|9705			|Below Target		|-11.77
|Mysore		|April		|2500			|2603			|Above Target		|4.12
|Mysore		|February	|2000			|2668			|Above Target		|33.40
|Mysore		|January	|2000			|2485			|Above Target		|24.25
|Mysore		|June		|2500			|2842			|Above Target		|13.68
|Mysore		|March		|2000			|2633			|Above Target		|31.65
|Mysore		|May		|2500			|3007			|Above Target		|20.28
|Surat		|April		|10000			|9831			|Below Target		|-1.69
|Surat		|February	|9000			|9069			|Above Target		|0.77
|Surat		|January	|9000			|8358			|Below Target		|-7.13
|Surat		|June		|10000			|8544			|Below Target		|-14.56
|Surat		|March		|9000			|9267			|Above Target		|2.97
|Surat		|May		|10000			|9774			|Below Target		|-2.26
|Vadodara	|April		|6500			|5941			|Below Target		|-8.60
|Vadodara	|February	|6000			|5228			|Below Target		|-12.87
|Vadodara	|January	|6000			|4775			|Below Target		|-20.42
|Vadodara	|June		|6500			|4685			|Below Target		|-27.92
|Vadodara	|March		|6000			|5598			|Below Target		|-6.70
|Vadodara	|May		|6500			|5799			|Below Target		|-10.78
|Visakhapatnam	|April		|5000			|4938			|Below Target		|-1.24
|Visakhapatnam	|February	|4500			|4793			|Above Target		|6.51
|Visakhapatnam	|January	|4500			|4468			|Below Target		|-0.71
|Visakhapatnam	|June		|5000			|4478			|Below Target		|-10.44
|Visakhapatnam	|March		|4500			|4877			|Above Target		|8.38
|Visakhapatnam	|May		|5000			|4812			|Below Target		|-3.76

```
**Explanation:**

1. **Aggregate Actual Trips:**
In the actual_trips CTE, we calculate the total number of trips (COUNT(ft.trip_id)) for each city and month by formatting fact_trips.date to the first day of the month using DATE_FORMAT(ft.date, '%Y-%m-01').
2. **Join with Targets:**
    In the performance_comparison CTE, we join the aggregated trips (actual_trips) with targets_db.monthly_target_trips using city_id and month.
    The COALESCE function ensures that cities and months with no trips (missing in actual_trips) are treated as 0.
3. **Categorize Performance:**
Compare total_actual_trips with total_target_trips to determine if the performance is "Above Target" or "Below Target."
4. **Calculate Percentage Difference:**
Calculate the percentage difference using the formula:
	
 	> Percentage Difference = (Actual Trips−Target Trips / Target Trips​) ×100
	
 	Use ROUND to format it to two decimal places.
5. **Final Report:**
Select relevant columns and order by city_name and month for a structured report.

**Further Explanation:**

- A **LEFT JOIN** was used in the query to ensure that all cities and months from the targets_db.monthly_target_trips table are included in the report, even if there are no trips recorded in the trips_db.fact_trips table for that city and month.

- The expression **DATE_FORMAT(ft.date, '%Y-%m-01') AS month** was used to standardize all dates in fact_trips to the first day of the respective month, enabling us to group and compare data at the monthly level.

# Business Request - 3: City-Level Passenger Trip Frequency Report
> Generate a report that shows the percentage distribution of repeat passengers by the number of trips they have taken in each city. Calculate the percentage of repeat passengers who took 2 trips, 3 trips, and so on, up to 10 trips.
>
> Each column should represent a trip count category, displaying the percentage of repeat passengers who fall into that category out of the total repeat passengers for that city.
>
> This report will help identify cities with high repeat trip frequency, which can indicate strong customer loyalty or frequent usage patterns.


```sql
WITH city_total_repeat AS (
	-- Calculate total repeat passengers per city
	SELECT	drtd.city_id,
  	      SUM(drtd.repeat_passenger_count) AS total_repeat_passengers
	FROM trips_db.dim_repeat_trip_distribution drtd
	WHERE	CAST(SUBSTRING_INDEX(drtd.trip_count, '-', 1) AS UNSIGNED) BETWEEN 2 AND 10
		GROUP BY drtd.city_id
),
percentage_distribution AS (
	-- Calculate percentage distribution for each trip count in each city
	SELECT	drtd.city_id,
        CAST(SUBSTRING_INDEX(drtd.trip_count, '-', 1) AS UNSIGNED) AS trip_count_numeric,
        ROUND(
            drtd.repeat_passenger_count * 100.0 / ctr.total_repeat_passengers, 
            2
        ) AS percentage
	FROM trips_db.dim_repeat_trip_distribution drtd
INNER JOIN
	city_total_repeat ctr
ON	drtd.city_id = ctr.city_id
WHERE	CAST(SUBSTRING_INDEX(drtd.trip_count, '-', 1) AS UNSIGNED) BETWEEN 2 AND 10
)
-- Pivot-style query to display percentages as columns for trip counts
SELECT	dc.city_name,
    	MAX(CASE WHEN pd.trip_count_numeric = 2 THEN pd.percentage ELSE 0 END) AS `2-Trips`,
    	MAX(CASE WHEN pd.trip_count_numeric = 3 THEN pd.percentage ELSE 0 END) AS `3-Trips`,
    	MAX(CASE WHEN pd.trip_count_numeric = 4 THEN pd.percentage ELSE 0 END) AS `4-Trips`,
    	MAX(CASE WHEN pd.trip_count_numeric = 5 THEN pd.percentage ELSE 0 END) AS `5-Trips`,
    	MAX(CASE WHEN pd.trip_count_numeric = 6 THEN pd.percentage ELSE 0 END) AS `6-Trips`,
    	MAX(CASE WHEN pd.trip_count_numeric = 7 THEN pd.percentage ELSE 0 END) AS `7-Trips`,
    	MAX(CASE WHEN pd.trip_count_numeric = 8 THEN pd.percentage ELSE 0 END) AS `8-Trips`,
    	MAX(CASE WHEN pd.trip_count_numeric = 9 THEN pd.percentage ELSE 0 END) AS `9-Trips`,
    	MAX(CASE WHEN pd.trip_count_numeric = 10 THEN pd.percentage ELSE 0 END) AS `10-Trips`
FROM	percentage_distribution pd
INNER JOIN
	trips_db.dim_city dc
ON	pd.city_id = dc.city_id
GROUP BY
	dc.city_name
ORDER BY
	dc.city_name
;



|city_name	|2-Trips	|3-Trips	|4-Trips	|5-Trips	|6-Trips	|7-Trips	|8-Trips	|9-Trips	|10-Trips|
|---------------|---------------|---------------|---------------|---------------|---------------|---------------|---------------|---------------|--------|
|Chandigarh	|6.67		|3.59		|4.18		|2.50		|1.60		|1.48		|0.65		|0.59		|0.37	
|Coimbatore	|2.47		|3.61		|2.82		|4.23		|4.43		|2.23		|1.22		|0.63		|0.47
|Indore		|8.50		|4.35		|3.24		|2.40		|1.50		|0.98		|0.67		|0.61		|0.35
|Jaipur		|10.32		|4.82		|2.49		|1.23		|1.19		|0.53		|0.58		|0.26		|0.25
|Kochi		|12.73		|6.14		|2.74		|1.35		|1.09		|0.52		|0.38		|0.29		|0.21
|Lucknow	|2.34		|3.33		|3.39		|3.67		|3.93		|2.56		|1.42		|0.50		|0.21
|Mysore		|12.19		|4.81		|3.45		|1.29		|1.15		|0.61		|0.34		|0.20		|0.20
|Surat		|2.10		|3.06		|3.99		|4.25		|4.26		|3.07		|1.56		|0.39		|0.31
|Vadodara	|2.53		|3.01		|4.12		|3.96		|3.66		|2.55		|1.61		|0.48		|0.39
|Visakhapatnam	|9.89		|6.46		|2.25		|1.25		|0.78		|0.47		|0.27		|0.20		|0.22

```

# Business Request - 4: Identify Cities with Highest and Lowest Total New Passengers
>Generate a report that calculates the total new passengers for each city and ranks them based on this value. Identify the top 3 cities with the highest number of new passengers as well as the bottom 3 cities with the lowest number of new passengers, categorising them as "Top 3" and "Bottom 3" accordingly.

```sql
WITH city_total_new_passengers AS (
    -- Calculate total new passengers for each city
    SELECT	fps.city_id,
		dc.city_name,
		SUM(fps.new_passengers) AS total_new_passengers
    FROM	trips_db.fact_passenger_summary fps
    INNER JOIN	
		trips_db.dim_city dc
    ON		fps.city_id = dc.city_id
    GROUP BY
		fps.city_id, dc.city_name
),
city_ranking AS (
    -- Rank cities based on total new passengers
    SELECT	ctnp.city_id,
		ctnp.city_name,
		ctnp.total_new_passengers,
		RANK() OVER (ORDER BY ctnp.total_new_passengers DESC) AS rank_desc,
		RANK() OVER (ORDER BY ctnp.total_new_passengers ASC) AS rank_asc
    FROM	city_total_new_passengers ctnp
),
categorized_cities AS (
    -- Categorize cities as "Top 3" or "Bottom 3"
    SELECT	cr.city_id,
		cr.city_name,
		cr.total_new_passengers,
		CASE 
			WHEN cr.rank_desc <= 3 THEN 'Top 3'
			WHEN cr.rank_asc <= 3 THEN 'Bottom 3'
			ELSE 'Others'
		END AS category
    FROM	city_ranking cr
)
-- Final report: Show only Top 3 and Bottom 3 cities
SELECT	city_id,
	city_name,
	total_new_passengers,
	category
FROM	categorized_cities
WHERE	category IN ('Top 3', 'Bottom 3')
ORDER BY
	category DESC, total_new_passengers DESC
;
```

![image](https://github.com/user-attachments/assets/f2a5382c-fd03-4ea1-847e-77bb6cba4887)


