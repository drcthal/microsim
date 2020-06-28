program define evaluate_sim
	syntax [if], day(int) [level(string) daily_inf source compare_r0 smooth debug]

	marksample touse
	
	if mi("`level'") local level statefip
	if !inlist("`level'", "statefip","met2013") {
	    di as error "Can only evaluate at MSA or state level
		exit 198"
	}
	local lttl = cond("`level'"=="statefip", "State", "MSA")

	local vol = cond(!mi("`debug'"),"noi","qui")
	`vol' {
		if !mi("`daily_inf'") {
		    tempname dinf
			frame put `touse' `level' perwt day_infected, into(`dinf')
			frame `dinf' {
			    keep if `touse'
				
				bys `level': gegen N = total(perwt)
				drop if mi(day_infected) | day_infected <=0
				gcollapse (sum) perwt, by(`level' day_infected N)
				gen inf_per_1000 = 1000*perwt/N

				replace day_infected = day_infected + td(31mar2020)
				format day_infected %td
				tw bar inf_per_1000 day_infected, ///
					by(`level', title("Daily New Infections by `lttl'")) ///
					xtitle("Day") ///
					ytitle("Infections per 1,000") ///
					scheme(cb)
			}
		}	


		if !mi("`source'") {
		    tempname src
			frame put `touse' `level' perid perwt day_infected infection_source, into(`src')
			frame `src' {
			    keep if `touse'
				keep if day_infected > 0 & !mi(day_infected)

				gen source = 1 if infection_source == "w"
				replace source = 2 if infection_source == "c"
				replace source = 3 if infection_source == "h"
				replace source = 4 if length(infection_source) > 1

				gcollapse (sum) perwt, by(`level' source day_infected)

				fillin `level' source day_infected
				replace perwt = 0 if mi(perwt)

				bys `level' day_infected: egen tot = total(perwt)

				gen pct = 100*perwt/tot
				gen bottom = 0 if source==1
				bys `level' day_infected (source): replace bottom = bottom[_n-1] + pct[_n-1] if _n>1
				gen top = bottom + pct

				replace day_infected = day_infected + td(31mar2020)
				format day_infected %td

				local level statefip
				tw (rbar bottom top day_infected if source==1) ///
					(rbar bottom top day_infected if source==2) ///
					(rbar bottom top day_infected if source==3) ///
					(rbar bottom top day_infected if source==4) ///
					, ///
					by(`level', title("Source of New Infections by Day and `lttl'")) ///
					xtitle("Day") ///
					ytitle("Share of New Infections") ///
					legend(order(1 "Work" 2 "Community" 3 "Home" 4 "Multiple")) ///
					scheme(cb)
			}
		}

		if !mi("`compare_r0'") {
		    tempname r0
			frame put `touse' `level' perid perwt day_infected days_to_symptomatic days_to_infectious days_to_recovered, into(`r0') 
			frame `r0' {
				keep if `touse'
				keep if !mi(day_infected)

				gcollapse (sum) perwt, by(`level' day_infected days_to_symptomatic days_to_infectious days_to_recovered)

				gen id = _n
				expand `=`day'+1'
				bys id: gen day = _n-1
				gen infectious = day >= (day_infected + days_to_infectious) & day < (day_infected + days_to_recovered)
				gen newly_infected = day==day_infected
				gen days_infectious = days_to_recovered - days_to_infectious

				gcollapse (sum) infectious newly_infected (mean) days_infectious [fw=perwt], by(`level' day)

				gen sim_r0 = days_infectious * newly_infected / infectious
				
				bys `level' (day): gen sim_r0_7avg = (sim_r0 + sim_r0[_n-1] + sim_r0[_n-2] + sim_r0[_n-3] + sim_r0[_n-4] + sim_r0[_n-5] + sim_r0[_n-6]) / 7
				
				merge 1:1 `level' day using "$derived\rt\actual_r0s.dta", keep(1 3) nogen
				keep if day > 0
				
				replace day = day + td(31mar2020)
				format day %td
				
				if !mi("`smooth'") {
				    local yv sim_r0_7avg
					local yvl "Simulation R0, 7-day avg"
				}
				else {
				    local yv sim_r0
					local yvl "Simulation R0, daily"
				}
				tw (rarea r0_lower_90 r0_upper_90 day, color(black%25)) ///
					(rarea r0_lower_50 r0_upper_50 day, color(black%50)) ///
					(line r0_actual day, color(black) lpattern(longdash)) ///
					(line `yv' day, color(cb_orange)) ///
					, ///
					by(`level', title("Simulated vs actual R0 by Day and `lttl'")) ///
					xtitle("Day") ///
					ytitle("R0") ///
					legend(order(4 "`yvl'" 3 "Real R0" 2 "50% CI" 1 "90% CI")) ///
					scheme(cb)

			}
		}
	}
end