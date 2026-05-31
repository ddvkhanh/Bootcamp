create table user_devices_cumulated  (
    user_id text,
    browser_type text,
    device_activity_datelist date[],
    date DATE,
    primary key (user_id, browser_type, date)
);

insert into user_devices_cumulated
with yesterday as (
    select * 
    from user_devices_cumulated
    where date = date('2023-01-01')
), 
today as (
    select
        cast(user_id as text) as user_id,
        d.browser_type,
        date(cast(e.event_time as timestamp)) as date_active
    from events e
    join devices d on e.device_id = d.device_id
    where date (cast(e.event_time as timestamp)) = date('2023-01-02')
    and user_id is not null
    group by user_id, d.browser_type, date(cast(event_time as timestamp))

)

select
    coalesce(t.user_id, y.user_id) as user_id,
    coalesce(y.browser_type, t.browser_type) as browser_type,
    coalesce(y.device_activity_datelist, ARRAY[]::DATE[]) ||
        case when t.user_id is not null then ARRAY[t.date_active]
        else ARRAY[]::DATE[]
        end as device_activity_datelist,
    coalesce(t.date_active, y.date + interval '1 day') as date
from today t
full outer join yesterday y
on t.user_id = y.user_id and t.browser_type = y.browser_type
