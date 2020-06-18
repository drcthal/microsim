program define define_disease_progression
	syntax, [debug]
	
	local vol = cond(!mi("`debug'"),"noi","qui")
	`vol' {
		
		// Using lognormal parameters from https://www.acpjournals.org/doi/10.7326/M20-0504 appendix table 2
		gen int days_to_symptomatic = round(exp(rnormal(1.621,0.418)))
		// Put 99.9th percentile cap on it to keep it from keeping the simulation running forever
		replace days_to_symptomatic = round(exp(1.62 + 0.418*invnormal(0.999))) if days_to_symptomatic > round(exp(1.62 + 0.418*invnormal(0.999)))
		gen days_to_infectious = days_to_symptomatic
		
		// Assuming recovery is gamma(1,5) days after symptoms, based on IC model
		// Could have it be related to age/comorbs
		// Could also have it related to whether recovery = death or return to health (e.g. I assume time to death is shorter since it truncates)
		tempvar gamma
		gen int `gamma' = round(rgamma(1,5))
		// Topcode, since gamma has quite a tail
		// Do we care about bottomcoding, i.e. everyone has to be symptomatic for 1 day? Not for now
		replace `gamma' = round(5*invgammap(1, 0.95)) if `gamma' > round(5*invgammap(1, 0.95))
		gen int days_to_recovered = days_to_symptomatic + round(`gamma')
		
		// Determine recovery type. This is all sorts of wrong.
		// Ideally would have some source that included age gender and comorbidity crossed.
		// As-is I'm assuming they're all independent, so old people will be at high risk due to age plus comorbidity, but that's double counting, since our comorbs depend on age.
		// For odds of death, numbers from https://www.worldometers.info/coronavirus/coronavirus-age-sex-demographics/
		tempvar agecat pr_die logodds logodds_base logodds_comorb logodds_age
		
		local ifr = 0.013
		local lo_ifr = ln(`ifr'/(1-`ifr'))
		gen `logodds_base' = `lo_ifr'
		
		local ifr_none = 0.009
		local ifr_cardiac = .105
		local ifr_diabetes = 0.073
		local ifr_copd = 0.063
		local ifr_cancer_kidney = 0.056
		
		gen `logodds_comorb' = 0
		
		local lo_none = ln(`ifr_none'/(1-`ifr_none'))
		local lor_none = `lo_none' - `lo_ifr'
		replace `logodds_comorb' = `lor_none' if cardiac==0 & diabetes==0 & copd==0 &  cancer_kidney==0
		
		foreach x in cardiac diabetes copd cancer_kidney {
			local lo_`x' = ln(`ifr_`x'' / (1-`ifr_`x''))
			local lor_`x' = `lo_`x'' - `lo_ifr'
			replace `logodds_comorb' = `logodds_comorb' + `lor_`x'' if `x'==1
		}
		
		tempvar agecat
		gen `agecat' = 1 if age <= 9
		replace `agecat' = 2 if inrange(age,10,19)
		replace `agecat' = 3 if inrange(age,20,29)
		replace `agecat' = 4 if inrange(age,30,39)
		replace `agecat' = 5 if inrange(age,40,49)
		replace `agecat' = 6 if inrange(age,50,59)
		replace `agecat' = 7 if inrange(age,60,69)
		replace `agecat' = 8 if inrange(age,70,79)
		replace `agecat' = 9 if age>=80
		
		// 0-9 is given as 0, assume some though
		gen `logodds_age' = .
		local age_ifrs 0.001 0.002 0.002 0.002 0.004 0.013 0.036 0.08 0.148
		forval i = 1/9 {
			local ifr_age: word `i' of `age_ifrs'
			local lo = ln(`ifr_age' / (1-`ifr_age'))
			replace `logodds_age' = `lo' - `lo_ifr' if `agecat' == `i'
		}
		
		// Don't have good gender stuff
		gen `logodds' = `logodds_base' + `logodds_comorb' + `logodds_age'
		// normalize back to overall? This gets the mean logodds right, but the mean percent is way off
		summ `logodds'
		replace `logodds' = `logodds' + `lo_ifr' - r(mean)
		gen `pr_die' = exp(`logodds') / (1 + exp(`logodds'))
		gen will_die = runiform() <= `pr_die'
	}
end