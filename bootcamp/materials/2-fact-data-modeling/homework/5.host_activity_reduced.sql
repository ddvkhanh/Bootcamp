with daily_aggregate as (
    select
        host as host_id,
        date(event_time) as date,
        count(1) as num_activity_hits,
        count(distinct user_id) as num_unique_visitors
    from events
    WHERE DATE(event_time) = DATE('2023-01-02')
    and host IS NOT NULL
    group by host, date(event_time)
),
yesterday_array as (
    select *
    from host_activity_reduced
    where month_start = date('2023-01-01')
),
combined as (
select
    coalesce(da.host_id, ya.host_id) as host_id,
    coalesce(ya.month_start, date_trunc('month', da.date)) as month_start,
    case when
        ya.hit_array is not null then
            ya.hit_array || array[coalesce(da.num_activity_hits, 0)]
        when ya.hit_array is null then
                ARRAY_FILL(0, ARRAY[COALESCE(da.date - DATE(DATE_TRUNC('month', da.date)), 0)])
                || array[coalesce(da.num_activity_hits, 0)]
    end as hit_array,

    case when
        ya.unique_visitors is not null then
            ya.unique_visitors || array[coalesce(da.num_unique_visitors,0)]
        when ya.unique_visitors is null then
                ARRAY_FILL(0, ARRAY[COALESCE(da.date - DATE(DATE_TRUNC('month', da.date)), 0)])
                || array[coalesce(da.num_unique_visitors, 0)]
    end as unique_visitors
from daily_aggregate da
full outer join yesterday_array ya
on da.host_id = ya.host_id
)
select * from combined