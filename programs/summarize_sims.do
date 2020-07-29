set_dirs

use "$output\simulations\r0s_1.dta", clear
gen iter = 1
forval i = 2/10 {
	append using "$output\simulations\r0s_`i'.dta"
	replace iter = `i' if mi(iter)
}

sort iter day

local lines
forval i = 1/10 {
	local lines `lines' (line sim_r0_7avg day if iter==`i', color(cb_orange))
}

tw (rarea r0_lower_80 r0_upper_80 day if iter==1, color(black%50)) ///
	(line r0_actual day if iter==1, color(black) lpattern(longdash)) ///
	`lines' ///
	, ///
	title("Simulated vs actual R0 by Day") ///
	xtitle("Day") ///
	ytitle("R0") ///
	legend(order(3 "Simulation R0, 7-day avg" 2 "Real R0" 1 "80% CI")) ///
	scheme(cb)

graph export "$output\figure1.png", replace
summ sim_r0
table iter, c(mean sim_r0)

use "$output\simulation_result_3.dta", clear
tab infection_source if infection_source!="i"

di (1 - exp(ln(.85)/7))
di 2.25*(1 - exp(ln(.85)/7))
di 0.9*(1 - exp(ln(.85)/7))