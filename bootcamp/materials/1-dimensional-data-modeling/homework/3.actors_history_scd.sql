-- for scd type 2

create table actors_history_scd (
    actor text,
    actorid text,
    quality_class scoring_category,
    is_active boolean,
    start_date integer,
    end_date integer,
    current_year integer,
    primary key (actorid, start_date)
);


