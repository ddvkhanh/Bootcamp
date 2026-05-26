with deduped as (
	select
		g.game_date_est,
		g.season,
		g.home_team_id,
		gd.*,
		row_number() over (partition by gd.game_id, team_id, player_id order by game_date_est) as row_num
	from game_details gd
	join games g
	on gd.game_id = g.game_id
)
select 
	game_date_est,
	season,
	team_id,
	team_id = home_team_id as dim_is_playing_at_home,
	player_id,
	player_name,
	start_position,
	comment,
	min,
	fgm,
	fga,
	fg3a,
	fta,
	oreb,
	dreb,
	reb,
	ast,
	blk,
	"TO" as turnovers
from deduped
where row_num = 1