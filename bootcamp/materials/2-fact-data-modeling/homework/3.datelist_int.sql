CREATE TABLE device_activity_datelist_int (
    user_id text,
    browser_type text,
    datelist_int bit(32),
    date DATE,
    primary key (user_id, browser_type, date)
);

with starter as (
    select 
        udc.user_id,
        udc.browser_type,
        udc.device_activity_datelist @> ARRAY [DATE(d.valid_date)]   as is_active,
        EXTRACT(
            DAY FROM DATE('2023-01-31') - d.valid_date
        ) as days_since
    from user_devices_cumulated udc
    cross join
    (select generate_series('2023-01-01', '2023-01-31', interval '1 day') as valid_date) as d
    where date = date('2023-01-31')

), bits as (
    select
        user_id,
        browser_type,
        sum(
            case 
                when is_active then pow(2, 32 - days_since)
                else 0
            end 
        )::bigint::bit(32) as datelist_int,
        date('2023-01-31') as date
    from starter
    group by user_id, browser_type
)

insert into device_activity_datelist_int
select * from bits

