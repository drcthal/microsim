clear all
program drop _all

set_dirs

frame create person
frame change person

use "$derived\acs_2018_clean.dta", clear
// No clue how to handle non-metro
drop if met2013==0
// Boston, Baltimore, Pittsburgh for now
keep if inlist(met2013, 14460, 12580, 38300)

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
define_disease_progression

// Placeholder
gen base_tau_w = 1/3 * (ind!=0 | (age>=5 & age<=18 & ind==0))
gen base_tau_c = 2/3 - base_tau_w
gen base_tau_h = 1 - base_tau_c - base_tau_w

// Average number of contacts if they spent 24 hours somewhere
gen N_w = 50
gen N_c = 50

gen tau_w = base_tau_w
gen tau_c = base_tau_c
gen tau_h = base_tau_h

// Seed infections
// Should be weighted towards more recent
gen day_infected = runiformint(-10,0) if runiform()<=0.01
gen infection_source = "i" if !mi(day_infected)
gen symptomatic = 0
gen infectious = 0
gen recovered = 0
update_disease, day(0)
update_taus, day(0)

local day = 0

count if !mi(day_infected) & !recovered
local active = r(N)
while `active' > 0  & `day' < 100 {
	local ++day
	di `day'
	// For each day, we take people's current status, have them interact, then at the end of the day there are new infections, we progress disease, and we change taus
	draw_contacts, day(`day')
	update_disease, day(`day')
	update_taus, day(`day')
	
	count if !mi(day_infected) & !recovered
	local active = r(N)
}

// Postprocessing - we can recreate daily infections by looking at day_infected and the days_to vars
frame copy person postprocess, replace
frame postprocess {
	local day 100
	keep met2013 perid perwt day_infected infection_source days_to_symptomatic days_to_infectious days_to_recovered
	expand `=`day'+1'
	bys perid: gen day = _n-1
	gen infected = day>=day_infected & day < (day_infected + days_to_recovered)
	gen symptomatic = day >= (day_infected + days_to_symptomatic) & day < (day_infected + days_to_recovered)
	gen infectious = day >= (day_infected + days_to_infectious) & day < (day_infected + days_to_recovered)
	gen recovered = day >= (day_infected + days_to_recovered)

	gcollapse (rawsum) N=perwt (sum) infected symptomatic infectious recovered [aw=perwt], by(met2013 day)
	foreach x in infected symptomatic infectious recovered {
		gen `x'_rate = `x' / N
		bys met2013 (day): gen cuml_`x' = sum(`x')
		gen cuml_`x'_rate = cuml_`x' / N
	}

	local lines
	foreach x in infected symptomatic infectious recovered {
		local lines `lines' (line `x'_rate day)
	}

	tw `lines', by(met2013) scheme(cb) name(daily, replace)
}

