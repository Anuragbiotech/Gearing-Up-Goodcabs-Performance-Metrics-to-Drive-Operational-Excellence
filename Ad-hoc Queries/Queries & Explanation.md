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
```
![image](https://github.com/user-attachments/assets/4429be4a-a3d2-4db6-879b-0488ee60cf0c)


	
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
	dc.city_name,
	pc.month_number -- Sort by the numeric value of the month
;

|city_name	|month_name	|total_target_trips	|total_actual_trips	|performance_status|percentage_difference|
|---------------|---------------|-----------------------|-----------------------|------------------|---------------------|
|Chandigarh	|January	|7000			|6810			|Below Target	   |-2.71
|Chandigarh	|February	|7000			|7387			|Above Target	   |5.53
|Chandigarh	|March		|7000			|6569			|Below Target	   |-6.16
|Chandigarh	|April		|6000			|5566			|Below Target	   |-7.23
|Chandigarh	|May		|6000			|6620			|Above Target	   |10.33
|Chandigarh	|June		|6000			|6029			|Above Target	   |0.48
|Coimbatore	|January	|3500			|3651			|Above Target	   |4.31
|Coimbatore	|February	|3500			|3404			|Below Target	   |-2.74
|Coimbatore	|March		|3500			|3680			|Above Target	   |5.14
|Coimbatore	|April		|3500			|3661			|Above Target	   |4.60
|Coimbatore	|May		|3500			|3550			|Above Target	   |1.43
|Coimbatore	|June		|3500			|3158			|Below Target	   |-9.77
|Indore		|January	|7000			|6737			|Below Target	   |-3.76
|Indore		|February	|7000			|7210			|Above Target	   |3.00
|Indore		|March		|7000			|7019			|Above Target	   |0.27
|Indore		|April		|7500			|7415			|Below Target	   |-1.13
|Indore		|May		|7500			|7787			|Above Target	   |3.83
|Indore		|June		|7500			|6288			|Below Target      |-16.16
|Jaipur		|January	|13000			|14976			|Above Target	   |15.20
|Jaipur		|February	|13000			|15872			|Above Target	   |22.09
|Jaipur		|March		|13000			|13317			|Above Target	   |2.44
|Jaipur		|April		|9500			|11406			|Above Target      |20.06
|Jaipur		|May		|9500			|11475			|Above Target	   |20.79
|Jaipur		|June		|9500			|9842			|Above Target	   |3.60
|Kochi		|January	|7500			|7344			|Below Target	   |-2.08
|Kochi		|February	|7500			|7688			|Above Target	   |2.51
|Kochi		|March		|7500			|9495			|Above Target	   |26.60
|Kochi		|April		|9000			|9762			|Above Target	   |8.47
|Kochi		|May		|9000			|10014			|Above Target	   |11.27
|Kochi		|June		|9000			|6399			|Below Target	   |-28.90
|Lucknow	|January	|13000			|10858			|Below Target	   |-16.48
|Lucknow	|February	|13000			|12060			|Below Target	   |-7.23
|Lucknow	|March		|13000			|11224			|Below Target	   |-13.66
|Lucknow	|April		|11000			|10212			|Below Target	   |-7.16
|Lucknow	|May		|11000			|9705			|Below Target	   |-11.77
|Lucknow	|June		|11000			|10240			|Below Target	   |-6.91
|Mysore		|January	|2000			|2485			|Above Target	   |24.25
|Mysore		|February	|2000			|2668			|Above Target	   |33.40
|Mysore		|March		|2000			|2633			|Above Target	   |31.65
|Mysore		|April		|2500			|2603			|Above Target	   |4.12
|Mysore		|May		|2500			|3007			|Above Target	   |20.28
|Mysore		|June		|2500			|2842			|Above Target	   |13.68
|Surat		|January	|9000			|8358			|Below Target	   |-7.13
|Surat		|February	|9000			|9069			|Above Target	   |0.77
|Surat		|March		|9000			|9267			|Above Target	   |2.97
|Surat		|April		|10000			|9831			|Below Target      |-1.69
|Surat		|May		|10000			|9774			|Below Target      |-2.26
|Surat		|June		|10000			|8544			|Below Target	   |-14.56
|Vadodara	|January	|6000			|4775			|Below Target	   |-20.42
|Vadodara	|February	|6000			|5228			|Below Target	   |-12.87
|Vadodara	|March		|6000			|5598			|Below Target	   |-6.70
|Vadodara	|April		|6500			|5941			|Below Target	   |-8.60
|Vadodara	|May		|6500			|5799			|Below Target      |-10.78
|Vadodara	|June		|6500			|4685			|Below Target	   |-27.92
|Visakhapatnam	|January	|4500			|4468			|Below Target      |-0.71
|Visakhapatnam	|February	|4500			|4793			|Above Target	   |6.51
|Visakhapatnam	|March		|4500			|4877			|Above Target	   |8.38
|Visakhapatnam	|April		|5000			|4938			|Below Target	   |-1.24
|Visakhapatnam	|May		|5000			|4812			|Below Target	   |-3.76
|Visakhapatnam	|June		|5000			|4478			|Below Target	   |-10.44

```

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



