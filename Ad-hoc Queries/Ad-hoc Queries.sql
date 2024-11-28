/* Before moving to the ad-hoc questions, 
	take a look at each table and/or schema
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

										-- Business Request 1: City-Level Fare and Trip Summary Report
/*
Generate a report that displays the total trips, average fare per km, average fare per trip, and the percentage contribution of each city's trips to the overall trips. This report will help in assessing trip volume, pricing efficiency, and each city's contribution to the overall trip count.
*/

WITH city_trip_metrics AS (
    -- Calculate total trips, average fare per km, and average fare per trip for each city
    SELECT	ft.city_id,
		dc.city_name,
		COUNT(ft.trip_id) AS total_trips,
		ROUND(AVG(ft.fare_amount / ft.distance_travelled_km), 2) AS avg_fare_per_km,
		ROUND(AVG(ft.fare_amount), 2) AS avg_fare_per_trip
    FROM	trips_db.fact_trips ft
    INNER JOIN
		trips_db.dim_city dc
    ON		ft.city_id = dc.city_id
    WHERE	ft.distance_travelled_km > 0 -- Exclude trips with 0 km to avoid division by zero. 
    GROUP BY
		ft.city_id, dc.city_name
),
overall_trip_metrics AS (
    -- Calculate the total trips across all cities
    SELECT	SUM(total_trips) AS overall_total_trips
    FROM	city_trip_metrics
)
-- Combine metrics with percentage contribution
SELECT	ctm.city_name,
		ctm.total_trips,
		ctm.avg_fare_per_km,
		ctm.avg_fare_per_trip,
		ROUND((ctm.total_trips * 100.0) / otm.overall_total_trips, 2) AS trip_percentage_contribution
FROM	city_trip_metrics ctm
CROSS JOIN 
		overall_trip_metrics otm
ORDER BY
		ctm.total_trips DESC
;


										-- Business Request 2: Monthly City-Level Trips Target Performance Report
   
/* Generate a report that evaluates the target performance for trips at the monthly and city level. For each city and month, compare the actual total trips with the target trips and categorize the performance as follows:

• If actual trips are greater than target trips, mark it as "Above Target".
• If actual trips are less or equal to target trips, mark it as "Below Target".

Additionally, calculate the % difference between actual and target trips to quantify the performance gap
*/

