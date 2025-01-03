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
• For each city, identify the month with the highest total trips (peak demand) and the month with the lowest total trips (low demand). This analysis will help Goodim_cityabs understand seasonal patterns and adjust resources acategorized_citiesordingly.

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
	SUM(dim_repeat_trip_distribution.repeat_passenger_count) OVER (PARTITION BY dim_repeat_trip_distribution.city_id)
	AS total_repeat_passengers,
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
|Lucknow	|Business-Focused	|6-Trips	|	3.37
|Lucknow	|Business-Focused	|5-Trips	|	3.07
|Lucknow	|Business-Focused	|4-Trips	|	2.70
|Lucknow	|Business-Focused	|3-Trips	|	2.46
|Lucknow	|Business-Focused	|7-Trips	|	1.89
|Lucknow	|Business-Focused	|2-Trips	|	1.61
|Lucknow	|Business-Focused	|8-Trips	|	1.07
|Lucknow	|Business-Focused	|9-Trips	|	0.32
|Lucknow	|Business-Focused	|10-Trips	|	0.19
|Mysore		|Tourism-Focused		|2-Trips	|	8.13
|Mysore		|Tourism-Focused		|3-Trips	|	4.08
|Mysore		|Tourism-Focused		|4-Trips	|	2.12
|Mysore		|Tourism-Focused		|5-Trips	|	0.97
|Mysore		|Tourism-Focused		|6-Trips	|	0.68
|Mysore		|Tourism-Focused		|7-Trips	|	0.30
|Mysore		|Tourism-Focused		|8-Trips	|	0.24
|Mysore		|Tourism-Focused		|9-Trips	|	0.09
|Mysore		|Tourism-Focused		|10-Trips	|	0.08
|Surat		|Business-Focused	|5-Trips	|	3.29
|Surat		|Business-Focused	|6-Trips	|	3.07
|Surat		|Business-Focused	|4-Trips	|	2.76
|Surat		|Business-Focused	|3-Trips	|	2.38
|Surat		|Business-Focused	|7-Trips	|	1.98
|Surat		|Business-Focused	|2-Trips	|	1.63
|Surat		|Business-Focused	|8-Trips	|	1.04
|Surat		|Business-Focused	|9-Trips	|	0.29
|Surat		|Business-Focused	|10-Trips	|	0.23
|Vadodara	|Business-Focused	|6-Trips	|	3.18
|Vadodara	|Business-Focused	|5-Trips	|	3.01
|Vadodara	|Business-Focused	|4-Trips	|	2.75
|Vadodara	|Business-Focused	|3-Trips	|	2.36
|Vadodara	|Business-Focused	|7-Trips	|	2.14
|Vadodara	|Business-Focused	|2-Trips	|	1.65
|Vadodara	|Business-Focused	|8-Trips	|	0.96
|Vadodara	|Business-Focused	|9-Trips	|	0.34
|Vadodara	|Business-Focused	|10-Trips	|	0.27
|Visakhapatnam	|Tourism-Focused		|2-Trips	|	8.54
|Visakhapatnam	|Tourism-Focused		|3-Trips	|	4.16
|Visakhapatnam	|Tourism-Focused		|4-Trips	|	1.66
|Visakhapatnam	|Tourism-Focused		|5-Trips	|	0.91
|Visakhapatnam	|Tourism-Focused		|6-Trips	|	0.53
|Visakhapatnam	|Tourism-Focused		|7-Trips	|	0.33
|Visakhapatnam	|Tourism-Focused		|8-Trips	|	0.23
|Visakhapatnam	|Tourism-Focused		|10-Trips	|	0.16
|Visakhapatnam	|Tourism-Focused		|9-Trips	|	0.15

# 7. Monthly Target Achievement Analysis for Key Metrics
• For each city, evaluate monthly performance against targets for total trips, new passengers, and average passenger ratings from targets_db. Determine if each metric met, exceeded, or missed the target, and calculate the percentage difference. Identify any consistent patterns in target achievement, particularly across tourism versus business-focused cities.

