program define add_contact_Ns	
	qui {
		// Average number of contacts if they spent 24 hours somewhere
		merge m:1 occ using "$derived\polymod\ACS_workcounts.dta", keep(1 3) nogen keepusing(occ cnt_work_hat sh_infrequent_hat)
		assert mi(cnt_work_hat) == (occ==0)

		// Split contacts at work into contacts with coworkers (assumed to be the frequent contacts)
		// and the work contacts with the community
		gen N_w_w = cnt_work_hat * (1-sh_infrequent_hat)
		replace N_w_w = 0 if occ==0
		gen N_w_c = cnt_work_hat * sh_infrequent_hat
		replace N_w_c = 0 if occ==0
		drop cnt_work_hat sh_infrequent_hat

		// Assume not in laborforce and older = retired; 
		// not working and younger = student,
		// not working and in between = 50/50 unemployed vs at home
		// Working = employed
		gen part_occupation = 1 if occ!=0
		// Retired = older and not in LF
		replace part_occupation = 2 if occ==0 & age>=60 & labforce==1
		// student = younger and not working and not in LF
		replace part_occupation = 5 if occ==0 & age<=25 & inlist(labforce, 0, 1)
		// At home = unemployed and not in LF
		replace part_occupation = 3 if occ==0 & inrange(age,26,59) & labforce==1
		// Unemployed = unemployed and in LF
		replace part_occupation = 4 if occ==0 & labforce==2
		assert !mi(part_occupation)

		merge m:1 part_occupation using "$derived\polymod\average_community_contact.dta", assert(2 3) keep(3) nogen
		// This is "typical" so should be scaled by tau_c relative to base_tau_c
		rename cnt_community N_c
		
		// Scale community contacts based on population density, but log-wise
		gen log_dens = log(density)
		summ log_dens [aw=perwt]
		replace N_c = N_c * log_dens / r(mean)
		drop part_occupation log_dens
	}
end