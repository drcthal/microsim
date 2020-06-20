set_dirs

cap program drop _all 
program main 
	import_contact_common 
	import_household_file
	import_participant_extra
	create_participant
	create_participant_hh 
	create_full_dataset 
	create_summary_stats
	
	alternative_work_contacts
	alternative_comm_contacts
end 

program import_contact_common 
	import delimited ${raw}\polymod\2008_Mossong_POLYMOD_contact_common.csv, varnames(1) clear stringcols(_all)
	destring part_id, replace
	
	gen cnt_age_real 		 = real(cnt_age_exact)
	gen cnt_age_min_real 	 = real(cnt_age_est_min)
	gen cnt_age_max_real 	 = real(cnt_age_est_max)
	gen frequency_multi_real = real(frequency_multi)
	gen phys_contact_real 	 = real(phys_contact)
	gen duration_multi_real  = real(duration_multi)

	foreach x in home work school transport leisure otherplace {
		replace cnt_`x' = "FALSE" if cnt_`x'=="0"
		replace cnt_`x' = "TRUE" if cnt_`x'=="1"
	}
	gen cnt_home_real = cnt_home == "TRUE"
	gen cnt_work_real = cnt_work == "TRUE"
	gen cnt_school_real = cnt_school == "TRUE"
	gen cnt_transport_real = cnt_transport == "TRUE"
	gen cnt_leisure_real = cnt_leisure == "TRUE"
	gen cnt_other_real = cnt_otherplace == "TRUE"

	gen male = cnt_gender == "M"
	 /* About 1,000 obs have gender missing */
	 
	label define phys_contact_lbl 2 "No" 1 "Yes"
	label values phys_contact_real phys_contact_lbl

	label define frequency_lbl 1 "daily" 2 "weekly" 3 "monthly" 4 "few times a year" 5 "first time"
	label values frequency_multi_real frequency_lbl 

	label define duration_lbl 1 "less than 5 min" 2 "5 to 15 min" 3 "15 min to 1 hr" 4 "1 to 4 hrs" 5 "more than 4 hrs"
	label values duration_multi_real duration_lbl 

	/* A small proportion of observations indicate more than one place of contact */

	gen total_contact_places = cnt_home_real + cnt_work_real + cnt_school_real + cnt_transport_real + cnt_leisure_real + cnt_other_real
	gen contact_place = cnt_home_real + 2*cnt_work_real + 3*cnt_school_real + 4*cnt_transport_real + 5*cnt_leisure_real + 6*cnt_other_real if total_contact_places == 1
	replace contact_place = 8 if total_contact_places > 1 & total_contact_places ~= .

	label define contact_place_lbl 1 "Home" 2 "Work" 3 "School" 4 "Transport" 5 "Leisure" 6 "Other" 8 "More than one place"
	label values contact_place contact_place_lbl

	save ${derived}/polymod/contact_common.dta, replace
end 
program import_household_file 
	import delimited ${raw}\polymod\2008_Mossong_POLYMOD_hh_extra.csv,  varnames(1) clear
	tempfile hh1
	save `hh1', replace 

	import delimited ${raw}\polymod\2008_Mossong_POLYMOD_hh_common.csv, varnames(1) clear
	merge 1:1 hh_id using `hh1'
	drop _merge

	save ${derived}\polymod\hh_merged.dta, replace
end 
program import_participant_extra 
	import delimited using ${raw}\polymod\2008_Mossong_POLYMOD_participant_extra.csv, varnames(1) clear
	save ${derived}\polymod\participant_extra.dta, replace