```sql
WITH performance_vs_target AS (
    -- Combine actual performance and target data
    SELECT 
        fact_passenger_summary.city_id,
        dim_city.city_name,
        fact_passenger_summary.month,
        fact_passenger_summary.total_passengers,
        fact_passenger_summary.new_passengers,
        ft.avg_passenger_rating,
        monthly_target_new_passengers.target_new_passengers,
        monthly_target_trips.total_target_trips,
        city_target_passenger_rating.target_avg_passenger_rating,
        -- Calculate percentage differences
        ROUND(
            ((fact_passenger_summary.total_passengers - monthly_target_trips.total_target_trips) * 100.0) / monthly_target_trips.total_target_trips,
            2
        ) AS total_trips_pct_diff,
        ROUND(
            ((fact_passenger_summary.new_passengers - monthly_target_new_passengers.target_new_passengers) * 100.0) / monthly_target_new_passengers.target_new_passengers,
            2
        ) AS new_passengers_pct_diff,
        ROUND(
            ((ft.avg_passenger_rating - city_target_passenger_rating.target_avg_passenger_rating) * 100.0) / city_target_passenger_rating.target_avg_passenger_rating,
            2
        ) AS avg_rating_pct_diff,
        -- Determine target status
        CASE 
            WHEN fact_passenger_summary.total_passengers > monthly_target_trips.total_target_trips THEN 'Exceeded'
            WHEN fact_passenger_summary.total_passengers = monthly_target_trips.total_target_trips THEN 'Met'
            ELSE 'Missed'
        END AS total_trips_status,
        CASE 
            WHEN fact_passenger_summary.new_passengers > monthly_target_new_passengers.target_new_passengers THEN 'Exceeded'
            WHEN fact_passenger_summary.new_passengers = monthly_target_new_passengers.target_new_passengers THEN 'Met'
            ELSE 'Missed'
        END AS new_passengers_status,
        CASE 
            WHEN ft.avg_passenger_rating > city_target_passenger_rating.target_avg_passenger_rating THEN 'Exceeded'
             WHEN ft.avg_passenger_rating = city_target_passenger_rating.target_avg_passenger_rating THEN 'Met'
            ELSE 'Missed'
        END AS avg_rating_status
    FROM trips_db.fact_passenger_summary
    INNER JOIN trips_db.dim_city ON fact_passenger_summary.city_id = dim_city.city_id
    INNER JOIN targets_db.monthly_target_trips monthly_target_trips ON fact_passenger_summary.city_id = monthly_target_trips.city_id AND fact_passenger_summary.month = monthly_target_trips.month
    INNER JOIN targets_db.monthly_target_new_passengers ON fact_passenger_summary.city_id = monthly_target_new_passengers.city_id AND fact_passenger_summary.month = monthly_target_new_passengers.month
    -- Calculate average passenger rating
    INNER JOIN (
        SELECT 
            city_id, 
            ROUND(AVG(passenger_rating), 2) AS avg_passenger_rating
        FROM trips_db.fact_trips
        GROUP BY city_id
    ) ft ON fact_passenger_summary.city_id = ft.city_id
    INNER JOIN targets_db.city_target_passenger_rating city_target_passenger_rating ON fact_passenger_summary.city_id = city_target_passenger_rating.city_id
),
categorized_cities AS (
    -- Categorize cities into tourism-focused and business-focused
    SELECT 
        city_id, 
        city_name,
        CASE 
            WHEN city_name IN ('Visakhapatnam', 'Mysore', 'Jaipur', 'Kochi') THEN 'Tourism-Focused'
            WHEN city_name IN ('Surat', 'Vadodara', 'Indore', 'Lucknow') THEN 'Business-Focused'
            ELSE 'Mixed'
        END AS city_focus
    FROM trips_db.dim_city
)
-- Combine with city categorization and summarize results
SELECT 
    performance_vs_target.city_name,
    categorized_cities.city_focus,
    Monthname(performance_vs_target.month) AS month_name,
    performance_vs_target.total_trips_status,
    performance_vs_target.new_passengers_status,
    performance_vs_target.avg_rating_status,
    performance_vs_target.total_trips_pct_diff,
    performance_vs_target.new_passengers_pct_diff,
    performance_vs_target.avg_rating_pct_diff
FROM performance_vs_target
INNER JOIN categorized_cities ON performance_vs_target.city_id = categorized_cities.city_id
ORDER BY categorized_cities.city_focus, performance_vs_target.city_name, performance_vs_target.month;
```

