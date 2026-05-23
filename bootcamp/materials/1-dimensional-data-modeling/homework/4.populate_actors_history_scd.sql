with streaked as (
    select
        actor,
        actorid,
        year,
        quality_class,
        is_active,
        LAG(quality_class, 1) OVER (PARTITION BY actorid ORDER BY year) IS DISTINCT FROM quality_class AS did_change_quality,   
        LAG(is_active, 1) OVER (PARTITION BY actorid ORDER BY year) IS DISTINCT FROM is_active AS did_change_active
    from actors
),
grouped as (
    select
        actor,
        actorid,
        year,
        quality_class,
        is_active,
        SUM(CASE WHEN did_change_quality OR did_change_active THEN 1 ELSE 0 END) OVER (PARTITION BY actorid ORDER BY year) AS group_id
    from streaked
),
collapsed as (
    select
        min(actor) as actor,,
        actorid,
        group_id,
        quality_class,
        is_active,
        MIN(year) AS start_date,
        MAX(year) AS end_date
    from grouped
    group by 1,2,3,4,5
),
cy as (select max(year) as y from actors)

insert into actors_history_scd(actor, actorid, quality_class, is_active, start_date, end_date, current_year)
select c.actor, c.actorid, c.quality_class, c.is_active, c.start_date, c.end_date, cy.y
from collapsed c
cross join cy;
