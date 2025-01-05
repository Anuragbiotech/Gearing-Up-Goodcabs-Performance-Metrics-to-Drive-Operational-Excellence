-- 1. Top and Bottom Performing Cities
-- • Identify the top 3 and bottom 3 cities by total trips over the entire analysis period.

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

-- 2. Average Fare per Trip by City
-- • Calculate the average fare per trip each city and compare it with the city's average trip distance. Identify the cities with the highest and lowest average fare per trip to assess pricing efficiency across locations.

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


-- 3. Average Ratings by City and Passenger Type
-- • Calculate the average passenger and driver ratings for each city, segmented by passenger type (new vs. repeat). Identify cities with the highest and lowest average ratings.

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


-- 4. Peak and Low Demand Months by City
-- • For each city, identify the month with the highest total trips (peak demand) and the month with the lowest total trips (low demand). This analysis will help Goodcabs understand seasonal patterns and adjust resources accordingly.

    
WITH monthly_trip_counts AS (
SELECT	dim_city.city_name AS City_Name,
        DATE_FORMAT(fact_trips.date, "%Y-%m") AS Month,
        monthname(fact_trips.date) AS month_name,
        COUNT(fact_trips.trip_id) AS Total_Trips
FROM
        trips_db.fact_trips
INNER JOIN
        trips_db.dim_city ON fact_trips.city_id = dim_city.city_id
GROUP BY
        dim_city.city_name, DATE_FORMAT(fact_trips.date, "%Y-%m"), month_name
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
SELECT	City_Name,
		month_name,
		Total_Trips,
		'Peak' AS Demand_Type
FROM
		ranked_months
WHERE
		rank_desc = 1
        
UNION ALL

SELECT
		City_Name,
        month_name,
		Total_Trips,
		'Low' AS Demand_Type
FROM
		ranked_months
WHERE
		rank_asc = 1
ORDER BY
		City_Name, Demand_Type DESC, Total_Trips DESC
;



-- 5. Weekend vs. Weekday Trip Demand by City 
-- • Compare the total trips taken on weekdays versus weekends for each city over the six-month period. Identify cities with a strong preference for either weekend or weekday trips to understand demand variations.

SELECT	dim_city.city_name,
		SUM(CASE WHEN dim_date.day_type = 'Weekday' THEN 1 ELSE 0 END) AS total_weekday_trips,
		SUM(CASE WHEN dim_date.day_type = 'Weekend' THEN 1 ELSE 0 END) AS total_weekend_trips
FROM
		trips_db.fact_trips
INNER JOIN
		trips_db.dim_date ON fact_trips.date = dim_date.date
INNER JOIN
		trips_db.dim_city ON fact_trips.city_id = dim_city.city_id
GROUP BY
		dim_city.city_name
ORDER BY
		dim_city.city_name
;

-- 6. Repeat Passenger Frequency and City Contribution Analysis
-- • Analyse the frequency of trips taken by repeat passengers in each city (e.g., % of repeat passengers taking 2 trips, 3 trips, etc.). Identify which cities contribute most to higher trip frequencies among repeat passengers, and examine if there are distinguishable patterns between tourism-focused and business-focused cities.

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
	city_name, city_focus, repeat_passenger_contribution DESC
    
;

-- 7. Monthly Target Achievement Analysis for Key Metrics
-- • For each city, evaluate monthly performance against targets for total trips, new passengers, and average passenger ratings from targets_db. Determine if each metric met, exceeded, or missed the target, and calculate the percentage difference. Identify any consistent patterns in target achievement, particularly across tourism versus business-focused cities.

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


-- 8. Highest and Lowest Repeat Passenger Rate (RPR%) by City and Month
-- • Analyse the Repeat Passenger Rate (RPR%) for each city across the six-month period. Identify the top 2 and bottom 2 cities based on their RPR% to determine which locations have the strongest and weakest rates.
-- • Similarly, analyse the RPR% by month across all cities and identify the months with the highest and lowest repeat passenger rates. This will help to pinpoint any seasonal patterns or months with higher repeat passenger loyalty.

WITH city_rpr AS (
    -- Calculate RPR% for each city over the six-month period
    SELECT 
        fact_passenger_summary.city_id,
        dim_city.city_name,
        ROUND(
            (SUM(fact_passenger_summary.repeat_passengers) * 100.0) / SUM(fact_passenger_summary.total_passengers), 
            2
        ) AS avg_rpr
    FROM trips_db.fact_passenger_summary
    INNER JOIN trips_db.dim_city ON fact_passenger_summary.city_id = dim_city.city_id
    GROUP BY fact_passenger_summary.city_id, dim_city.city_name
),
month_rpr AS (
    -- Calculate RPR% for each month across all cities
    SELECT 
        fact_passenger_summary.month,
        dim_date.month_name,
        ROUND(
            (SUM(fact_passenger_summary.repeat_passengers) * 100.0) / SUM(fact_passenger_summary.total_passengers), 
            2
        ) AS monthly_rpr
    FROM trips_db.fact_passenger_summary
    INNER JOIN trips_db.dim_date ON fact_passenger_summary.month = dim_date.start_of_month
    GROUP BY fact_passenger_summary.month, dim_date.month_name
),
ranked_cities AS (
    -- Rank cities based on their RPR%
    SELECT 
        city_name,
        avg_rpr,
        RANK() OVER (ORDER BY avg_rpr DESC) AS rpr_rank_top,
        RANK() OVER (ORDER BY avg_rpr ASC) AS rpr_rank_bottom
    FROM city_rpr
),
ranked_months AS (
    -- Rank months based on their RPR%
    SELECT 
        month_name,
        monthly_rpr,
        RANK() OVER (ORDER BY monthly_rpr DESC) AS rpr_rank_high,
        RANK() OVER (ORDER BY monthly_rpr ASC) AS rpr_rank_low
    FROM month_rpr
)
-- Combine city and month analyses to identify top/bottom performers
SELECT 
    -- City Analysis
    'City Analysis' AS analysis_type,
    CASE 
        WHEN ranked_cities.rpr_rank_top <= 2 THEN 'Top 2 Cities'
        WHEN ranked_cities.rpr_rank_bottom <= 2 THEN 'Bottom 2 Cities'
    END AS category,
    ranked_cities.city_name AS name,
    ranked_cities.avg_rpr AS rpr_percentage
FROM ranked_cities
WHERE ranked_cities.rpr_rank_top <= 2 OR ranked_cities.rpr_rank_bottom <= 2

UNION ALL

SELECT 
    -- Month Analysis
    'Month Analysis' AS analysis_type,
    CASE 
        WHEN ranked_months.rpr_rank_high = 1 THEN 'Month with Highest RPR%'
        WHEN ranked_months.rpr_rank_low = 1 THEN 'Month with Lowest RPR%'
    END AS category,
    ranked_months.month_name AS name,
    ranked_months.monthly_rpr AS rpr_percentage
FROM ranked_months
WHERE ranked_months.rpr_rank_high = 1 OR ranked_months.rpr_rank_low = 1
;
