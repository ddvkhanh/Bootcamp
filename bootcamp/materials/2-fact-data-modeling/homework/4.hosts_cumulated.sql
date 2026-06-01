CREATE TABLE hosts_cumulated (
    host_id text,
    host_activity_datelist  DATE[],
    date DATE,
    PRIMARY KEY (host_id, date)
);

DO $$
DECLARE
    loop_date DATE := DATE('2023-01-01');
BEGIN
    WHILE loop_date <= DATE('2023-01-31') LOOP
        RAISE NOTICE 'Processing date: %', loop_date;

        INSERT INTO hosts_cumulated
        WITH yesterday AS (
            SELECT * 
            FROM hosts_cumulated
            WHERE date = loop_date - INTERVAL '1 day'
        ),
        today AS (
            SELECT
                cast(host as text) as host_id,
                date(cast(event_time as timestamp)) as date_active
            FROM events
            WHERE date(cast(event_time as timestamp)) = loop_date
            AND host IS NOT NULL
            GROUP BY host, date(cast(event_time as timestamp))
        )
        SELECT
            coalesce(t.host_id, y.host_id) as host_id,
            coalesce(y.host_activity_datelist, ARRAY[]::DATE[]) || 
                case when t.host_id is not null then ARRAY[t.date_active] 
                else ARRAY[]::DATE[] 
                end as host_activity_datelist,
            coalesce(t.date_active, y.date + INTERVAL '1 day') as date
        FROM today t
        FULL OUTER JOIN yesterday y
        ON t.host_id = y.host_id;

        loop_date := loop_date + INTERVAL '1 day';
    END LOOP;
END $$;