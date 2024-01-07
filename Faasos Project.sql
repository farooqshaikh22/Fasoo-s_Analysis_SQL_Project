drop table if exists driver;
CREATE TABLE driver(driver_id integer,reg_date date); 

INSERT INTO driver(driver_id,reg_date) 
 VALUES (1,'01-01-2021'),
(2,'01-03-2021'),
(3,'01-08-2021'),
(4,'01-15-2021');


drop table if exists ingredients;
CREATE TABLE ingredients(ingredients_id integer,ingredients_name varchar(60)); 

INSERT INTO ingredients(ingredients_id ,ingredients_name) 
 VALUES (1,'BBQ Chicken'),
(2,'Chilli Sauce'),
(3,'Chicken'),
(4,'Cheese'),
(5,'Kebab'),
(6,'Mushrooms'),
(7,'Onions'),
(8,'Egg'),
(9,'Peppers'),
(10,'schezwan sauce'),
(11,'Tomatoes'),
(12,'Tomato Sauce');

drop table if exists rolls;
CREATE TABLE rolls(roll_id integer,roll_name varchar(30)); 

INSERT INTO rolls(roll_id ,roll_name) 
 VALUES (1	,'Non Veg Roll'),
(2	,'Veg Roll');

drop table if exists rolls_recipes;
CREATE TABLE rolls_recipes(roll_id integer,ingredients varchar(24)); 

INSERT INTO rolls_recipes(roll_id ,ingredients) 
 VALUES (1,'1,2,3,4,5,6,8,10'),
(2,'4,6,7,9,11,12');

drop table if exists driver_order;
CREATE TABLE driver_order(order_id integer,driver_id integer,pickup_time timestamp,distance VARCHAR(7),duration VARCHAR(10),cancellation VARCHAR(23));
INSERT INTO driver_order(order_id,driver_id,pickup_time,distance,duration,cancellation) 
 VALUES(1,1,'01-01-2021 18:15:34','20km','32 minutes',''),
(2,1,'01-01-2021 19:10:54','20km','27 minutes',''),
(3,1,'01-03-2021 00:12:37','13.4km','20 mins','NaN'),
(4,2,'01-04-2021 13:53:03','23.4','40','NaN'),
(5,3,'01-08-2021 21:10:57','10','15','NaN'),
(6,3,null,null,null,'Cancellation'),
(7,2,'01-08-2021 21:30:45','25km','25mins',null),
(8,2,'01-10-2021 00:15:02','23.4 km','15 minute',null),
(9,2,null,null,null,'Customer Cancellation'),
(10,1,'01-11-2021 18:50:20','10km','10minutes',null);


drop table if exists customer_orders;
CREATE TABLE customer_orders(order_id integer,customer_id integer,roll_id integer,not_include_items VARCHAR(4),extra_items_included VARCHAR(4),order_date timestamp);
INSERT INTO customer_orders(order_id,customer_id,roll_id,not_include_items,extra_items_included,order_date)
values (1,101,1,'','','01-01-2021  18:05:02'),
(2,101,1,'','','01-01-2021 19:00:52'),
(3,102,1,'','','01-02-2021 23:51:23'),
(3,102,2,'','NaN','01-02-2021 23:51:23'),
(4,103,1,'4','','01-04-2021 13:23:46'),
(4,103,1,'4','','01-04-2021 13:23:46'),
(4,103,2,'4','','01-04-2021 13:23:46'),
(5,104,1,null,'1','01-08-2021 21:00:29'),
(6,101,2,null,null,'01-08-2021 21:03:13'),
(7,105,2,null,'1','01-08-2021 21:20:29'),
(8,102,1,null,null,'01-09-2021 23:54:33'),
(9,103,1,'4','1,5','01-10-2021 11:22:59'),
(10,104,1,null,null,'01-11-2021 18:34:49'),
(10,104,1,'2,6','1,4','01-11-2021 18:34:49');

select * from customer_orders;
select * from driver_order;
select * from ingredients;
select * from driver;
select * from rolls;
select * from rolls_recipes;

-- A.roll Metrics

-- 1. How many rolls were ordered?
select count(roll_id)total_roll_ordered from customer_orders

-- 2. How many unique customer order were made?
select count(distinct customer_id)num_of_unique_customer from 
customer_orders

-- 3. How many successful orders were delivered by each driver?
select driver_id,count(order_id)successful_order from
(select *,
case when cancellation in ('Cancellation','Customer Cancellation') then 'c'
else 'nc' end as cancel_status from driver_order)a
where cancel_status != 'c'
group by driver_id
order by driver_id

-- 4.How many of each type of roll delivered?

select roll_id,count(roll_id)total_roll_delivered from
(select b.order_id,c.* from
(select * from
(select *,
case when cancellation in ('Cancellation','Customer Cancellation') then 'c'
else 'nc' end as cancel_status from driver_order)a
where cancel_status != 'c')b
inner join customer_orders c
on b.order_id = c.order_id)d
group by roll_id
order by roll_id

-- 5.How many veg and non-veg rolls were ordered by each customer?

select a.customer_id,b.roll_name,a.num_of_rolls from
(select customer_id,roll_id,count(roll_id)num_of_rolls from customer_orders
group by customer_id,roll_id )a
inner join rolls b 
on a.roll_id = b.roll_id
order by customer_id

-- 6. What was the maximum number of rolls delivered in a single order?
select f.* from
(select *,rank() over(order by num_of_rolls desc) from
(select order_id,count(roll_id)num_of_rolls from
(select c.* from
(select * from
(select *,
case when cancellation in ('Cancellation','Customer Cancellation') then 'c'
else 'nc' end as cancel_status from driver_order)a
where cancel_status != 'c')b inner join customer_orders c
on b.order_id = c.order_id)d
group by order_id)e)f
where rank=1

