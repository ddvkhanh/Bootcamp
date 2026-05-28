WITH with_previous AS (
    SELECT player_name,
           current_season,
           scoring_class,
           is_active,
           LAG(scoring_class, 1) OVER
               (PARTITION BY player_name ORDER BY current_season) <> scoring_class as previous_scoring_class,
            LAG(is_active, 1) OVER
               (PARTITION BY player_name ORDER BY current_season) <> is_active as previous_is_active
    FROM players
), with_indicators as (
    select *,
        case
            when scoring_class <> previous_scoring_class then 1
            when is_active <> previous_is_active then 1
            else 0
        end as change_indicator
    from with_previous
), with_streaks AS (
        SELECT *,
            SUM(change_indicator) OVER (PARTITION BY player_name ORDER BY current_season) as streak_identifier
        FROM with_indicators
), aggregated AS (
    SELECT
    player_name,
    streak_identifier,
    scoring_class,
    is_active,
    MIN(current_season) AS start_date,
    MAX(current_season) AS end_date
    FROM with_streaks
    GROUP BY 1,2,3,4
)
insert into players_scd(player_name, scoring_class, is_active, start_season, end_season, current_season)
SELECT player_name, scoring_class, is_active, start_date, end_date, 2021
FROM aggregated