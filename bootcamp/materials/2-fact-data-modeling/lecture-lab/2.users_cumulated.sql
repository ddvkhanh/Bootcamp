 CREATE TABLE users_cumulated (
     user_id BIGINT,
     dates_active DATE[],
     date DATE,
     PRIMARY KEY (user_id, date)
 );

 with yesterday AS (
    SELECT * FROM users_cumulated
    WHERE date = DATE('2022-12-31')
),
    today AS (
        select
            user_id,
            date(:cast(event_time as timestamp)) as date_active
        from events
        where date(:cast(event_time as timestamp)) = DATE(:'2023-01-01')
            and user_id is not null
            group by user_id, date(:cast(event_time as timestamp))
    )