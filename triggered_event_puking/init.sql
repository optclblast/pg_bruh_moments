create table orders (
    id bigserial primary key, 
    user_id bigint not null,  
    to_pay decimal default 0, 
    created_at timestamp default current_timestamp,
    order_payload json -- some order payload idk
);

create index idx_orders_user_id on 
    orders (user_id); 

create table event_exchange (
    id bigserial primary key,
    topic text,
    payload json
);

create index idx_event_exchange_topic on 
    event_exchange (topic); 

create function orders_payload_upd() 
	returns trigger AS
$func$
begin 
    insert into event_exchange (
       topic, payload  
    ) values (
        'order_updated', json_build_object('order_id', new.id, 'new_payload', new.order_payload)
    );
	return null;
end
$func$ language plpgsql;

create trigger order_payload_updated 
    after update of order_payload
    on orders 
    for each row
execute function orders_payload_upd();