end 
program create_participant  
	import delimited ${raw}\polymod\2008_Mossong_POLYMOD_participant_common.csv, varnames(1) clear
	merge 1:1 part_id using ${derived}\polymod\participant_extra.dta
	drop _merge

	label define occupation_lbl 1 "Working" 2 "Retired" 3 " At Home" 4 "Unemployed" 5 "Student" 6 "Other"
	label define occupation_detail_lbl 1 "Professional (UK)" 2 "Skilled non-manual (UK)" 3 "Skilled, semi-skilled manual (UK)" 4 "Unskilled (UK)" 
	label define occupation_detail_lbl 5 "self-employed (LU/FI)" 6 "upper employee (LU/FI)" 7 "lower employee (LU/FI)" 8 "Worker", add

	label values part_occupation occupation_lbl
	label values part_occupation_detail occupation_detail_lbl

	label define education_lbl  0 "no formal schooling" 1 "primary school" 2 "secondary school (lower)" 3 "upper secondary school" 4 "secondary school (unspecified)"
	label define education_lbl 5 "university degree (lower)" 6 "university degree (higher)" 7 "university degree (unspecified)" 8 "vocational education (FI)", add
	label values part_education education_lbl

	save participant.dta, replace
	merge 1:1 part_id using ${derived}\polymod\participant_extra.dta
	drop _merge
	save ${derived}\polymod\participant_merged.dta, replace
end 
program create_participant_hh 
	use ${derived}\polymod\participant_merged.dta, clear 
	merge m:1 hh_id using ${derived}\polymod\hh_merged.dta
	drop _merge
	save ${derived}\polymod\participant_hh_merged.dta, replace
end 
program create_full_dataset 
	use ${derived}\polymod\contact_common.dta, clear
	merge m:1 part_id using ${derived}\polymod\participant_hh_merged.dta
	drop if _merge == 2 
	 /* 36 participants do not seem to appear in the contact data. */
	save ${derived}\polymod\contact_merged.dta, replace