WITH actual_trips AS (
-- Aggregate actual trips by city and month
SELECT	fact_trips.city_id,
        DATE_FORMAT(fact_trips.date, '%Y-%m-01') AS month,
        MONTH(fact_trips.date) AS month_number,
        COUNT(fact_trips.trip_id) AS total_actual_trips
FROM 	trips_db.fact_trips
GROUP BY 
		fact_trips.city_id, DATE_FORMAT(fact_trips.date, '%Y-%m-01'), month_number
),
performance_comparison AS (
-- Join aggregated trips with target trips and calculate metrics
SELECT	monthly_target_trips.city_id,
		monthly_target_trips.month,
        actual_trips.month_number,
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
ON		monthly_target_trips.city_id = actual_trips.city_id AND monthly_target_trips.month = actual_trips.month
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
ON 		pc.city_id = dc.city_id
ORDER BY
		dc.city_name, pc.month_number
;


														-- Business Request - 3: City-Level Passenger Trip Frequency Report
/*
Generate a report that shows the percentage distribution of repeat passengers by the number of trips they have taken in each city. Calculate the percentage of repeat passengers who took 2 trips, 3 trips, and so on, up to 10 trips.

Each column should represent a trip count category, displaying the percentage of repeat passengers who fall into that category out of the total repeat passengers for that city.

This report will help identify cities with high repeat trip frequency, which can indicate strong customer loyalty or frequent usage patterns.
*/

WITH city_total_repeat AS (
    -- Calculate total repeat passengers per city
    SELECT	drtd.city_id,
			SUM(drtd.repeat_passenger_count) AS total_repeat_passengers
    FROM	trips_db.dim_repeat_trip_distribution drtd
    WHERE	CAST(SUBSTRING_INDEX(drtd.trip_count, '-', 1) AS UNSIGNED) BETWEEN 2 AND 10
    GROUP BY 
			drtd.city_id
),
percentage_distribution AS (
    -- Calculate percentage distribution for each trip count in each city
    SELECT	drtd.city_id,
			CAST(SUBSTRING_INDEX(drtd.trip_count, '-', 1) AS UNSIGNED) AS trip_count_numeric,
			ROUND(
				drtd.repeat_passenger_count * 100.0 / ctr.total_repeat_passengers, 
				2
			) AS percentage
    FROM	trips_db.dim_repeat_trip_distribution drtd
    INNER JOIN
			city_total_repeat ctr
    ON		drtd.city_id = ctr.city_id
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
ON		pd.city_id = dc.city_id
GROUP BY
		dc.city_name
ORDER BY
		dc.city_name
;

	

										       -- Business Request - 4: Identify Cities with Highest and Lowest Total New Passengers
/*
Generate a report that calculates the total new passengers for each city and ranks them based on this value. Identify the top 3 cities with the highest number of new passengers as well as the bottom 3 cities with the lowest number of new passengers, categorising them as "Top 3" and "Bottom 3" accordingly.
*/							

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



                                                -- Business Request - 5: Identify Month with Highest Revenue for Each City
/*
Generate a report that identifies the month with the highest revenue for each city. For each city, display the month_name, the revenue amount for that month, and the percentage contribution of that month's revenue to the city's total revenue.
*/								

WITH city_monthly_revenue AS (
    -- Calculate monthly revenue for each city
    SELECT	ft.city_id,
			dd.month_name,
			SUM(ft.fare_amount) AS monthly_revenue
    FROM	trips_db.fact_trips ft
    INNER JOIN
			trips_db.dim_date dd
    ON		ft.date = dd.date
    GROUP BY	
			ft.city_id, dd.month_name
),
city_total_revenue AS (
    -- Calculate total revenue for each city
    SELECT	city_id,
			SUM(monthly_revenue) AS total_revenue
    FROM 	city_monthly_revenue
    GROUP BY
			city_id
),
city_highest_revenue_month AS (
    -- Identify the month with the highest revenue for each city
    SELECT	cmr.city_id,
			cmr.month_name,
			cmr.monthly_revenue,
			ctr.total_revenue,
			RANK() OVER (PARTITION BY cmr.city_id ORDER BY cmr.monthly_revenue DESC) AS rank_desc
    FROM	city_monthly_revenue cmr
    INNER JOIN
			city_total_revenue ctr
    ON		cmr.city_id = ctr.city_id
)
-- Final report: Filter to only include the highest revenue month for each city
SELECT	chr.city_id,
		dc.city_name,
		chr.month_name,
		chr.monthly_revenue AS highest_month_revenue,
		ROUND((chr.monthly_revenue / chr.total_revenue) * 100, 2) AS percentage_contribution
FROM	city_highest_revenue_month chr
INNER JOIN
		trips_db.dim_city dc
ON		chr.city_id = dc.city_id
WHERE	chr.rank_desc = 1
ORDER BY	
		chr.city_id
;


                                                  -- Business Request - 6: Repeat Passenger Rate Analysis
/*
Generate a report that calculates two metrics:
1. Monthly Repeat Passenger Rate: Calculate the repeat passenger rate for each city and month by comparing the number of repeat passengers to the passengers.
2. City-wide Repeat Passenger Rate: Calculate the overall repeat passenger rate for each city, considering all passengers across months.

These metrics will provide insights into monthly repeat trends as well as the overall repeat behaviour for each city.
*/

WITH monthly_metrics AS (
    -- Calculate total passengers, repeat passengers, and monthly repeat passenger rate for each city and month
    SELECT	fps.city_id,
			dc.city_name,
			MONTHNAME(fps.month) AS month_name,
			fps.total_passengers,
			fps.repeat_passengers,
			ROUND(
				(fps.repeat_passengers * 100.0) / fps.total_passengers, 
				2
			) AS monthly_repeat_passenger_rate
    FROM	trips_db.fact_passenger_summary fps
    INNER JOIN
			trips_db.dim_city dc
	ON 		fps.city_id = dc.city_id
),
city_wide_metrics AS (
    -- Calculate overall repeat passenger rate for each city
    SELECT	fps.city_id,
			ROUND(
				(SUM(fps.repeat_passengers) * 100.0) / SUM(fps.total_passengers), 
				2
			) AS city_repeat_passenger_rate
    FROM	trips_db.fact_passenger_summary fps
    GROUP BY
			fps.city_id
)
-- Combine both monthly and city-wide metrics
SELECT	mm.city_name,
		mm.month_name,
		mm.total_passengers,
		mm.repeat_passengers,
		mm.monthly_repeat_passenger_rate,
		cwm.city_repeat_passenger_rate
FROM	monthly_metrics mm
INNER JOIN
		city_wide_metrics cwm
ON		mm.city_id = cwm.city_id
ORDER BY 
		mm.city_name, mm.month_name 
;

WITH monthly_metrics AS (
    -- Calculate total passengers, repeat passengers, and monthly repeat passenger rate for each city and month
    SELECT	fps.city_id,
			dc.city_name,
			MONTHNAME(fps.month) AS month_name, -- Convert month date to month name
			MONTH(fps.month) AS month_number, -- Extract numeric value of the month
			fps.total_passengers,
			fps.repeat_passengers,
			ROUND(
				(fps.repeat_passengers * 100.0) / fps.total_passengers, 
				2
			) AS monthly_repeat_passenger_rate
    FROM	trips_db.fact_passenger_summary fps
    INNER JOIN
			trips_db.dim_city dc
	ON 		fps.city_id = dc.city_id
),
city_wide_metrics AS (
    -- Calculate overall repeat passenger rate for each city
    SELECT	fps.city_id,
			ROUND(
				(SUM(fps.repeat_passengers) * 100.0) / SUM(fps.total_passengers), 
				2
			) AS city_repeat_passenger_rate
    FROM	trips_db.fact_passenger_summary fps
    GROUP BY
			fps.city_id
)
-- Combine both monthly and city-wide metrics
SELECT	mm.city_name,
		mm.month_name, -- Use the month name instead of the original month column
		mm.total_passengers,
		mm.repeat_passengers,
		mm.monthly_repeat_passenger_rate,
		cwm.city_repeat_passenger_rate
FROM	monthly_metrics mm
INNER JOIN
		city_wide_metrics cwm
ON		mm.city_id = cwm.city_id
ORDER BY 
		mm.city_name,
		mm.month_number; -- Sort by the numeric value of the month

