program define update_disease
	syntax, day(int) [debug]
	
	local vol = cond(!mi("`debug'"),"noi","qui")
	`vol' {
		tempvar days_since_infection
		gen `days_since_infection' = `day' - day_infected
		replace recovered = `days_since_infection' >= days_to_recovered & !mi(`days_since_infection')
		replace symptomatic = (`days_since_infection' >= days_to_symptomatic & !mi(`days_since_infection') & !recovered)
		replace infectious = (`days_since_infection' >= days_to_infectious & !mi(`days_since_infection') & !recovered)
	}
end