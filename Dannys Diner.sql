CREATE DATABASE dannys_diner;

USE dannys_diner;

CREATE TABLE sales(
	customer_id VARCHAR(1),
	order_date DATE,
	product_id INTEGER
);

INSERT INTO sales
	(customer_id, order_date, product_id)
VALUES
	('A', '2021-01-01', 1),
	('A', '2021-01-01', 2),
	('A', '2021-01-07', 2),
	('A', '2021-01-10', 3),
	('A', '2021-01-11', 3),
	('A', '2021-01-11', 3),
	('B', '2021-01-01', 2),
	('B', '2021-01-02', 2),
	('B', '2021-01-04', 1),
	('B', '2021-01-11', 1),
	('B', '2021-01-16', 3),
	('B', '2021-02-01', 3),
	('C', '2021-01-01', 3),
	('C', '2021-01-01', 3),
	('C', '2021-01-07', 3);

CREATE TABLE menu(
	product_id INTEGER,
	product_name VARCHAR(5),
	price INTEGER
);

INSERT INTO menu
	(product_id, product_name, price)
VALUES
	(1, 'sushi', 10),
    (2, 'curry', 15),
    (3, 'ramen', 12);

CREATE TABLE members(
	customer_id VARCHAR(1),
	join_date DATE
);

-- Still works without specifying the column names explicitly
INSERT INTO members
	(customer_id, join_date)
VALUES
	('A', '2021-01-07'),
    ('B', '2021-01-09');


-- 1. What is the total amount each customer spent at the restaurant?
select sales.customer_id, sum(menu.price) as total_spent from sales
inner join menu
on sales.product_id = menu.product_id
group by sales.customer_id;

-- 2. How many days has each customer visited the restaurant?
select customer_id, count(distinct order_date) as days_visited from sales
group by customer_id;

-- 3. What was the first item from the menu purchased by each customer?
with customer_first_purchase as (select s.customer_id, min(s.order_date) as first_purchase_date from sales s
group by s.customer_id
)
select cfp.customer_id, cfp.first_purchase_date, m.product_name
from customer_first_purchase cfp
join sales s on s.customer_id = cfp.customer_id
AND cfp.first_purchase_date = s.order_date
JOIN menu m on m.product_id = s.product_id;

-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
select m.product_name, count(*) as total_purchased
from sales s
Join menu m on s.product_id = m.product_id
group by m.product_name
order by total_purchased desc limit 1 ;

-- 5. Which item was the most popular for each customer?
with customer_popularity as(
select s.customer_id, m.product_name, count(*) as purchase_count,
dense_rank() over(partition by s.customer_id order by count(*) desc) as ranks
from sales s
join menu m on s.product_id = m.product_id
group by s.customer_id, m.product_name
)
select cp.customer_id, cp.product_name, cp.purchase_count
from customer_popularity cp
where ranks = 1 ;

-- 6. Which item was purchased first by the customer after they became a member?
with first_purchase_after_membership as (
select s.customer_id, min(s.order_date) as first_purchase_date
from sales s 
join members mb on s.customer_id = mb.customer_id
where s.order_date >= mb.join_date
group by  s.customer_id
)
select fpam.customer_id, m.product_name
from first_purchase_after_membership fpam
join sales s on s.customer_id = fpam.customer_id
and fpam .first_purchase_date = s.order_date
join menu m on s.product_id = m.product_id;

-- 7. Which item was purchased just before the customer became a member?
with last_purchase_before_membership as (
select s.customer_id, max(s.order_date) as last_purchase_date
from sales s 
join members mb on s.customer_id = mb.customer_id
where s.order_date < mb.join_date
group by  s.customer_id
)
select lpbm.customer_id, m.product_name
from last_purchase_before_membership lpbm
join sales s on lpbm.customer_id = s.customer_id
and lpbm .last_purchase_date = s.order_date
join menu m on s.product_id = m.product_id;


-- 8. What is the total items and amount spent for each member before they became a member?

select s.customer_id, count(*) as total_item, sum(m.price) as total_spent
from sales s
join menu m on s.product_id = m.product_id
join members mb on s.customer_id = mb.customer_id
where s.order_date < mb.join_date
group by s.customer_id;


-- 9. If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
select s.customer_id, sum(
CASE
    WHEN m.product_name = 'sushi' then m.price * 20 else m.price *10 END) as total_points
from sales s
join menu m on s.product_id = m.product_id
group by s.customer_id;


/* 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - 
how many points do customer A and B have at the end of January?*/

select s.customer_id, sum(
  case 
      when s.order_date between mb.join_date and ADDDATE(mb.join_date, INTERVAL 7 DAY)
      then m.price*20
      when m.product_name = 'sushi' then m.price*20
      else m.price*10 end) as total_points
from sales s 
join menu m on s.product_id = m.product_id
left join members mb on s.customer_id = mb.customer_id
where s.customer_id in ('A', 'B') AND s.order_date <= '2021-01-31'
group by s.customer_id;

-- 11. Recreate the table output using the available data

select s.customer_id, s.order_date, m.product_name, m.price,
case when s.order_date >= mb.join_date then 'Y'
ELSE 'N' END AS member
from sales s
join menu m on s.product_id = m.product_id
LEFT JOIN members mb on s.customer_id = mb.customer_id
order by s.customer_id, s.order_date;

-- 12. Rank all the things:

with customer_data as (
select s.customer_id, s.order_date, m.product_name, m.price,
case 
    when s.order_date < mb.join_date then 'N'
    WHEN s.order_date >= mb.join_date then 'Y'
    ELSE 'N' END as memeber
from sales s
Left JOIN members mb on s.customer_id = mb.customer_id
join menu m on s.product_id = m.product_id
)
select *,
case when memeber = 'N' THEN NULL
ELSE RANK() OVER(PARTITION BY customer_id, memeber order by order_date)
end as ranking
from customer_data
order by customer_id, order_date;
