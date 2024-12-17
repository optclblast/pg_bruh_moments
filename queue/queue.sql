create or replace function uuid_v6() returns uuid as $$
declare
	v_time timestamp with time zone:= null;
	v_secs bigint := null;
	v_usec bigint := null;
	v_timestamp bigint := null;
	v_timestamp_hex varchar := null;
	v_clkseq_and_nodeid bigint := null;
	v_clkseq_and_nodeid_hex varchar := null;
	v_bytes bytea;
	c_epoch bigint := -12219292800; -- RFC-4122 epoch: '1582-10-15 00:00:00'
	c_variant bit(64):= x'8000000000000000'; -- RFC-4122 variant: b'10xx...'
begin
	v_time := clock_timestamp();
	v_secs := EXTRACT(EPOCH FROM v_time);
	v_usec := mod(EXTRACT(MICROSECONDS FROM v_time)::numeric, 10^6::numeric);
	-- Generate timestamp hexadecimal (and set version 6)
	v_timestamp := (((v_secs - c_epoch) * 10^6) + v_usec) * 10;
	v_timestamp_hex := lpad(to_hex(v_timestamp), 16, '0');
	v_timestamp_hex := substr(v_timestamp_hex, 2, 12) || '6' || substr(v_timestamp_hex, 14, 3);
	-- Generate clock sequence and node identifier hexadecimal (and set variant b'10xx')
	v_clkseq_and_nodeid := ((random()::numeric * 2^62::numeric)::bigint::bit(64) | c_variant)::bigint;
	v_clkseq_and_nodeid_hex := lpad(to_hex(v_clkseq_and_nodeid), 16, '0');
	-- Concat timestemp, clock sequence and node identifier hexadecimal
	v_bytes := decode(v_timestamp_hex || v_clkseq_and_nodeid_hex, 'hex');
	return encode(v_bytes, 'hex')::uuid;
end $$ language plpgsql;

create type job_status as enum (
    'NEW', 
    'PROCESSING', 
    'WAITING', 
    'CANCELLED', 
    'FINISHED'
);

create table queue (
    id uuid primary key default uuid_v6(),
    payload json not null,
    created_at timestamp default current_timestamp, 
    status job_status default 'NEW', 
    error text, 
    result json,
    attempts smallint default 0 
);

CREATE TYPE next_job_result AS (id uuid, payload json);

-- fetcher proc
create or replace function next_job() returns next_job_result as $$ 
declare 
	callResult next_job_result := null; 
begin
	select q.id, q.payload into callResult
    from queue as q 
    where ( 
        status = 'NEW' or 
        status = 'WAITING' 
    ) and 
        attempts < 5
    limit 1 for update;

	update queue 
	set status = 'PROCESSING', 
		attempts = attempts + 1
	where id = (callResult).id;

	return callResult;
END;
$$ LANGUAGE plpgsql;

-- how to use? 
-- 1. Add some jobs:
insert into queue (payload)
values
	('{"@type":"order_created","order_id":"1"}'),
	('{"@type":"order_updated","order_id":"2"}'),
	('{"@type":"order_updated","order_id":"5"}'),
	('{"@type":"order_deleted","order_id":"2"}');
-- 2. Start fetching!
select next_job();