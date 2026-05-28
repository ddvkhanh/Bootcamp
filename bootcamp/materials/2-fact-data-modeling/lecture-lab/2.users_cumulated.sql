 CREATE TABLE users_cumulated (
     user_id text,
     dates_active DATE[],
     date DATE,
     PRIMARY KEY (user_id, date)
 );


 with yesterday AS (
    SELECT * FROM users_cumulated
    WHERE date = DATE('202-01-01')
),
    today AS (
        select
            cast(user_id as text) as user_id,
            date(cast(event_time as timestamp)) as date_active
        from events
        where date(cast(event_time as timestamp)) = DATE('2023-01-02')
            and user_id is not null
            group by user_id, date(cast(event_time as timestamp))
    )
    select 
        coalesce(t.user_id, y.user_id) as user_id,
        coalesce(y.dates_active, ARRAY[]::DATE[]) || 
            case when t.user_id is not null then ARRAY[t.date_active] 
            else ARRAY[]::DATE[] 
            end 
        as dates_active,
        coalesce(t.date_active, y.date + interval '1 day') as date
    from today t 
    full outer join yesterday y 
    on t.user_id = y.user_id