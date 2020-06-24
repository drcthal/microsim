program define update_taus
	syntax, day(int) [pr_wfh(real 0.5) pr_isolate(real 0.25) debug]
	
	local vol = cond(!mi("`debug'"),"noi","qui")
	`vol' {		
		// If a person is newly symptomatic, change their behavior
		// Don't reroll this each day
		// Todo: depend on industry etc?
		// alternatively make this an initially generated quantity - are you able & willing to WFH/isolate
		replace tau_w = 0 if (`day' - day_infected) == days_to_symptomatic & runiform()<=`pr_wfh'
		replace tau_c = min(tau_c, 0.5/24) if (`day' - day_infected) == days_to_symptomatic & runiform()<=`pr_isolate'
		
		// return to work if recovered
		replace tau_w = covid_tau_w if recovered
		replace tau_c = covid_tau_c if recovered
		
		// The dead will have their tau_c/w set to 0, since in this model that is equivalent (no interaction outside of the house, and inside we only track the infections, which they necessarily aren't)
		replace tau_w = 0 if dead
		replace tau_c = 0 if dead
		
		/*
			Could also update society things, like society shutting down  depending on infection rates, 
			or industry specific shutdowns or w/e
			Could also introduce cylclical patterns like weekends changing taus
		*/
		
		replace tau_h = 1 - tau_c - tau_w
	}
end