insert into orders (
	user_id, to_pay, order_payload
)
values 
    ((select trunc(random() * 9999999 + 1)), random(), '{}'),
    ((select trunc(random() * 9999999 + 1)), random(), '{}'),
    ((select trunc(random() * 9999999 + 1)), random(), '{}'),
    ((select trunc(random() * 9999999 + 1)), random(), '{}'),
    ((select trunc(random() * 9999999 + 1)), random(), '{}')
;

select * from orders; -- check orders
select * from event_exchange ee -- check that events table is empty

update orders set order_payload = '{"items":[{"id":1,"price":100}]}' -- update order
where id = 1;

select * from event_exchange ee; -- check agian