|city_name	|2-Trips |3-Trips |4-Trips |5-Trips |6-Trips |7-Trips |8-Trips |9-Trips	|10-Trips|
|---------------|--------|--------|--------|--------|--------|--------|--------|--------|--------|
|Chandigarh	|6.67	 |3.59	  |4.18	   |2.50    |1.60    |1.48    |0.65    |0.59	|0.37	
|Coimbatore	|2.47	 |3.61	  |2.82	   |4.23    |4.43    |2.23    |1.22    |0.63	|0.47
|Indore		|8.50	 |4.35	  |3.24	   |2.40    |1.50    |0.98    |0.67    |0.61	|0.35
|Jaipur		|10.32	 |4.82	  |2.49	   |1.23    |1.19    |0.53    |0.58    |0.26	|0.25
|Kochi		|12.73	 |6.14	  |2.74	   |1.35    |1.09    |0.52    |0.38    |0.29	|0.21
|Lucknow	|2.34	 |3.33	  |3.39	   |3.67    |3.93    |2.56    |1.42    |0.50	|0.21
|Mysore		|12.19	 |4.81	  |3.45	   |1.29    |1.15    |0.61    |0.34    |0.20	|0.20
|Surat		|2.10	 |3.06	  |3.99	   |4.25    |4.26    |3.07    |1.56    |0.39	|0.31
|Vadodara	|2.53	 |3.01	  |4.12	   |3.96    |3.66    |2.55    |1.61    |0.48	|0.39
|Visakhapatnam	|9.89	 |6.46	  |2.25	   |1.25    |0.78    |0.47    |0.27    |0.20	|0.22

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

# Business Request - 5: Identify Month with Highest Revenue for Each City
>Generate a report that identifies the month with the highest revenue for each city. For each city, display the month_name, the revenue amount for that month, and the percentage contribution of that month's revenue to the city's total revenue.

```sql
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
ON	chr.city_id = dc.city_id
WHERE	chr.rank_desc = 1
ORDER BY	
	chr.city_id
;
```

