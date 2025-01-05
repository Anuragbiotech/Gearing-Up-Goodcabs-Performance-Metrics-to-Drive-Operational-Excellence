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

