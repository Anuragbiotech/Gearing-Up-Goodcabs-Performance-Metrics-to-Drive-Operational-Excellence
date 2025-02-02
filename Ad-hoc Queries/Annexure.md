# [Business-Request-1-Query Explanation](https://github.com/Anuragbiotech/Gearing-Up-Goodcabs-Performance-Metrics-to-Drive-Operational-Excellence/blob/main/Ad-hoc%20Queries/Queries%20&%20Explanation.md#business-request-1-city-level-fare-and-trip-summary-report)

**Explanation:**

1. **city_trip_metrics CTE (City-Level Metrics)**
This CTE computes trip-related metrics for each city:
total_trips: Counts the total number of trips (COUNT(ft.trip_id)) for each city.

	avg_fare_per_km: Calculates the average fare per kilometer (ft.fare_amount / ft.distance_travelled_km). Trips with zero distance are excluded to prevent division errors.

	avg_fare_per_trip: Computes the average fare per trip (AVG(ft.fare_amount)).

	The metrics are grouped by city (ft.city_id, dc.city_name) to ensure distinct calculations for each city.

2. **overall_trip_metrics CTE (Overall Metrics)**

	This CTE calculates the total number of trips across all cities (SUM(total_trips)) derived from the city_trip_metrics CTE. This will a single value of **425903**.

3. **Main Query (Combining City-Level and Overall Metrics)**

	**Joins**:
	CROSS JOIN combines city_trip_metrics and overall_trip_metrics to allow each city to calculate its percentage contribution to the total trips.
	CROSS JOIN is appropriate here as there is no shared key between the datasets, and the overall metric applies to all cities.

	**Trip Contribution Calculation:**

	_Trip Percentage Contribution = (City Total Trips * 100 \ Overall Total Trips)_ 

	**Sorting**:
	Cities are sorted by their total trips in descending order (ORDER BY ctm.total_trips DESC) to highlight the highest-performing cities.

**Further Explanation:**

You can also run the query below, but it will take longer. The below query completed in 1.265 sec while the above query in 1.188 sec.

```sql
WITH city_trip_metrics AS (
    -- Calculate total trips, average fare per km, and average fare per trip for each city
    SELECT	ft.city_id,
			dc.city_name,
			COUNT(ft.trip_id) AS total_trips,
			ROUND(AVG(ft.fare_amount / ft.distance_travelled_km), 2) AS avg_fare_per_km,
			ROUND(AVG(ft.fare_amount), 2) AS avg_fare_per_trip,
            ROUND(COUNT(ft.trip_id) * 100 / (SELECT COUNT(trip_id) FROM trips_db.fact_trips),2) as trip_percentage_contribution
    FROM	trips_db.fact_trips ft
    INNER JOIN
			trips_db.dim_city dc
	ON		ft.city_id = dc.city_id
    WHERE	ft.distance_travelled_km > 0 -- Exclude trips with 0 km to avoid division by zero. 
    GROUP BY
			ft.city_id, dc.city_name
)
-- Combine metrics with percentage contribution
SELECT	ctm.city_name,
		ctm.total_trips,
		ctm.avg_fare_per_km,
		ctm.avg_fare_per_trip,
        ctm.trip_percentage_contribution
FROM	city_trip_metrics ctm
ORDER BY
		ctm.total_trips DESC
;
```

# [Business Request 2: Query Explanation](https://github.com/Anuragbiotech/Gearing-Up-Goodcabs-Performance-Metrics-to-Drive-Operational-Excellence/blob/main/Ad-hoc%20Queries/Queries%20%26%20Explanation.md#business-request-2-monthly-city-level-trips-target-performance-report)
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

# [Business Request - 3: Query Explanation](https://github.com/Anuragbiotech/Gearing-Up-Goodcabs-Performance-Metrics-to-Drive-Operational-Excellence/blob/main/Ad-hoc%20Queries/Queries%20&%20Insights.md#business-request---3-city-level-passenger-trip-frequency-report)

**Explanation:**

1. City Total Repeat Passengers (city_total_repeat): This common table expression (CTE) calculates the total number of repeat passengers for each city.

   Key Operations:
   Extract the numeric value from trip_count (e.g., "3-Trips" becomes 3) using CAST(SUBSTRING_INDEX(drtd.trip_count, '-', 1) AS UNSIGNED).
   Filter records to include only trip counts between 2 and 10.
   Sum the repeat_passenger_count for each city.

