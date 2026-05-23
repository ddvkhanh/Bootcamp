
with last_year as (
	select * from actors
	where year = 2006
),
this_year as (
	select * from actor_films
	where year = 2007
),
merged as (
	select
	    coalesce(ty.actor, ly.actor) as actor,
	    coalesce(ty.actorid, ly.actorid) as actorid,
	    2007 as year,
	    coalesce(ly.films, ARRAY[]::film_stats[]) ||
	        coalesce(
	            ARRAY_AGG(ROW(ty.film, ty.votes, ty.rating, ty.filmid)::film_stats order by ty.filmid)
                filter (where ty.filmid is not null)
                , ARRAY[]::film_stats[]    
	        ) as films,
	    case
	        when ty.actorid is not null then
	            (case when avg(ty.rating) > 8 then 'star'
	                when avg(ty.rating) > 6 then 'good'
	                when avg(ty.rating) > 4 then 'average'
	                else 'bad' end)::scoring_category
	        else ly.quality_class
	    end as quality_class,
	    ty.actorid is not null as is_active
    from this_year ty
    full outer join last_year ly
    on ty.actorid = ly.actorid
    GROUP BY
    ty.actor,
    ty.actorid,
    ly.actor,
    ly.actorid,
    ly.films,
    ly.quality_class
)
insert into actors(actor, actorid, films, quality_class, is_active, year)
select actor, actorid, films, quality_class, is_active, year 
from merged
on conflict (actorid, year) do nothing
