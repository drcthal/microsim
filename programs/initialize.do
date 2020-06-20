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

keep perid hhid met2013 male age raceeth educ hhincome occ ind perwt uhrswork

// combine none and unemployed
replace ind = 0 if ind==9920
replace occ = 0 if occ==9920
replace hhincome = . if hhincome<0 | hhincome==9999999

add_comorb, check_ev
create_inds
define_disease_progression
link_frames

// Placeholder
gen base_tau_w = 0
replace base_tau_w = uhrswork / (7*24) if occ!=0
replace base_tau_w = 40 / (7*24) if age>=5 & age<=18 & ind==0
drop uhrswork

// assume people spend 1/3 sleeping plus half of the remaining time at home
assert base_tau_w < 2/3
gen base_tau_c = 0.5 * (2/3 - base_tau_w)
gen base_tau_h = 1 - base_tau_c - base_tau_w

// Average number of contacts if they spent 24 hours somewhere
merge m:1 occ using "$derived\polymod\ACS_workcounts.dta", keep(1 3) nogen keepusing(occ cnt_work_hat sh_infrequent_hat)
assert mi(cnt_work_hat) == (occ==0)

// Split contacts at work into contacts with coworkers (assumed to be the frequent contacts)
// and the work contacts with the community
gen N_w_w = cnt_work_hat * (1-sh_infrequent_hat)
replace N_w_w = 0 if occ==0
gen N_w_c = cnt_work_hat * sh_infrequent_hat
replace N_w_c = 0 if occ==0
drop cnt_work_hat sh_infrequent_hat

// Assume not working and older = retired; 
// not working and younger = student,
// not working and in between = 50/50 unemployed vs at home
gen part_occupation = 1 if occ!=0
replace part_occupation = 2 if occ==0 & age>=60
replace part_occupation = 5 if occ==0 & age<=25
replace part_occupation = 3 if occ==0 & inrange(age,26,59) & runiform()<=0.5
replace part_occupation = 4 if occ==0 & inrange(age,26,59) & mi(part_occupation)
assert !mi(part_occupation)

merge m:1 part_occupation using "$derived\polymod\average_community_contact.dta", assert(2 3) keep(3) nogen
// This is "typical" so should be scaled by tau_c relative to base_tau_c
rename cnt_community N_c
drop part_occupation
 
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
gen dead = 0
update_disease, day(0)
update_taus, day(0)

local day = 0

count if !mi(day_infected) & !recovered
local active = r(N)
while `active' > 0  & `day' < 250 {
	local ++day
	di `day'
	// For each day, we take people's current status, have them interact, then at the end of the day there are new infections, we progress disease, and we change taus
	draw_contacts, day(`day')
	update_disease, day(`day')
	update_taus, day(`day')
	
	count if !mi(day_infected) & !recovered
	local active = r(N)
}

di `day'

// Postprocessing - we can recreate daily infections by looking at day_infected and the days_to vars
frame copy person postprocess, replace
frame postprocess {
	keep met2013 perid perwt day_infected infection_source days_to_symptomatic days_to_infectious days_to_recovered
	gcollapse (sum) perwt, by(met2013 day_infected infection_source days_to_symptomatic days_to_infectious days_to_recovered)
	
	gen id = _n
	expand `=`day'+1'
	bys id: gen day = _n-1
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

//daily new infections
frame copy person postprocess2, replace
frame postprocess2 {
	bys met2013: gegen N = total(perwt)
	drop if mi(day_infected)
	gcollapse (sum) perwt, by(met2013 day_infected N)
	
	*tw bar perwt day_infected, by(met2013)
	
	gen inf_per_1000 = 1000*perwt/N
	tw bar inf_per_1000 day_infected, by(met2013)
}

// Calculate effective R0 to compare to real world values
// Not sure what the right way is - we don't actually track individuals, but that's also not available in real-world population studies
// We know how many people are infectious in a given day and how many new people are infected. We also know how long people are infectious for. So combine those?
frame copy person r0, replace
local day 250
frame r0 {
    keep met2013 perid perwt day_infected days_to_symptomatic days_to_infectious days_to_recovered
	keep if !mi(day_infected)
	
	gcollapse (sum) perwt, by(met2013 day_infected days_to_symptomatic days_to_infectious days_to_recovered)
	
	gen id = _n
	expand `=`day'+1'
	bys id: gen day = _n-1
	gen infectious = day >= (day_infected + days_to_infectious) & day < (day_infected + days_to_recovered)
	gen newly_infected = day==day_infected
	gen days_infectious = days_to_recovered - days_to_infectious
	
	gcollapse (sum) infectious newly_infected (mean) days_infectious [fw=perwt], by(met2013 day)
	
	gen r0 = days_infectious * newly_infected / infectious
	bys met2013: summ r0
	tw line r0 day, by(met2013) scheme(cb) name(daily, replace)
	
}