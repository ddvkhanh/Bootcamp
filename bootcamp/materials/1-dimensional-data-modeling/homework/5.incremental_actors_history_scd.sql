CREATE TYPE scd_actor_type AS (
    actor TEXT,          
    actorid TEXT,         
    quality_class scoring_category,
    is_active BOOLEAN,
    start_date INTEGER,
    end_date INTEGER
);


with last_year_scd as (
    select *
    from actors_history_scd ahs
    where current_year = 2006 and end_date = 2006
),
historical_scd as (
    select
        actor,
        actorid,
        quality_class,
        is_active,
        start_date,
        end_date
    from actors_history_scd ahs
    where current_year = 2006 and end_date < 2006
),
current_year_actors as (
    select
        actor,
        actorid,
        quality_class,
        is_active,
        year
    from actors
    where year = 2007
),
unchanged_records as (
    select
        cya.actor,
        cya.actorid,
        cya.quality_class,
        cya.is_active,
        lys.start_date,
        cya.year AS end_date
    from current_year_actors cya
    left join last_year_scd lys on cya.actorid = lys.actorid
    where
        cya.quality_class = lys.quality_class and
        cya.is_active = lys.is_active
),
changed_records as (
    select
        cya.actor,
        cya.actorid,
        UNNEST(ARRAY[
            ROW(
                lys.actor,
                lys.actorid,
                lys.quality_class,
                lys.is_active,
                lys.start_date,
                lys.end_date
            )::scd_actor_type,
            ROW(
                cya.actor,
                cya.actorid,
                cya.quality_class,
                cya.is_active,
                cya.year,
                cya.year
            )::scd_actor_type
        ]) as records
        from current_year_actors cya
        left join last_year_scd lys on cya.actorid = lys.actorid
        where
            (cya.quality_class <> lys.quality_class) or
            (cya.is_active <> lys.is_active)
),
unnested_change_records as (
    select
        (records::scd_actor_type).actor,
        (records::scd_actor_type).actorid,
        (records::scd_actor_type).quality_class,
        (records::scd_actor_type).is_active,
        (records::scd_actor_type).start_date,
        (records::scd_actor_type).end_date
    from changed_records cr
),
new_records as (
    select
        cya.actor,
        cya.actorid,
        cya.quality_class,
        cya.is_active,
        cya.year as start_date,
        cya.year as end_date
    from current_year_actors cya
    left join last_year_scd lys on cya.actorid = lys.actorid
    where lys.actorid is null
),
inactive_records as (
    select
        lys.actor,
        lys.actorid,
        lys.quality_class,
        lys.is_active,
        lys.start_date,
        2007 as end_date
    from last_year_scd lys
    left join current_year_actors cya on lys.actorid = cya.actorid
    where cya.actorid is null
)
joined as (
    select * from historical_scd
    union all
    select * from unchanged_records
    union all
    select * from unnested_change_records
    union all
    select * from new_records
    union all
    select * from inactive_records
)
insert into actors_history_scd(actor, actorid, quality_class, is_active, start_date, end_date, current_year)
select 
    actor, 
    actorid, 
    quality_class, 
    is_active, 
    start_date, 
    end_date, 
    2007
from joined
on conflict (actorid, start_date) do nothing;