clear all
program drop _all

set_dirs

frame create person
frame change person

use "$derived\simulation_afile.dta", clear

// Boston, Baltimore, Pittsburgh for now
*keep if inlist(met2013, 14460, 12580, 38300)

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
while `active' > 0  & `day' < 61 {
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

evaluate_sim, day(`day') daily_inf
graph export "$output\simulations\daily_inf.emf", replace
evaluate_sim, day(`day') source
graph export "$output\simulations\source.emf", replace
evaluate_sim, day(`day') compare_r0 smooth
graph export "$output\simulations\compare_r0.emf", replace

local big inlist(statefip, 6, 9, 17, 22, 25, 34, 36, 53)
evaluate_sim if `big', day(`day') daily_inf
graph export "$output\simulations\daily_inf_big.emf", replace
evaluate_sim if `big', day(`day') source
graph export "$output\simulations\source_big.emf", replace
evaluate_sim if `big', day(`day') compare_r0 smooth
graph export "$output\simulations\compare_r0_big.emf", replace

