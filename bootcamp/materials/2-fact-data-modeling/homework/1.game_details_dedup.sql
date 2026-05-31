with deduped as (
    select
        g.game_date_est,
		g.season,
		g.home_team_id,
		gd.*,
        row_number() over (partition by game_id, team_id, player_id order by game_date_est) as row_num
    from 
        game_details gd
        join games g
        on gd.game_id = g.game_id
    where g.game_date_est = '2016-10-04'
)
    select 
        game_date_est as dim_game_date,
        season as dim_season,
        team_id as dim_team_id,
        player_id as dim_player_id,
        player_name as dim_player_name,
        start_position as dim_start_position,
        coalesce(position('DNP' in comment),0) > 0 as dim_did_not_play,
        coalesce(position('DND' in comment),0) > 0 as dim_did_not_dress,
        coalesce(position('NWT' in comment),0) > 0 as dim_not_with_team,
        team_id = home_team_id as dim_is_playing_at_home,
	CAST(SPLIT_PART(min,':',1) as real) + 
		CAST(SPLIT_PART(min,':',2) as real)/60 as m_minutes,
	fgm as m_fgm,
	fga as m_fga,
	fg3m as m_fg3m,
	fg3a as m_fg3a,
	ftm as m_ftm,
	fta as m_fta,
	oreb as m_oreb,
	dreb as m_dreb,
	reb as m_reb,
	ast as m_ast,
	stl as m_stl,
	blk as m_blk,
	"TO" as m_turnovers,
	pf as m_pf,
	pts as m_pts,
	plus_minus as m_plus_minus
from deduped
where row_num = 1
        