2. Percentage Distribution (percentage_distribution): This CTE calculates the percentage distribution of repeat passengers for each trip count category (2 to 10 trips) within each city.

   Key Operations: For each city, calculate the percentage contribution of each trip_count_numeric to the city's total repeat passengers:

   	>percentage = (repeat_passenger_count / total_repeat_passengers) x 100

   Use a JOIN to bring in total_repeat_passengers from the city_total_repeat CTE.

3. Final SELECT: Pivot the Data: The final query pivots the data to display trip count categories (2-Trips, 3-Trips, etc.) as columns, with the percentage values for each city.

   Key Operations:
   Use CASE expressions to create separate columns for each trip count category.
   Use MAX() to ensure one value is selected for each column. Since there’s one percentage per city-trip count pair, MAX() works as a simple value selector.

   **Further Explanation:**

   Why Use MAX()?

   When pivoting, there might be multiple rows for the same group (e.g., city and trip count).
   To ensure that only a single value appears in each pivoted column for that group, an aggregate function like MAX() is applied. Since percentages are already calculated per group (e.g., city and trip count), taking the maximum works effectively as there is only one value.

# [Business Request - 4: Query Explanation](https://github.com/Anuragbiotech/Gearing-Up-Goodcabs-Performance-Metrics-to-Drive-Operational-Excellence/blob/main/Ad-hoc%20Queries/Queries%20&%20Insights.md#business-request---4-identify-cities-with-highest-and-lowest-total-new-passengers)

**Explanation:**

1. City Total New Passengers (city_total_new_passengers): This CTE sums up total new passengers for each city. It takes the value from fact_passenger_summary table of the trips_db database.
2. City Ranking (city_ranking): This CTE ranks the total_new_passengers by descending and ascending order. This ordering further helps in the next CTE to categorize cities as Top 3 and Bottom 3 according to most new_passengers and least new passengers.
3. Categorized Cities (categorized_cities): The Business Report 3 asks about Top 3 and Bottom 3 cities by New Passenger. This CTE helps in categorizing cities in these categories. 
   Here, CASE statements are used to categorize rankings (desc. order) where rank_desc is less than or equal to 3 then Top 3 and when rank_asc is less than or equal to 3 then Bottom 3.

   At the end, all relevant columns are referenced by SELECT statement and filtered by WHERE clause, ie., including Top 3 and Bottom 3.

# [Business Request - 5: Query Explanation](https://github.com/Anuragbiotech/Gearing-Up-Goodcabs-Performance-Metrics-to-Drive-Operational-Excellence/blob/main/Ad-hoc%20Queries/Queries%20&%20Insights.md#business-request---5-identify-month-with-highest-revenue-for-each-city)

**Explanation:**

1. City Monthly Revenue (city_monthly_revenue): This CTE sums up the fare_amount in the fact_trips table of the trips_db database for each month and city combination.
2. City Total Revenue (city_total_revenue): This CTE sums up monthly_revenue for each city.
3. City Highest Revenue Month (city_highest_revenue_month): This CTE ranks the monthly_revenue in descending order so that in the final output we can extract the city and month with only highest revenue.

At the end, all relevant columns are referenced by SELECT statement and filtered by WHERE clause to include rank_desc = 1 so that only city with highest montly revenue will show up in the output.

# [Business Request - 6: Query Explanation](https://github.com/Anuragbiotech/Gearing-Up-Goodcabs-Performance-Metrics-to-Drive-Operational-Excellence/blob/main/Ad-hoc%20Queries/Queries%20&%20Insights.md#business-request---6-repeat-passenger-rate-analysis)

**Explanation:**

1. Monthly Metrics (monthly_metrics): This CTE finds total passengers, total repeat passengers, and monthly repeat passenger rate for each city and month.
2. City Wide Metrics (city_wide_metrics): This CTE finds overall repeate passenger rate for each city.

The final output is all the relevant columns plus monthly_repeat_passenger_rate (city and month wise combination) and city_repeat_passenger_rate for each city. 

>Note: Keep in mind that city_repeat_passenger_rate is same for each city.
