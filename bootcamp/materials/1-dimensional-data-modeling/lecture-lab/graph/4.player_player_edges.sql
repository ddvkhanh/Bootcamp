INSERT INTO edges

WITH deduped AS (
    SELECT *, row_number() over (PARTITION BY player_id, game_id) AS row_num
    FROM game_details
),
filtered AS (
    SELECT * FROM deduped
    WHERE row_num = 1
),
aggregated AS (
    SELECT
    f1.player_id as subject_player_id,
    f2.player_id as object_player_id,
    CASE WHEN f1.team_abbreviation =         f2.team_abbreviation
        THEN 'shares_team'::edge_type
    ELSE 'plays_against'::edge_type
    END as edge_type,
    MAX(f1.player_name) as subject_player_name,
    MAX(f2.player_name) as object_player_name,
    COUNT(1) AS num_games,
    SUM(f1.pts) AS subject_points,
    SUM(f2.pts) as object_points
FROM filtered f1
    JOIN filtered f2
    ON f1.game_id = f2.game_id
    AND f1.player_name <> f2.player_name
WHERE f1.player_id > f2.player_id
GROUP BY
    f1.player_id,
    f2.player_id,
    CASE WHEN f1.team_abbreviation =         f2.team_abbreviation
        THEN  'shares_team'::edge_type
    ELSE 'plays_against'::edge_type
    END
)
SELECT 
    subject_player_id as subject_identifier,
    'player'::vertex_type as subject_type,
    object_player_id as object_identifier,
    'player'::vertex_type as object_type,
    edge_type as edge_type,
    json_build_object(
        'num_games', num_games,
        'subject_points', subject_points,
        'object_points', object_points
    ) as edge_properties
from aggregated


select
    v.properties ->> 'player_name' as player_name,
    e.object_identifier,
    cast(v.properties ->> 'number_of_games' as real) /
        case when cast(v.properties ->> 'total_points' as real) = 0 then 1 else cast(v.properties ->> 'total_points' as real) end as points_per_game,
    e.properties ->> 'num_games' as num_games,
    e.properties ->> 'subject_points' as subject_points
from vertices v
join edges e
on v.identifier = e.subject_identifier
	and v.type = e.subject_type
where e.object_type = 'player'::vertex_type