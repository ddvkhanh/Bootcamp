create type film_stats as (
    film text,
	votes integer,
	rating real,
	filmid text 
);

create type scoring_category as enum (
	'star', 'good', 'average', 'bad'
);

create table actors (
	actor text,
	actorid text,
	films film_stats[],
	quality_class scoring_category,
	is_active boolean,
	year integer,
	primary key (actorid, year)
);
	