![image](https://github.com/user-attachments/assets/adf219a0-45bb-40f7-b661-d1261cc383f8)


# Business Request - 6: Repeat Passenger Rate Analysis
>Generate a report that calculates two metrics:
>1. Monthly Repeat Passenger Rate: Calculate the repeat passenger rate for each city and month by comparing the number of repeat passengers to the passengers.
>2. City-wide Repeat Passenger Rate: Calculate the overall repeat passenger rate for each city, considering all passengers across months.
>
>These metrics will provide insights into monthly repeat trends as well as the overall repeat behaviour for each city.

```sql
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
    ON		fps.city_id = dc.city_id
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
ON	mm.city_id = cwm.city_id
ORDER BY 
	mm.city_name,
	mm.month_number -- Sort by the numeric value of the month
;



|city_name	|month_name |total_passengers	|repeat_passengers  |monthly_repeat_passenger_rate  |city_repeat_passenger_rate|
|---------------|-----------|-------------------|-------------------|-------------------------------|--------------------------|
|Chandigarh	|January    |4640		|720		    |15.52			    |21.14
|Chandigarh	|February   |4957		|853		    |17.21			    |21.14
|Chandigarh	|March	    |4100		|872		    |21.27			    |21.14
|Chandigarh	|April	    |3285		|789		    |24.02			    |21.14
|Chandigarh	|May	    |3699		|969		    |26.20			    |21.14
|Chandigarh	|June	    |3297		|867		    |26.30			    |21.14
|Coimbatore	|January    |2214		|392		    |17.71			    |23.05
|Coimbatore	|February   |1993		|346		    |17.36			    |23.05
|Coimbatore	|March	    |1965		|427		    |21.73			    |23.05
|Coimbatore	|April	    |1722		|480		    |27.87			    |23.05
|Coimbatore	|May	    |1543		|504		    |32.66			    |23.05
|Coimbatore	|June	    |1628		|402		    |24.69			    |23.05
|Indore		|January    |3876		|1033		    |26.65			    |32.68
|Indore		|February   |3981		|1103		    |27.71			    |32.68
|Indore		|March	    |3833		|1091		    |28.46			    |32.68
|Indore		|April	    |3646		|1295		    |35.52			    |32.68
|Indore		|May	    |3591		|1563		    |43.53			    |32.68
|Indore		|June	    |3152		|1131		    |35.88			    |32.68
|Jaipur		|January    |11845		|1422		    |12.01			    |17.43
|Jaipur		|February   |12450		|1661		    |13.34			    |17.43
|Jaipur		|March	    |9257		|1840		    |19.88			    |17.43
|Jaipur		|April	    |7856		|1736		    |22.10			    |17.43
|Jaipur		|May	    |7174		|1842		    |25.68			    |17.43
|Jaipur		|June	    |6956		|1181		    |16.98			    |17.43
|Kochi		|January    |5660		|795		    |14.05			    |22.40
|Kochi		|February   |5372		|1005		    |18.71			    |22.40
|Kochi		|March	    |6213		|1348		    |21.70			    |22.40
|Kochi		|April	    |6515		|1576		    |24.19			    |22.40
|Kochi		|May	    |6222		|1853		    |29.78			    |22.40
|Kochi		|June	    |4060		|1049		    |25.84			    |22.40
|Lucknow	|January    |4896		|1431		    |29.23			    |37.12
|Lucknow	|February   |5188		|1659		    |31.98			    |37.12
|Lucknow	|March	    |4781		|1622		    |33.93			    |37.12
|Lucknow	|April	    |3807		|1496		    |39.30			    |37.12
|Lucknow	|May	    |3487		|1662		    |47.66			    |37.12
|Lucknow	|June	    |3698		|1727		    |46.70			    |37.12
|Mysore		|January    |2129		|172		    |8.08			    |11.23
|Mysore		|February   |2290		|183		    |7.99			    |11.23
|Mysore		|March	    |2194		|208		    |9.48			    |11.23
|Mysore		|April	    |2072		|236		    |11.39			    |11.23
|Mysore		|May	    |2270		|349		    |15.37			    |11.23
|Mysore		|June	    |2203		|329		    |14.93			    |11.23
|Surat		|January    |3616		|1184		    |32.74			    |42.63
|Surat		|February   |3567		|1313		    |36.81			    |42.63
|Surat		|March	    |3440		|1494		    |43.43			    |42.63
|Surat		|April	    |3394		|1551		    |45.70			    |42.63
|Surat		|May	    |3217		|1606		    |49.92			    |42.63
|Surat		|June	    |3030		|1490		    |49.17			    |42.63
|Vadodara	|January    |2633		|544		    |20.66			    |30.03
|Vadodara	|February   |2756		|610		    |22.13			    |30.03
|Vadodara	|March	    |2522		|759		    |30.10			    |30.03
|Vadodara	|April	    |2499		|862		    |34.49			    |30.03
|Vadodara	|May	    |2256		|868		    |38.48			    |30.03
|Vadodara	|June	    |1807		|703		    |38.90			    |30.03
|Visakhapatnam	|January    |3163		|650		    |20.55			    |28.61
|Visakhapatnam	|February   |3170		|790		    |24.92			    |28.61
|Visakhapatnam	|March	    |3093		|923		    |29.84			    |28.61
|Visakhapatnam	|April	    |2837		|992		    |34.97			    |28.61
|Visakhapatnam	|May	    |2890		|951		    |32.91			    |28.61
|Visakhapatnam	|June	    |2702		|802		    |29.68			    |28.61


```