/* 7. For each customer how many delivered rolls had atleast 1 change and
how many had no change? */

-- creating first temporary table (temporary_customer_orders)
with temporary_customer_orders(
	order_id ,customer_id ,roll_id,not_include_items,extra_items_included,
	order_date
)
as
(select *,
	case 
	when not_include_items is null  or not_include_items = '' then '0' else '1'
	end as excluded_items,
    case
	when extra_items_included is null or extra_items_included in  ('','NaN') then '0' else '1'	
	end
 as included_items
	from customer_orders

)
,
temp_driver_order(
order_id,driver_id,pickup_time,distance,duration,cancellation
)
as
(
    select *,
	case when cancellation in ('Cancellation','Customer Cancellation')
	then 1 else 0 end as new_cancellation	
	from driver_order
)

select b.customer_id,b.change,count(b.change)change_no_change_count from
(select *,
case when excluded_items='1' or included_items='1' then 'Change' else 'No change'
end as change
from
(select order_id,customer_id,roll_id,order_date,excluded_items,included_items
from temporary_customer_orders where order_id in 
(select order_id from temp_driver_order where new_cancellation = 0))a)b
group by b.customer_id,b.change

-- 8.How many rolls were delivered  that had both exclusion and extras.

with temporary_customer_orders(
	order_id ,customer_id ,roll_id,not_include_items,extra_items_included,
	order_date
)
as
(select *,
	case 
	when not_include_items is null  or not_include_items = '' then '0' else '1'
	end as excluded_items,
    case
	when extra_items_included is null or extra_items_included in  ('','NaN') then '0' else '1'	
	end
 as included_items
	from customer_orders

)
,
temp_driver_order(
order_id,driver_id,pickup_time,distance,duration,cancellation
)
as
(
    select *,
	case when cancellation in ('Cancellation','Customer Cancellation')
	then 1 else 0 end as new_cancellation	
	from driver_order
)
select count(order_id)both_inclusion_exclusion_count from
(select order_id,customer_id,roll_id,order_date,excluded_items,included_items
from temporary_customer_orders where order_id in 
(select order_id from temp_driver_order where new_cancellation = 0))a
where excluded_items='1' and included_items='1'

-- 9.What was the total number of rolls ordered for each hour of the day?

select hour_bucket,count(hour_bucket)hour_bucket_count from
(select *,concat(date_part('hour',order_date),'-',date_part('hour',order_date)+1)hour_bucket
from customer_orders)a
group by hour_bucket

-- 10.What was the number of orders for each day of the week?

select day_of_week, count(distinct order_id)num_of_orders from
(select *,to_char(order_date,'Day')day_of_week from customer_orders)a
group by day_of_week

-- B. driver and customer experience

/* 1. what was the average time in minutes it took for each driver to arrive at
the faasos HQ to pickup the order? */

select driver_id,round(avg(time_difference),0)avg_time_in_minutes from
(select distinct a.order_id,a.order_date,b.driver_id,b.pickup_time,
extract(epoch from age(b.pickup_time,a.order_date))/60 time_difference
from customer_orders a
inner join driver_order b 
on a.order_id = b.order_id
where pickup_time is not null)c
group by driver_id order by driver_id

/* 2.is there any relationship between the number of rolls and how longer order
takes to prepare? */

select num_of_orders,round(avg(time_difference),0)avg_time from
(select order_id,count(roll_id)num_of_orders,time_difference from
(select a.order_id,a.roll_id,a.order_date,b.driver_id,b.pickup_time,
extract(epoch from age(b.pickup_time,a.order_date))/60 time_difference
from customer_orders a
inner join driver_order b 
on a.order_id = b.order_id
where pickup_time is not null)c
group by order_id,time_difference order by order_id)d
group by num_of_orders

-- Note : As number of orders increases,average time for preparation also increases

/* 3.What was the average distance travelled for each customer? */

select d.customer_id,round(avg(d.new_distance),2)avg_distance from
(select c.*,cast(trim(replace(lower(c.distance),'km','')) as decimal)new_distance
 from
(select distinct a.order_id,a.customer_id,b.driver_id,b.distance from customer_orders a
inner join driver_order b
on a.order_id = b.order_id
where distance is not null)c)d
group by d.customer_id order by customer_id

/* 4.What was the difference between the longest and shortest delivery times
for all orders.*/

select max(a.new_duration)-min(a.new_duration) diff from
(select duration,cast(case
when duration like '%min%' then left(duration,position('m' in duration)-1)
else duration end as integer) as new_duration
from driver_order
where duration is not null)a

/* 5.What was the avereage speed for each driver for delivery.*/

select a.order_id,a.driver_id,round((a.new_distance/a.new_duration)*60,2) as "speed(km/h)" from
(select order_id,driver_id,
cast(trim(replace(lower(distance),'km',''))as decimal)new_distance,
cast(case when duration like '%min%' then left(duration,position('m' in duration)-1)
else duration end as integer) as new_duration
from driver_order where distance is not null)a

/* 6.What is the successful delivery percentage for each driver? */
select * from customer_orders;
select * from driver_order;

select b.driver_id, round(b.order_delivered*1.0/b.order_recived,2)*100 successful_delivery_percentage from
(select a.driver_id,count(a.driver_id)order_recived,sum(a.cancel_status)order_delivered
from
(select order_id,driver_id,cancellation,
case when lower(cancellation) like '%cancel%' then 0 else 1 end as cancel_status
from driver_order)a
group by a.driver_id)b
order by b.driver_id
