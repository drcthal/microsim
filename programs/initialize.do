clear all
program drop _all

set_dirs

frame create person
frame change person

use "$derived\acs_2018_clean.dta", clear
drop if met2013==0

gen perid = _n
rename serial hhid

recode race (1=1) (2=2) (3=3) (4/6 = 4) (7=6) (8/9=7), gen(raceeth)
replace raceeth = 5 if hispan!=0
label define raceeth_lbl 1 "White" 2 "Black" 3 "AIAN" 4 "Asian/PI" 5 "Hispanic" 6 "Other" 7 "Multiple", replace
label values raceeth raceeth_lbl

gen male = sex==1

keep perid hhid met2013 male age raceeth educ hhincome occ ind perwt

// combine none and unemployed
replace ind = 0 if ind==9920
replace occ = 0 if occ==9920
replace hhincome = . if hhincome<0 | hhincome==9999999

add_comorb, check_ev
create_inds

/* Assign people to industries now
	put them in a random order within met/ind, then fill out the workplaces 1 by 1
	
	figure out how to deal with kids - if not working, assign to grade based on age, then create schools?
	e.g. if we treat "grades" like industries we can use the same logic as create_inds
	issues are class sizes, and also the fact that there would be no teachers.
	
	could take the elem/secondary school industries and blow those up?
*/
