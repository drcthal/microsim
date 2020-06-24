program define identify_essential
	syntax, [prob actualize]
	
	qui {
		if !mi("`prob'") {
		    drop *merge* Critical essential
			merge m:1 occ using "${raw}\occupation_classifications\2018-occupation-code-list-and-crosswalk.dta", keep(1 3) nogen
			gen fivedigit = substr(soc,6,1) == "X"
			
			merge m:1 soc using "${raw}\occupation_classifications\SOC-Codes-CISA-Critical.dta", keep(1 3) nogen
			
			assert mi(Critical) if fivedigit==1
			gen essential = !missing(Critical) if !fivedigit
			
			// For the people with 5-digit soc codes (e.g. not elsewhere classified) extrapolate from others in the same industry group
			gen industrygroup_clean = .
			replace industrygroup_clean = 1 if inlist(ind,7970,8080,8090,8170) // health
			replace industrygroup_clean = 1 if inlist(ind,8180,8191,8194,8270) // health
			replace industrygroup_clean = 1 if inlist(ind,7980,7990,8070,8192) // health
			replace industrygroup_clean = 2 if industrygroup == 6  // Retail
			replace industrygroup_clean = 3 if industrygroup == 4  // Manufacturing 
			replace industrygroup_clean = 4 if industrygroup == 3  // Construction 
			replace industrygroup_clean = 5	if industrygroup == 18 // Accommodation and Food 
			replace industrygroup_clean = 6	if industrygroup == 20 // Public Administration 
			replace industrygroup_clean = 7	if industrygroup == 12 // Scientific and Technical 
			replace industrygroup_clean = 8	if industrygroup == 7  // Transportation 
			replace industrygroup_clean = 9	if missing(industrygroup_clean)  // Other Essential		
			
			gen subind_clean = . 
			replace subind_clean = 11 if inlist(ind,8191) 	// General Hospital 
			replace subind_clean = 12 if inlist(ind,8270) 	// Nursing Homes
			replace subind_clean = 13 if ind == 7970 		// Physician Office
			replace subind_clean = 14 if ind == 8090 		// Outpatient Care 
			replace subind_clean = 15 if inlist(ind,8170) 	// Home Health
			replace subind_clean = 16 if inlist(ind,8192) 	// Psych, Substance Abuse Hospital
			replace subind_clean = 17 if inlist(ind,7980,7990,8070,8080,8180) // Other Medical Services
			
			replace subind_clean = 21 if inlist(ind, 4971 , 4972 , 4990 ) // Grocery 
			replace subind_clean = 22 if inlist(ind, 5070) 				  // Pharmacy 
			replace subind_clean = 23 if missing(subind_clean) & industrygroup_clean == 2 // Other Retail 
			
			replace subind_clean = 51 if ind == 8680 // Restaurant 
			replace subind_clean = 52 if ind == 8660 // Hotels
			replace subind_clean = 53 if missing(subind_clean) & industrygroup_clean == 5 // Other Accomotdation / Food 
			
			replace subind_clean = 61 if ind == 9470 // Police
			replace subind_clean = 62 if ind == 9370 // Executive, Legislative Bodies 
			replace subind_clean = 63 if inlist(ind, 9480,9490,9570) // Administration
			replace subind_clean = 64 if ind == 9590 // National Security
			replace subind_clean = 65 if missing(subind_clean) & industrygroup_clean == 6
			
			preserve
				gcollapse (mean) pr_essential = essential [aw=perwt], by(subind_clean)
				tempfile pr_ess
				save `pr_ess'
			restore
			merge m:1 subind_clean using `pr_ess', assert(1 3) nogen
			assert !mi(pr_essential) if mi(essential)
			
			drop fivedigit industrygroup category industrygroup_clean subind_clean
		}
		
		if !mi("`actualize'") {
			replace essential = runiform() <= pr_essential if mi(essential)
			drop pr_essential
		}
	}
end