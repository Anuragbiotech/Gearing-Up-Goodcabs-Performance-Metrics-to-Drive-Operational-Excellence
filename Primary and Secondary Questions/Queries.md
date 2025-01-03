# 1. Top and Bottom Performing Cities
• Identify the top 3 and bottom 3 cities by total trips over the entire analysis period.

```sql
WITH city_level_trips_metrics AS (
    -- Calculate Total Trips by City
    SELECT  dim_city.city_name,
            COUNT(fact_trips.trip_id) AS total_trips
    FROM    trips_db.fact_trips
    INNER JOIN
            trips_db.dim_city
    ON      fact_trips.city_id = dim_city.city_id
    GROUP BY
            dim_city.city_name
    ),
rank_trips AS (
    -- Rank the total as top 3 and bottom 3
    SELECT  city_level_trips_metrics.city_name,
            city_level_trips_metrics.total_trips,
            RANK() OVER(ORDER BY city_level_trips_metrics.total_trips DESC) AS rank_desc,
            RANK() OVER(ORDER BY city_level_trips_metrics.total_trips ASC) AS rank_asc
    FROM    city_level_trips_metrics
    ),
categorize_rank AS (
    -- Rank the total trips by city as Top 3 and Bottom 3
    SELECT  rank_trips.city_name,
            rank_trips.total_trips,
            CASE
                WHEN rank_trips.rank_desc <= 3 THEN 'Top 3'
                WHEN rank_trips.rank_asc <= 3 THEN 'Bottom 3'
                ELSE 'others'
            END AS rank_performance
    FROM    rank_trips
    )
SELECT  categorize_rank.city_name,
        categorize_rank.total_trips,
        rank_performance
FROM    categorize_rank
WHERE   rank_performance IN ('Top 3', 'Bottom 3')
ORDER BY
        total_trips DESC,
        rank_performance DESC
;
```

