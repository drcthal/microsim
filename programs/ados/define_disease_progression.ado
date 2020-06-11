program define define_disease_progression
	syntax, [debug]
	
	local vol = cond(!mi("`debug'"),"noi","qui")
	`vol' {
		// Placeholder
		gen days_to_symptomatic = runiformint(1,10)
		gen days_to_infectious = min(days_to_symptomatic, runiformint(1,10))
		gen days_to_recovered = runiformint(5,20)
	}
end