--populate vertices table with data from games, players, and teams tables
insert into vertices
select 
	game_id as identifier,
	'game'::vertex_type as type,
	json_build_object(
		'pts_home', pts_home,
		'pts_away', pts_away,
		'winning_team', case when home_team_wins =1 then home_team_id else visitor_team_id end
	) as properties
from games

insert into vertices
with players_agg as(
	select
		player_id as identifier,
		max(player_name) as player_name,
		count(1) as number_of_games,
		sum(pts) as total_points,
		ARRAY_AGG(distinct team_id) as teams
	from game_details
	group by player_id
)
select identifier, 'player'::vertex_type,
	json_build_object(
		'player_name', player_name,
		'number_of_games', number_of_games,
		'total_points', total_points,
		'teams', teams
	)
from players_agg


insert into vertices
with teams_deduped as
	(select *, row_number() over (partition by team_id) as rn
	from teams)

select 
	team_id as identifier,
	'team'::vertex_type as type,
	json_build_object(
		'abbreviation', abbreviation,
		'nickname', nickname,
		'city', city,
		'arena', arena,
		'year_founded', yearfounded
	)
from teams_deduped
where rn =1


--queries to verify data was inserted correctly
select * from vertices where type = 'team'

select
	v.properties ->> 'player_name', --cast to text since properties is a jsonb column
	MAX(cast(e.properties ->> 'pts' as INTEGER))
from vertices v
join edges e
	on e.subject_identifier = v.identifier
		and e.subject_type = v.type
group by 1
order by 2 desc