![image](https://github.com/user-attachments/assets/d3d42e16-546a-42cd-80f3-bc6881ab8d6d)

# 2. Average Fare per Trip by City
• Calculate the average passenger and driver ratings for each city, segmented by passenger type (new vs. repeat). Identify cities with the highest and lowest average ratings.

```sql
WITH average_fare AS (
    -- average fare per trip
    SELECT  fact_trips.city_id,
            ROUND(SUM(fact_trips.fare_amount) / COUNT(fact_trips.trip_id),
            2) AS Average_fare_per_trip
    FROM    trips_db.dim_city
    INNER JOIN
            trips_db.fact_trips
    ON      dim_city.city_id = fact_trips.city_id
    GROUP BY
            city_id
    ORDER BY
            Average_fare_per_trip DESC
    ),
average_distance AS (
    -- city's average trip distance
    SELECT  fact_trips.city_id,
            ROUND(AVG(distance_travelled_km),
            2) AS Average_Distance
    FROM    trips_db.fact_trips
    GROUP BY
            city_id
    )
SELECT  dim_city.city_name AS City_Name,
        average_fare.Average_fare_per_trip,
        average_distance.Average_Distance
FROM    average_fare
INNER JOIN
        average_distance
ON      average_fare.city_id = average_distance.city_id
INNER JOIN
        trips_db.dim_city
ON      average_fare.city_id = dim_city.city_id AND average_distance.city_id = dim_city.city_id
ORDER BY
        Average_fare_per_trip DESC
;
```

![image](https://github.com/user-attachments/assets/37a2de54-0b8b-4994-b785-ec56be10d6a3)

# 3. Average Ratings by City and Passenger Type
• Calculate the average passenger and driver ratings for each city, segmented by passenger type (new vs. repeat). Identify cities with the highest and lowest ratings.

```sql
WITH avg_ratings AS (
    -- average passenger's and dirver's ratings
    SELECT  dim_city.city_name,
            fact_trips.passenger_type,
            ROUND(AVG(fact_trips.passenger_rating), 2) AS avg_passenger_rating,
            ROUND(AVG(fact_trips.driver_rating), 2) AS avg_driver_rating
    FROM 
            trips_db.fact_trips
    INNER JOIN 
            trips_db.dim_city
    ON 
            fact_trips.city_id = dim_city.city_id
    GROUP BY 
            dim_city.city_name, fact_trips.passenger_type
)
SELECT  city_name,
        passenger_type,
        avg_passenger_rating,
        avg_driver_rating
FROM    avg_ratings
ORDER BY
        avg_passenger_rating,
        avg_driver_rating
;
```
|city_name 		  |passenger_type |avg_passenger_rating |avg_driver_rating|
|---------------|---------------|---------------------|-----------------|
|Vadodara		    |repeated		    |5.98				          |6.48
|Lucknow		    |repeated		    |5.99				          |6.49
|Surat			    |repeated		    |6.00				          |6.48
|Indore			    |repeated		    |7.47				          |7.48
|Coimbatore		  |repeated		    |7.48				          |7.48
|Chandigarh		  |repeated		    |7.49				          |7.47
|Surat			    |new			      |7.98				          |6.99
|Lucknow		    |new			      |7.98				          |6.99
|Vadodara		    |new			      |7.98				          |7.00
|Mysore			    |repeated		    |7.98				          |8.97
|Jaipur			    |repeated		    |7.99				          |8.98
|Visakhapatnam	|repeated		    |7.99				          |8.99
|Kochi			    |repeated		    |8.00				          |8.99
|Indore			    |new			      |8.49				          |7.97
|Chandigarh		  |new			      |8.49				          |7.99
|Coimbatore		  |new			      |8.49				          |7.99
|Visakhapatnam	|new			      |8.98				          |8.98
|Mysore			    |new			      |8.98				          |8.98
|Kochi			    |new			      |8.99				          |8.99
|Jaipur			    |new			      |8.99				          |8.99

# 4. Peak and Low Demand Months by City
• For each city, identify the month with the highest total trips (peak demand) and the month with the lowest total trips (low demand). This analysis will help Goodcabs understand seasonal patterns and adjust resources accordingly.

```sql
WITH monthly_trip_counts AS (
    -- Count of Trips by City and month
SELECT  dim_city.city_name AS City_Name,
        DATE_FORMAT(fact_trips.date, "%Y-%m") AS Month,
        monthname(fact_trips.date) AS month_name,
        COUNT(fact_trips.trip_id) AS Total_Trips
FROM
        trips_db.fact_trips
INNER JOIN
        trips_db.dim_city ON fact_trips.city_id = dim_city.city_id
GROUP BY
        dim_city.city_name, DATE_FORMAT(fact_trips.date, "%Y-%m")
),
ranked_months AS (
SELECT	City_Name,
        Month,
        month_name,
        Total_Trips,
        RANK() OVER (PARTITION BY City_Name ORDER BY Total_Trips DESC) AS rank_desc,
        RANK() OVER (PARTITION BY City_Name ORDER BY Total_Trips ASC) AS rank_asc
FROM
        monthly_trip_counts
)
SELECT  City_Name,
	month_name,
	Total_Trips,
	'Peak' AS Demand_Type
FROM	ranked_months
WHERE	rank_desc = 1
        
UNION ALL

SELECT  City_Name,
	month_name,
	Total_Trips,
	'Low' AS Demand_Type
FROM
        ranked_months
WHERE	rank_asc = 1
ORDER BY
	City_Name,
        Demand_Type DESC,
        Total_Trips DESC
;
```

![image](https://github.com/user-attachments/assets/ba539c85-1504-41d7-bf7a-6b69facdb8ca)

# 5. Weekend vs. Weekday Trip Demand by City 
• Compare the total trips taken on weekdays versus weekends for each city over the six-month period. Identify cities with a strong preference for either weekend or weekday trips to understand demand variations.

```sql
SELECT  dim_city.city_name,
        SUM(CASE WHEN dim_date.day_type = 'Weekday' THEN 1 ELSE 0 END) AS total_weekday_trips,
        SUM(CASE WHEN dim_date.day_type = 'Weekend' THEN 1 ELSE 0 END) AS total_weekend_trips
FROM    trips_db.fact_trips
INNER JOIN
        trips_db.dim_date ON fact_trips.date = dim_date.date
INNER JOIN
        trips_db.dim_city ON fact_trips.city_id = dim_city.city_id
GROUP BY
        dim_city.city_name
ORDER BY
        dim_city.city_name
;
```
![image](https://github.com/user-attachments/assets/b1641ae7-b2dd-466e-9060-06fb812636eb)

# 6. Repeat Passenger Frequency and City Contribution Analysis
• Analyse the frequency of trips taken by repeat passengers in each city (e.g., % of repeat passengers taking 2 trips, 3 trips, etc.). Identify which cities contribute most to higher trip frequencies among repeat passengers, and examine if there are distinguishable patterns between tourism-focused and business-focused cities.

```sql
WITH city_trip_frequency AS (
	-- Calculate percentage distribution of repeat passenger counts by trip frequency in each city
	SELECT	dim_repeat_trip_distribution.city_id,
        	dim_city.city_name,
        	dim_repeat_trip_distribution.trip_count,
        	dim_repeat_trip_distribution.repeat_passenger_count,
        	SUM(dim_repeat_trip_distribution.repeat_passenger_count) OVER (PARTITION BY dim_repeat_trip_distribution.city_id) AS total_repeat_passengers,
        	ROUND(
            		(dim_repeat_trip_distribution.repeat_passenger_count * 100.0) / 
            		SUM(dim_repeat_trip_distribution.repeat_passenger_count) OVER (PARTITION BY dim_repeat_trip_distribution.city_id),
            	2) AS percentage_repeat_passengers
	FROM	trips_db.dim_repeat_trip_distribution
	INNER JOIN
		trips_db.dim_city
	ON	dim_repeat_trip_distribution.city_id = dim_city.city_id
),
categorized_cities AS (
	-- Categorize cities into tourism-focused and business-focused
	SELECT	city_id, 
        	city_name,
        	CASE
			WHEN city_name IN ('Visakhapatnam', 'Mysore', 'Jaipur', 'Kochi') THEN 'Tourism-Focused'
			WHEN city_name IN ('Surat', 'Vadodara', 'Indore', 'Lucknow') THEN 'Business-Focused'
			ELSE 'Business plus Tourism'
		END AS city_focus
	FROM	trips_db.dim_city
),
combined_data AS (
    -- Combine trip frequency and city categorization
	SELECT	city_trip_frequency.city_name,
        	categorized_cities.city_focus,
        	city_trip_frequency.trip_count,
        	city_trip_frequency.percentage_repeat_passengers
    	FROM	city_trip_frequency
    	INNER JOIN
		categorized_cities
    	ON	city_trip_frequency.city_id = categorized_cities.city_id
)
-- Summarize trip frequency patterns by city focus
SELECT	city_name,
	city_focus,
	trip_count,
	ROUND(AVG(percentage_repeat_passengers), 2) AS repeat_passenger_contribution
FROM	combined_data
GROUP BY
	city_focus, trip_count, city_name
ORDER BY
	city_name,
	city_focus,
	repeat_passenger_contribution DESC
;
```
|city_name	|city_focus		|trip_count	|repeat_passenger_contribution|
|---------------|-----------------------|---------------|-----------------------------|
|Chandigarh	|Business plus Tourism	|2-Trips	|	5.39
|Chandigarh	|Business plus Tourism	|3-Trips	|	3.21
|Chandigarh	|Business plus Tourism	|4-Trips	|	2.62
|Chandigarh	|Business plus Tourism	|5-Trips	|	2.04
|Chandigarh	|Business plus Tourism	|6-Trips	|	1.24
|Chandigarh	|Business plus Tourism	|7-Trips	|	0.92
|Chandigarh	|Business plus Tourism	|8-Trips	|	0.58
|Chandigarh	|Business plus Tourism	|9-Trips	|	0.39
|Chandigarh	|Business plus Tourism	|10-Trips	|	0.30
|Coimbatore	|Business plus Tourism	|5-Trips	|	3.44
|Coimbatore	|Business plus Tourism	|6-Trips	|	2.94
|Coimbatore	|Business plus Tourism	|4-Trips	|	2.59
|Coimbatore	|Business plus Tourism	|3-Trips	|	2.47
|Coimbatore	|Business plus Tourism	|2-Trips	|	1.87
|Coimbatore	|Business plus Tourism	|7-Trips	|	1.75
|Coimbatore	|Business plus Tourism	|8-Trips	|	1.03
|Coimbatore	|Business plus Tourism	|9-Trips	|	0.39
|Coimbatore	|Business plus Tourism	|10-Trips	|	0.20
|Indore		|Business-Focused	|2-Trips	|	5.72
|Indore		|Business-Focused	|3-Trips	|	3.78
|Indore		|Business-Focused	|4-Trips	|	2.23
|Indore		|Business-Focused	|5-Trips	|	1.72
|Indore		|Business-Focused	|6-Trips	|	1.14
|Indore		|Business-Focused	|7-Trips	|	0.87
|Indore		|Business-Focused	|8-Trips	|	0.55
|Indore		|Business-Focused	|9-Trips	|	0.40
|Indore		|Business-Focused	|10-Trips	|	0.25
|Jaipur		|Tourism-Focused	|2-Trips	|	8.36
|Jaipur		|Tourism-Focused	|3-Trips	|	3.45
|Jaipur		|Tourism-Focused	|4-Trips	|	2.02
|Jaipur		|Tourism-Focused	|5-Trips	|	1.05
|Jaipur		|Tourism-Focused	|6-Trips	|	0.69
|Jaipur		|Tourism-Focused	|7-Trips	|	0.42
|Jaipur		|Tourism-Focused	|8-Trips	|	0.32
|Jaipur		|Tourism-Focused	|9-Trips	|	0.20
|Jaipur		|Tourism-Focused	|10-Trips	|	0.16
|Kochi		|Tourism-Focused	|2-Trips	|	7.95
|Kochi		|Tourism-Focused	|3-Trips	|	4.06
|Kochi		|Tourism-Focused	|4-Trips	|	1.97
|Kochi		|Tourism-Focused	|5-Trips	|	1.08
|Kochi		|Tourism-Focused	|6-Trips	|	0.65
|Kochi		|Tourism-Focused	|7-Trips	|	0.35
|Kochi		|Tourism-Focused	|8-Trips	|	0.28
|Kochi		|Tourism-Focused	|9-Trips	|	0.20
|Kochi		|Tourism-Focused	|10-Trips	|	0.14
|Lucknow	Business-Focused	|6-Trips	|	3.37
|Lucknow	Business-Focused	|5-Trips	|	3.07
|Lucknow	Business-Focused	|4-Trips	|	2.70
|Lucknow	Business-Focused	|3-Trips	|	2.46
|Lucknow	Business-Focused	|7-Trips	|	1.89
|Lucknow	Business-Focused	|2-Trips	|	1.61
|Lucknow	Business-Focused	|8-Trips	|	1.07
|Lucknow	Business-Focused	|9-Trips	|	0.32
|Lucknow	Business-Focused	|10-Trips	|	0.19
|Mysore		Tourism-Focused		|2-Trips	|	8.13
|Mysore		Tourism-Focused		|3-Trips	|	4.08
|Mysore		Tourism-Focused		|4-Trips	|	2.12
|Mysore		Tourism-Focused		|5-Trips	|	0.97
|Mysore		Tourism-Focused		|6-Trips	|	0.68
|Mysore		Tourism-Focused		|7-Trips	|	0.30
|Mysore		Tourism-Focused		|8-Trips	|	0.24
|Mysore		Tourism-Focused		|9-Trips	|	0.09
|Mysore		Tourism-Focused		|10-Trips	|	0.08
|Surat		Business-Focused	|5-Trips	|	3.29
|Surat		Business-Focused	|6-Trips	|	3.07
|Surat		Business-Focused	|4-Trips	|	2.76
|Surat		Business-Focused	|3-Trips	|	2.38
|Surat		Business-Focused	|7-Trips	|	1.98
|Surat		Business-Focused	|2-Trips	|	1.63
|Surat		Business-Focused	|8-Trips	|	1.04
|Surat		Business-Focused	|9-Trips	|	0.29
|Surat		Business-Focused	|10-Trips	|	0.23
|Vadodara	Business-Focused	|6-Trips	|	3.18
|Vadodara	Business-Focused	|5-Trips	|	3.01
|Vadodara	Business-Focused	|4-Trips	|	2.75
|Vadodara	Business-Focused	|3-Trips	|	2.36
|Vadodara	Business-Focused	|7-Trips	|	2.14
|Vadodara	Business-Focused	|2-Trips	|	1.65
|Vadodara	Business-Focused	|8-Trips	|	0.96
|Vadodara	Business-Focused	|9-Trips	|	0.34
|Vadodara	Business-Focused	|10-Trips	|	0.27
|Visakhapatnam	Tourism-Focused		|2-Trips	|	8.54
|Visakhapatnam	Tourism-Focused		|3-Trips	|	4.16
|Visakhapatnam	Tourism-Focused		|4-Trips	|	1.66
|Visakhapatnam	Tourism-Focused		|5-Trips	|	0.91
|Visakhapatnam	Tourism-Focused		|6-Trips	|	0.53
|Visakhapatnam	Tourism-Focused		|7-Trips	|	0.33
|Visakhapatnam	Tourism-Focused		|8-Trips	|	0.23
|Visakhapatnam	Tourism-Focused		|10-Trips	|	0.16
|Visakhapatnam	Tourism-Focused		|9-Trips	|	0.15

# 7. Monthly Target Achievement Analysis for Key Metrics
• For each city, evaluate monthly performance against targets for total trips, new passengers, and average passenger ratings from targets_db. Determine if each metric met, exceeded, or missed the target, and calculate the percentage difference. Identify any consistent patterns in target achievement, particularly across tourism versus business-focused cities.

```sql

```