|city_name		|city_focus			|month_name		|total_trips_status	|passengers_status	|avg_rating_status		|total_trips_pct_diff	|new_passengers_pct_diff|avg_rating_pct_diff|
|-----------------------|-------------------------------|-----------------------|-----------------------|-----------------------|--------------------------------|----------------------|-----------------------|--------------------
|Indore			|Business-Focused		|January		|Missed			|Exceeded	  	|	Missed			|	-44.63		|	5.30		|-2.13
|Indore			|Business-Focused		|February		|Missed			|Exceeded		|	Missed			|	-43.13		|	6.59		|-2.13
|Indore			|Business-Focused		|March			|Missed			|Exceeded		|	Missed			|	-45.24		|	1.56		|-2.13
|Indore			|Business-Focused		|April			|Missed			|Exceeded		|	Missed			|	-51.39		|	17.55		|-2.13
|Indore			|Business-Focused		|May			|Missed			|Exceeded		|	Missed			|	-52.12		|	1.40		|-2.13
|Indore			|Business-Focused		|June			|Missed			|Exceeded		|	Missed			|	-57.97		|	1.05		|-2.13
|Lucknow		|Business-Focused		|January		|Missed			|Exceeded		|	Missed			|	-62.34		|	8.28		|-10.48
|Lucknow		|Business-Focused		|February		|Missed			|Exceeded		|	Missed			|	-60.09		|	10.28		|-10.48
|Lucknow		|Business-Focused		|March			|Missed			|Missed			|	Missed			|	-63.22		|	-1.28		|-10.48
|Lucknow		|Business-Focused		|April			|Missed			|Exceeded		|	Missed			|	-65.39		|	15.55		|-10.48
|Lucknow		|Business-Focused		|May			|Missed			|Missed			|	Missed			|	-68.30		|	-8.75		|-10.48
|Lucknow		|Business-Focused		|June			|Missed			|Missed			|	Missed			|	-66.38		|	-1.45		|-10.48
|Surat			|Business-Focused		|January		|Missed			|Exceeded		|	Missed			|	-59.82		|	21.60		|-8.29
|Surat			|Business-Focused		|February		|Missed			|Exceeded		|	Missed			|	-60.37		|	12.70		|-8.29
|Surat			|Business-Focused		|March			|Missed			|Missed			|	Missed			|	-61.78		|	-2.70		|-8.29
|Surat			|Business-Focused		|April			|Missed			|Exceeded		|	Missed			|	-66.06		|	22.87		|-8.29
|Surat			|Business-Focused		|May			|Missed			|Exceeded		|	Missed			|	-67.83		|	7.40		|-8.29
|Surat			|Business-Focused		|June			|Missed			|Exceeded		|	Missed			|	-69.70		|	2.67		|-8.29
|Vadodara		|Business-Focused		|January		|Missed			|Exceeded		|	Missed			|	-56.12		|	16.06		|-11.87
|Vadodara		|Business-Focused		|February		|Missed			|Exceeded		|	Missed			|	-54.07		|	19.22		|-11.87
|Vadodara		|Business-Focused		|March			|Missed			|Missed			|	Missed			|	-57.97		|	-2.06		|-11.87
|Vadodara		|Business-Focused		|April			|Missed			|Exceeded		|	Missed			|	-61.55		|	9.13		|-11.87
|Vadodara		|Business-Focused		|May			|Missed			|Missed			|	Missed			|	-65.29		|	-7.47		|-11.87
|Vadodara		|Business-Focused		|June			|Missed			|Missed			|	Missed			|	-72.20		|	-26.40		|-11.87
|Chandigarh		|Mixed				|January		|Missed			|Missed			|	Missed			|	-33.71		|	-2.00		|-0.25
|Chandigarh		|Mixed				|February		|Missed			|Exceeded		|	Missed			|	-29.19		|	2.60		|-0.25
|Chandigarh		|Mixed				|March			|Missed			|Missed			|	Missed			|	-41.43		|	-19.30		|-0.25
|Chandigarh		|Mixed				|April			|Missed			|Missed			|	Missed			|	-45.25		|	-16.80		|-0.25
|Chandigarh		|Mixed				|May			|Missed			|Missed			|	Missed			|	-38.35		|	-9.00		|-0.25
|Chandigarh		|Mixed				|June			|Missed			|Missed			|	Missed			|	-45.05		|	-19.00		|-0.25
|Coimbatore		|Mixed				|January		|Missed			|Exceeded		|	Missed			|	-36.74		|	21.47		|-4.48
|Coimbatore		|Mixed				|February		|Missed			|Exceeded		|	Missed			|	-43.06		|	9.80		|-4.48
|Coimbatore		|Mixed				|March			|Missed			|Exceeded		|	Missed			|	-43.86		|	2.53		|-4.48
|Coimbatore		|Mixed				|April			|Missed			|Exceeded		|	Missed			|	-50.80		|	24.20		|-4.48
|Coimbatore		|Mixed				|May			|Missed			|Exceeded		|	Missed			|	-55.91		|	3.90		|-4.48
|Coimbatore		|Mixed				|June			|Missed			|Exceeded		|	Missed			|	-53.49		|	22.60		|-4.48
|Jaipur			|Tourism-Focused		|January		|Missed			|Missed			|	Exceeded		|	-8.88		|	-13.14		|4.00
|Jaipur			|Tourism-Focused		|February		|Missed			|Missed			|	Exceeded		|	-4.23		|	-10.09		|4.00
|Jaipur			|Tourism-Focused		|March			|Missed			|Missed			|	Exceeded		|	-28.79		|	-38.19		|4.00
|Jaipur			|Tourism-Focused		|April			|Missed			|Exceeded		|	Exceeded		|	-17.31		|	2.00		|4.00
|Jaipur			|Tourism-Focused		|May			|Missed			|Missed			|	Exceeded		|	-24.48		|	-11.13		|4.00
|Jaipur			|Tourism-Focused		|June			|Missed			|Missed			|	Exceeded		|	-26.78		|	-3.75		|4.00
|Kochi			|Tourism-Focused		|January		|Missed			|Missed			|	Exceeded		|	-24.53		|	-2.70		|0.24
|Kochi			|Tourism-Focused		|February		|Missed			|Missed			|	Exceeded		|	-28.37		|	-12.66		|0.24
|Kochi			|Tourism-Focused		|March			|Missed			|Missed			|	Exceeded		|	-17.16		|	-2.70		|0.24
|Kochi			|Tourism-Focused		|April			|Missed			|Exceeded		|	Exceeded		|	-27.61		|	23.48		|0.24
|Kochi			|Tourism-Focused		|May			|Missed			|Exceeded		|	Exceeded		|	-30.87		|	9.23		|0.24
|Kochi			|Tourism-Focused		|June			|Missed			|Missed			|	Exceeded		|	-54.89		|	-24.73		|0.24
|Mysore			|Tourism-Focused		|January		|Exceeded		|Missed			|	Exceeded		|	6.45		|	-2.15		|2.35
|Mysore			|Tourism-Focused		|February		|Exceeded		|Exceeded		|	Exceeded		|	14.50		|	5.35		|2.35
|Mysore			|Tourism-Focused		|March			|Exceeded		|Missed			|	Exceeded		|	9.70		|	-0.70		|2.35
|Mysore			|Tourism-Focused		|April			|Missed			|Missed			|	Exceeded		|	-17.12		|	-8.20		|2.35
|Mysore			|Tourism-Focused		|May			|Missed			|Missed			|	Exceeded		|	-9.20		|	-3.95		|2.35
|Mysore			|Tourism-Focused		|June			|Missed			|Missed			|	Exceeded		|	-11.88		|	-6.30		|2.35
|Visakhapatnam		|Tourism-Focused		|January		|Missed			|Exceeded		|	Missed			|	-29.71		|	0.52		|-0.82
|Visakhapatnam		|Tourism-Focused		|February		|Missed			|Missed			|	Missed			|	-29.56		|	-4.80		|-0.82
|Visakhapatnam		|Tourism-Focused		|March			|Missed			|Missed			|	Missed			|	-31.27		|	-13.20		|-0.82
|Visakhapatnam		|Tourism-Focused		|April			|Missed			|Missed			|	Missed			|	-43.26		|	-7.75		|-0.82
|Visakhapatnam		|Tourism-Focused		|May			|Missed			|Missed			|	Missed			|	-42.20		|	-3.05		|-0.82
|Visakhapatnam		|Tourism-Focused		|June			|Missed			|Missed			|	Missed			|	-45.96		|	-5.00		|-0.82