end 
program create_summary_stats
	use ${derived}\polymod\contact_merged.dta, clear 
	gen contact_overall     = 10*contact_place + frequency_multi_real
	replace contact_overall = 0 if duration_multi_real == 1
	replace contact_overall = 0 if duration_multi_real == .

	forvalues i = 11/85 {
	 quietly gen contact`i' = contact_overall == `i' 
	  }

	drop contact16-contact20 
	drop contact26-contact30
	drop contact36-contact40
	drop contact46-contact50
	drop contact56-contact60
	drop contact66-contact80

	
	
	
	collapse (sum) contact*, by(part_id)
	

	merge 1:1 part_id using ${derived}/polymod/participant_hh_merged
	drop if _merge == 2
	drop _merge

	forvalues j = 0/53 {
	 gen home_daily`j' = contact11 == `j'
	 gen home_weekly`j' = contact12 == `j'
	 gen home_biweekly`j' = contact13 == `j'
	 gen home_monthly`j' = contact14 == `j'
	 gen home_first`j' = contact15 == `j'
	 
	 gen work_daily`j' = contact21 == `j'
	 gen work_weekly`j' = contact22 == `j'
	 gen work_biweekly`j' = contact23 == `j'
	 gen work_monthly`j' = contact24 == `j'
	 gen work_first`j' = contact25 == `j'
	 
	 gen school_daily`j' = contact31 == `j'
	 gen school_weekly`j' = contact32 == `j'
	 gen school_biweekly`j' = contact33 == `j'
	 gen school_monthly`j' = contact34 == `j'
	 gen school_first`j' = contact35 == `j'
	 
	 gen transport_daily`j' = contact41 == `j'
	 gen transport_weekly`j' = contact42 == `j'
	 gen transport_biweekly`j' = contact43 == `j'
	 gen transport_monthly`j' = contact44 == `j'
	 gen transport_first`j' = contact45 == `j'
	 
	 gen leisure_daily`j' = contact51 == `j'
	 gen leisure_weekly`j' = contact52 == `j'
	 gen leisure_biweekly`j' = contact53 == `j'
	 gen leisure_monthly`j' = contact54 == `j'
	 gen leisure_first`j' = contact55 == `j'
	 
	 gen other_daily`j' = contact61 == `j'
	 gen other_weekly`j' = contact62 == `j'
	 gen other_biweekly`j' = contact63 == `j'
	 gen other_monthly`j' = contact64 == `j'
	 gen other_first`j' = contact65 == `j'
	 
	 gen multi_daily`j' = contact81 == `j'
	 gen multi_weekly`j' = contact82 == `j'
	 gen multi_biweekly`j' = contact83 == `j'
	 gen multi_monthly`j' = contact84 == `j'
	 gen multi_first`j' = contact85 == `j'
	 }

	forvalues j = 1/6 {
	preserve
	keep if part_occupation == `j'
	collapse home* work* school* transport* leisure* other* multi* part_occupation
	tempfile contacts`j'
	save `contacts`j'', replace
	restore
	}

	use `contacts1', clear
	forvalues i = 2/6 {
	 append using `contacts`i''
	 }
	 
	preserve

	keep part_occupation *daily*
	reshape long home_daily work_daily school_daily transport_daily leisure_daily multi_daily other_daily, i(part_occupation) j(contacts)
	gen frequency = 1
	 rename home_daily home
	 rename work_daily work
	 rename school_daily school
	 rename transport_daily transport
	 rename leisure_daily leisure
	 rename other_daily other
	 rename multi_daily multi
	tempfile daily
	save `daily', replace 
	restore

	preserve
	keep part_occupation *_weekly*
	reshape long home_weekly work_weekly school_weekly transport_weekly leisure_weekly multi_weekly other_weekly, i(part_occupation) j(contacts)
	gen frequency = 2
	 rename home_weekly home
	 rename work_weekly work
	 rename school_weekly school
	 rename transport_weekly transport
	 rename leisure_weekly leisure
	 rename other_weekly other
	 rename multi_weekly multi
	tempfile weekly
	save `weekly', replace 
	restore

	preserve
	keep part_occupation *_biweekly*
	reshape long home_biweekly work_biweekly school_biweekly transport_biweekly leisure_biweekly multi_biweekly other_biweekly, i(part_occupation) j(contacts)
	gen frequency = 3
	 rename home_biweekly home
	 rename work_biweekly work
	 rename school_biweekly school
	 rename transport_biweekly transport
	 rename leisure_biweekly leisure
	 rename other_biweekly other
	 rename multi_biweekly multi
	tempfile biweekly
	save `biweekly', replace 
	restore

	preserve
	keep part_occupation *monthly*
	reshape long home_monthly work_monthly school_monthly transport_monthly leisure_monthly multi_monthly other_monthly, i(part_occupation) j(contacts)
	gen frequency = 4
	 rename home_monthly home
	 rename work_monthly work
	 rename school_monthly school
	 rename transport_monthly transport
	 rename leisure_monthly leisure
	 rename other_monthly other
	 rename multi_monthly multi
	tempfile monthly
	save `monthly', replace 
	restore


	keep part_occupation *first*
	reshape long home_first work_first school_first transport_first leisure_first multi_first other_first, i(part_occupation) j(contacts)
	gen frequency = 5
	 rename home_first home
	 rename work_first work
	 rename school_first school
	 rename transport_first transport
	 rename leisure_first leisure 
	 rename other_first other
	 rename multi_first multi
	tempfile first
	save `first', replace 

	use `daily', clear
	append using `weekly'
	append using `biweekly'
	append using `monthly'
	append using `first'

	label values frequency frequency_lbl 
	label values part_occupation occupation_lbl
	save "${raw}\polymod\contact_data_distribution.dta", replace 

end 


program alternative_work_contacts

	use ${derived}\polymod\contact_merged.dta, clear 
	drop if inlist(duration_multi_real, 1) == 1 // Drop contacts < 15 mins
	keep if part_occupation == 1 // Keep only workers 
	
	gen infrequent = inlist(frequency_multi_real,5) == 1 
	foreach v in cnt_home cnt_work cnt_school cnt_transport cnt_leisure cnt_otherplace {
		gen tmp = `v' == "TRUE"
		drop `v'
		gen `v'_infrequent  = tmp if infrequent == 1 
		gen `v'_frequent 	= tmp if infrequent == 0 
		rename tmp `v' 
	}
	collapse (sum) 	cnt_home cnt_work cnt_school cnt_transport cnt_leisure cnt_otherplace ///
					cnt_home_infrequent cnt_work_infrequent  cnt_school_infrequent  cnt_transport_infrequent  cnt_leisure_infrequent  cnt_otherplace_infrequent  ///
					cnt_home_frequent   cnt_work_frequent    cnt_school_frequent    cnt_transport_frequent    cnt_leisure_frequent    cnt_otherplace_frequent,   ///
					by(part_id part_occupation) 
					
	foreach v in cnt_home cnt_work cnt_school cnt_transport cnt_leisure cnt_otherplace ///
	             cnt_home_infrequent cnt_work_infrequent  cnt_school_infrequent  cnt_transport_infrequent  cnt_leisure_infrequent  cnt_otherplace_infrequent  ///
	             cnt_home_frequent   cnt_work_frequent    cnt_school_frequent    cnt_transport_frequent    cnt_leisure_frequent    cnt_otherplace_frequent {
				
				replace `v' = 53 if `v' > 53
	}
	
	hist cnt_work , ////
		graphregion(color(white)) ///
		title("Total Number of Contacts") ///
		caption("Restrict to individuals who are working" "Contacts of 15 mins or more") ///
		fcolor(blue%30) lcolor(blue%50)
		graph export "${output}/hist_number_overall_work_contacts.png", as(png) height(400) width(600) replace 
				
	gen sh_infrequent = cnt_work_infrequent/cnt_work 
	binscatter sh_infrequent cnt_work if part_occupation == 1 
	gen num_obs  = 1 
	
	reg sh_infrequent cnt_work
	
	// Overall Work Contacts 
	preserve 
		collapse (mean) sh_infrequent (sum) num_obs  , by(cnt_work part_occupation) 
			bysort part_occupation: egen num_obs_occ = sum(num_obs)
			gen sh_obs = num_obs/num_obs_occ 
			sort part_occupation cnt_work 
			
			
			sort cnt_work 
			gen cumulative = sum(sh_obs)
			
			binscatter cumulative cnt_work , line(connect) ///
				title("PDF of Total Work Contacts") ///
				xtitle("Number of Work Contacts") ///
				ytitle("Cumulative CDF") ///
				caption("Restrict to individuals who are working" "Contacts of 15 mins or more") 
				graph export "${output}/pdf_number_overall_work_contacts.png", as(png) height(400) width(600) replace 

				
			keep cnt_work cumulative  

			save ${derived}/number_overall_work_contacts.dta, replace 
			
			
	restore 
	
	hist sh_infrequent , ////
		graphregion(color(white)) ///
		title("Share of Contacts with an Infrequently" "Encountered Counterpart") ///
		caption("Restrict to individuals who are working" "Contacts of 15 mins or more") ///
		fcolor(blue%30) lcolor(blue%50)
		graph export "${output}/hist_share_work_contacts_infrequent.png", as(png) height(400) width(600) replace 
	
	// Share of Work Contacts that are with a Customer
	gen sh_infrequent_round = round(sh_infrequent,0.05)
	
	collapse (sum) num_obs  , by(sh_infrequent_round part_occupation) 
		drop if missing(sh_infrequent_round) 
		bysort part_occupation: egen num_obs_occ = sum(num_obs)
		gen sh_obs = num_obs/num_obs_occ 
		sort part_occupation sh_infrequent_round 
		
		sort sh_infrequent_round 
		gen cumulative = sum(sh_obs)
		
		binscatter  cumulative sh_infrequent_round, line(connect) ///
			title("PDF of Share of Work Contacts that are Low Frequency", size(medsmall)) ///
			xtitle("Share of Work Contacts Low Frequency") ///
			ytitle("Cumulative CDF") ///
			caption("Restrict to individuals who are working" "Contacts of 15 mins or more") 
			graph export "${output}/pdf_sh_workcontacts_infrequent.png", as(png) height(400) width(600) replace 

		keep cumulative sh_infrequent_round
		save ${derived}/share_infrequent_work_contacts.dta, replace 
end 

program alternative_comm_contacts
	use ${derived}\polymod\contact_merged.dta, clear 
	drop if inlist(duration_multi_real, 1) == 1 // Drop contacts < 15 mins
	drop if cnt_home == "TRUE" | cnt_work == "TRUE" | cnt_school == "TRUE" 
	gen cnt_community  = 1 
	collapse (sum) cnt_community , by(part_id part_occupation) 
	isid part_id 
	collapse (mean) cnt_community , by(part_occupation) 
	save ${derived}\polymod\average_community_contact.dta, replace 
end

main 
