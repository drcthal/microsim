program define seed_infections
	syntax, [prob actualize]
	
	qui {
	    if !mi("`prob'") {
		    
			preserve
				gcollapse (sum) pop = perwt, by(statefip)
				tempfile pop
				save `pop'
				
				import delimited using "$raw\infections\daily.csv", delim(",") clear
				isid fips date 
				
				// Drop territories
				drop if inlist(fips, 60, 66, 69, 72, 78)
				
				rename fips statefip
				replace date = date(string(date,"%99.0f"),"YMD")
				format date %td
				// Data only really starts on Mar 1
				keep if inrange(date, td(29feb2020), td(6apr2020))
				
				keep statefip date positive
				
				// Rectangularize
				fillin statefip date
				replace positive = 0 if mi(positive)
				
				// convert to new cases, but keep from going negative (either due to filling in or reporting weirdness)
				bys statefip (date): gen new_cases = positive - positive[_n-1] if !mi(positive[_n-1])
				drop if date==td(29feb2020)
				assert !mi(new_cases)
				replace new_cases = 0 if new_cases<0
				
				drop _fillin positive
				
				merge m:1 statefip using `pop', assert(3) nogen
				
				// Need to do some adjustment for undercounting and delay between infected and positive test
				
				// Assume that testing happens around when symptomatic (average delay to symptoms is about 5.5)
				replace date = date - 6
				keep if inrange(date, td(1mar2020), td(31mar2020))
				
				// Assume undercounting by factor of 4 and 
				bys statefip (date): gen cuml_pr_inf_ = sum(4*new_cases/pop)
				drop new_cases pop
				
				reshape wide cuml_pr_inf_, i(statefip) j(date)
				
				tempfile pr_inf
				save `pr_inf'
			restore
			merge m:1 statefip using `pr_inf', assert(3) nogen
		}
		
		if !mi("`actualize'") {
		    gen day_infected = .
			
			gen inf_rand = runiform()
			
			forval d = `=td(1mar2020)'/`=td(31mar2020)' {
			    replace day_infected = `d' - td(1apr2020) if inf_rand <= cuml_pr_inf_`d' & mi(day_infected)
			}
			drop inf_rand cuml_pr_inf_*
		}
	}
end