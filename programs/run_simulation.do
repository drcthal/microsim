clear all
program drop _all

set_dirs

frame create person
frame change person

use "$derived\simulation_afile.dta", clear

// Boston, Baltimore, Pittsburgh for now
keep if inlist(met2013, 14460, 12580, 38300)

add_comorb, actualize
identify_essential, actualize
add_taus, actualize
create_inds
define_disease_progression
link_frames

// Seed infections
seed_infections, actualize
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
while `active' > 0  & `day' < 60 {
	local ++day
	di `day'
	// For each day, we take people's current status, have them interact, then at the end of the day there are new infections, we progress disease, and we change taus
	draw_contacts, day(`day') h_spread(0.05) c_spread(0.03) w_spread(0.03)
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