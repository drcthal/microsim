program define add_taus
	syntax, [actualize]
	qui {
		if mi("`actualize'") {
			// will have 3 sets of vars - tau during pre-covid period, general tau during covid period, and current daily tau
			// Need to know baseline period taus to modify contacts, since contact estimates are from pre-covid
			gen base_tau_w = 0 if occ==0
			replace base_tau_w = uhrswork / (7*24) if occ!=0
			drop uhrswork
			
			rename statefip state_fips
			merge m:1 state_fips using "$derived\Safegraph\tau_H.dta", assert(2 3) keep(3) nogen keepusing(tau_e tau_ne)
			rename state_fips statefip 
			
			replace tau_e = tau_e/100
			replace tau_ne = tau_ne/100
			
			gen base_tau_c = max(1 - base_tau_w - tau_e, 0.5/24) if occ!=0
			replace base_tau_c = max(1 - tau_ne, 0.5/24) if occ==0
			
			gen base_tau_h = 1 - base_tau_w - base_tau_c
		}
		if !mi("`actualize'") {
			gen covid_tau_w = base_tau_w
			replace covid_tau_w = 0 if essential==0
			
			gen covid_tau_c = max(1 - covid_tau_w - tau_e, 0.5/24) if occ!=0 & essential==1
			replace covid_tau_c = max(1 - tau_ne, 0.5/24) if occ==0 | essential==0
			
			gen covid_tau_h = 1 - covid_tau_w - covid_tau_c
			
			drop tau_e tau_ne
			
			gen tau_w = covid_tau_w
			gen tau_c = covid_tau_c
			gen tau_h = covid_tau_h
		}
	}
end