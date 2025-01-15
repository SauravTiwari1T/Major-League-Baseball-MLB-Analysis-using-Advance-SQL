--              ------------------------------- School level------------------------------------------------
use project;
select * from schools
order by yearID ;

-- ----------------------------------------------------------------------------------------------------

--  In each decade, how many schools were there that produced MLB players?
select 			floor(yearID /10)*10 as Decade , count( distinct( schoolID)) as Number_of_school
 from  			schools
group by 		Decade
order by 		Number_of_school desc , Decade desc
;

-- ----------------------------------------------------------------------------------------------------
-- What are the names of the top 5 schools that produced the most players
with top_5 as 
(
select  		schoolId , count(distinct playerID) as number_of_player
from			schools
group by 		schoolId
order by 		number_of_player desc
limit 5
)

select 			sd.name_full , t5.number_of_player
from 			top_5 t5 
join 			school_details sd 
on 				t5.schoolId = sd.schoolID
;

-- ----------------------------------------------------------------------------------------------------
-- For each decade, what were the names of the top 3 schools that produced the most players?
with  no_of_pl as 
(
select 			floor(nop.yearID /10)*10 decade ,nop.schoolId , sd.name_full  ,count(distinct nop.playerID) as number_of_player
from 			schools nop
join			school_details sd 
on				nop.schoolId = sd.schoolId
group by 	    decade ,schoolId

),
ranking_of_collages as 
(
select 			decade , number_of_player , name_full ,
				row_number() over ( partition by decade  order by number_of_player desc) as ranking
from			no_of_pl nop

)
select 			decade , number_of_player ,name_full, ranking
from			ranking_of_collages
where 			ranking <= 3
order by 		  decade  desc , ranking  
;

-- ----------------------------------------------------------------------------------------------------
--    ----------------------------------Salary Analysis---------------------------------------------
-- Return the top 20% of teams in terms of average annual spending
with avg_Salary as 
(
select       	yearID , teamID  , sum(salary) as total_salary 
from 			salaries
group by 		yearID , teamID
order by 	    total_salary desc , yearID desc
),
top20 as
(
select 		     teamID , round(avg(total_salary)/1000000,1) as average_Salary_in_millions , ntile(5) over ( partition by teamID order by round(avg(total_salary)/1000000,1)  desc ) top20_percent
from 			avg_Salary 
group by 		  teamID
)
select 			teamID , average_Salary_in_millions
from			top20
where 		    top20_percent = 1
order by 	    average_Salary_in_millions desc
;

--  For each team, show the cumulative sum of spending over the years
with total_salry as 
(
select 			 yearID , teamID , round(sum(salary)/1000000 , 1) as Total_Salary_million
from 			salaries
group by 		teamID , yearID
),
year_range as
(
select 			teamID , yearID ,  sum(Total_Salary_million) over( partition by teamID order by  yearID) as Cumulative_Salary_Million 
from			total_salry
), 
ranking as 
(
select 			* , row_number () over ( partition by teamID order by Cumulative_Salary_Million ) as ranking 
from 			year_range 
where 			Cumulative_Salary_Million > 1000
)
select 			teamID , yearID , Cumulative_Salary_Million 
from			ranking
where 			ranking = 1
;

-- --------------------------------  Player Career Analysis -------------------------------
-- For each player, calculate their age at their first (debut) game,
--  their last game, and their career length (all in years). 
-- Sort from longest career to shortest career.
select 				concat( nameFirst, ' ' , nameLast  ) as Name ,
					Year(debut) - birthYear Started_Playing_At,
					Year(finalGame) - birthYear  as  Retierd_At ,
					year(finalGame)- year(debut) as Carrer_lenght
from				players
order by 			Carrer_lenght desc
;




--  What team did each player play on for their starting and ending years?
with player_deails as
(
select 				p.nameGiven ,s.playerID , p.birthYear , p.nameFirst , p.nameLast , 
					year(p.debut) as debu_year , year(p.finalGame) as retiered_year ,s.teamID as team ,
                    s.yearID as year_when_played_at_team  ,year(p.finalGame)     -  year(p.debut)  as lenght
from				players p
join 				salaries s
on 					p.playerID = s.playerID
),
first_team as 
(
select 				nameGiven,playerID,concat(nameFirst , ' ' , nameLast) as full_name , team as first_team ,  year_when_played_at_team as debu_year , lenght
from				player_deails
where 				debu_year = year_when_played_at_team
),
last_team  as
(
select 				nameGiven ,playerID ,concat(nameFirst , ' ' , nameLast) as full_name , team as last_team ,  retiered_year  , lenght
from				player_deails
where 				retiered_year = year_when_played_at_team
)

select 				ft.nameGiven as given_name , ft.full_name , ft.first_team , ft.debu_year ,lt.last_team , lt.retiered_year  , lt.lenght
from				last_team lt
join 			    first_team ft
on 					lt.playerID = ft.playerID
					AND ft.first_team = lt.last_team 
                    AND lt.lenght >= 10
;

select 				*
from				players p
join 				salaries s
on 					p.playerID = s.playerID
;

--  Player Comparison Analysis

-- Which players have the same birthday?
with name_birthday as 
(
select 			cast(concat( birthYear ,'-',birthMonth , '-',birthDay) as date) as birthday , nameGiven
 from  			players
 )
 select 		birthday ,  group_concat( nameGiven  separator  ' ; ') as players , count(nameGiven) as number_of_players_with_same_birthday
 from			name_birthday 
 where 	        birthday is not null  
 group by 		birthday
 having 		number_of_players_with_same_birthday >= 2
 ; 
 
 -- Create a summary table that shows for each team, 
 -- what percent of players bat right, left and both.
 with combing_table as
 (
 select 		p.playerID ,p.nameGiven ,p.bats,s.teamID
 from 			players p
 join 			salaries s
 on 			p.playerID = s.playerID
 ),
 total_count as 
 (
 select 		teamID , count(  playerID ) as Total_Number_of_player ,
				count(case when bats = 'R' then  playerID  end) as Righ_B , 
				count(case when bats = 'L' then playerID   end) as Left_B ,
                count(case when bats = 'B' then playerID   end)  as Both_B 
				
 from			combing_table
 group by 		teamID 
 )
 select 		teamID , concat(round (( righ_b / Total_Number_of_player) * 100 , 2 ) , '%')as Righ_B ,
						concat(round (( Left_B / Total_Number_of_player) * 100 , 2 ) , '%')as Left_B ,
                         concat(round (( Both_B / Total_Number_of_player) * 100 , 2 ) , '%')as Both_B 
 from 			total_count	
 ;
 
 -- How have average height and weight at debut game changed over the years, and 
 -- what's the decade-over-decade difference?
with player_details as 
(
select 			floor(year(debut) /10)*10 as decade , avg(height) avg_height, avg(weight)  avg_weight
from			players
group by 		decade
)
select 			decade , round(avg_height,1) avg_height,
				coalesce((round((avg_height - lag(avg_height) over( order by decade) ),1)),'--')as height_diff,
				round(avg_weight,1)avg_weight,
               coalesce( (round(avg_weight - lag(avg_weight) over ( order by decade ),1)),'--')  as weight_diff
from 			player_details
where 			decade is not null
;