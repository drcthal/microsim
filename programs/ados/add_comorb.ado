program define add_comorb
	syntax , [check_ev prob actualize]
	qui {
		if !mi("`prob'") {
			gen income_group = inrange(hhincome,0,34999) + 2*inrange(hhincome,35000,74999) + 3*(!mi(hhincome) & hhincome>=75000) + 4*mi(hhincome)
			gen geography = 1 if met2013!=0
			replace geography = 2 if met2013==0
			gen age_group = inrange(age,0,17) + 2*inrange(age,18,49) + 3*inrange(age,50,59) + 4*(age>=60 & !mi(age))
			
			merge m:1 male income_group geography age_group using "$derived\brfss\brfss_risks.dta", assert(2 3) keep(3) nogen
			
			// Make sure 
			if !mi("`check_ev'") {
				rename met2013 locationid
				// BRFSS uses 2003 metro/micro data, so things don't line up
				merge m:1 locationid using "$derived\brfss\brfss_msa_disease_level.dta", keep(1 3) nogen
				drop locationdesc
				rename locationid met2013
				
				bys met2013: egen msa_count = total(perwt)
				foreach x in cardiac diabetes copd cancer_kidney {
					by met2013: egen ev_risk_`x' = total(perwt*`x'_risk)
					gen `x'_modifier = (msa_count * `x'_level) / ev_risk_`x'
					
					// Use average modifier for those with no data
					summ `x'_modifier [aw=perwt]
					replace `x'_modifier = r(mean) if mi(`x'_modifier)
					replace `x'_risk = min(0.95, `x'_risk * `x'_modifier)
					drop `x'_level ev_risk_`x' `x'_modifier 
				}
				drop msa_count
			}
			drop income_group geography age_group
		}
		
		if !mi("`actualize'") {
			foreach x in cardiac diabetes copd cancer_kidney {
				gen `x' = runiform()<=`x'_risk
			}
			drop cardiac_risk diabetes_risk copd_risk cancer_kidney_risk
		}
	}
end