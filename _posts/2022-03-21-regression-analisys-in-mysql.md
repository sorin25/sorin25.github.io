---
title: Given the current trend, when will I reach my ideal weight ?
thumb: blog-post-thumb-8.jpg
layout: article
---

I've been recording my weight for a while now, and trying to ge to my ideal weight. This is a slow process and takes a lot of time. 
In order to see the light at the end of the tunnel, I started trying to project given the current weight loss streak, when would I reach my ideal weight.

It's a mater of performing a linear regression over the exiting data. 

I record my weight multiple times a day, mostly because the [Viva OMRON scale](https://www.omron-healthcare.com/eu/digital-scales/VIVA.html) I have seems to be kind of flaky, and I average it over the day. 

To graph the current streak data I would need the list of day averages relative to the start date:

```SQL
SELECT avg(weight) AS weight, DATEDIFF(date(record_date), start_date) AS day 
        FROM weight_log WHERE record_date > @start_date GROUP BY date(record_date);
```

The slope formula is:

$$ slope = \frac{\sum{(y - \overline{y}) (x - \overline{x})}}{\sum{(x - \overline{x})^2}} $$


The intercept formula is:

$$ intercept = \overline{y} - slope \cdot \overline{x} $$


The formula for linear regression slope needs the average of both X and Y axis. 

```SQL
SELECT 
        avg(weight) AS weight_average,
        avg(day) AS day_average 
    FROM (
        SELECT 
                avg(weight) AS weight, 
                DATEDIFF(date(record_date), @start_date) AS day 
            FROM weight_log 
            WHERE record_date > @start_date GROUP BY date(record_date)
    ) AS A;
```


Since we will need the data in several places, let's use stored procedure and save it in memory table for reuse. 


```SQL
DELIMITER //
DROP PROCEDURE IF EXISTS get_weight_slope //

CREATE PROCEDURE get_weight_slope(
    IN start_date DATE
)
BEGIN
DECLARE weight_average DECIMAL(10,3);
DECLARE days_average DECIMAL(10,2);

SET @@session.sql_notes = 0;
DROP TEMPORARY TABLE IF EXISTS weight_slope_information;
CREATE TEMPORARY TABLE weight_slope_information engine=memory 
    SELECT 
            avg(weight) AS weight, 
            DATEDIFF(date(record_date), start_date) AS day 
        FROM weight_log 
        WHERE record_date > start_date GROUP BY date(record_date);

SELECT avg(weight), avg(day) INTO weight_average, days_average FROM weight_slope_information;

SELECT 
        sum((weight - weight_average)*(day - days_average)) /
                sum((day-days_average)*(day - days_average)) AS slope,
        weight_average - 
            sum((weight - weight_average)*(day - days_average)) / 
                sum((day-days_average)*(day - days_average)) * days_average AS intercept 
    FROM weight_slope_information;

END //

```


With the returned information you can compute the number of days from start that will be needed to reach a specific weight:

$$ days = target - \frac{intercept}{slope} $$




