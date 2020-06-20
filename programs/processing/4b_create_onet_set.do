set_dirs

cap program drop _all
program main
	import_onet_data
	test_ACS_match
	quick_descriptives 
	
	match_to_polymod 
end

// *************
// Create SOC - ONET xwalks
program import_onet_data
	import delimited "${raw}\onet\2010_to_2018_SOC_Crosswalk.csv", varnames(1) clear 
	isid soccode onetsoc2010code 
	unique soccode 
	unique onetsoc2010code 
	keep soccode onetsoc2010code 
	bysort onetsoc2010code: gen id = _n 
	reshape wide soccode, i(onetsoc2010code) j(id) 
	save  "${derived}\polymod\onet_soc_to_acs_soc_xwalk.dta" , replace 
	
	
	
	// Import ONET Data 
	import delimited "${raw}\onet\Face-to-Face_Discussions.csv", clear 
	rename context  face_to_face
	save "${raw}\onet\Face-to-Face_Discussions.dta" , replace 
	import delimited "${raw}\onet\Physical_Proximity.csv", clear 
	rename context  physical_proximity
	save "${raw}\onet\Physical_Proximity.dta", replace
	import delimited "${raw}\onet\Deal_With_External_Customers.csv", clear 
	rename context  deal_with_customers
	save "${raw}\onet\Deal_With_External_Customers.dta", replace
	
	merge 1:1 code using "${raw}\onet\Face-to-Face_Discussions.dta"  , keep(1 3) nogen 
	merge 1:1 code using "${raw}\onet\Physical_Proximity.dta", keep(1 3) nogen 
	
	count
	unique code
	isid code 
	
	rename code onetsoc2010code 
	merge m:1 onetsoc2010code using "${derived}\polymod\onet_soc_to_acs_soc_xwalk.dta" 
	keep if _merge == 3
	drop _merge
	reshape long soccode, i(onetsoc2010code) j(id) 
	drop id 
	drop if missing(soccode)
	rename soccode soc 
	collapse (mean) face_to_face physical_proximity deal_with_customers, by(soc) 
	count
	gen final_soc_digit = substr(soc,7,1)
	tab final_soc_digit
	drop final_soc_digit 
	compress 
	save "${derived}\polymod\onet.dta", replace 
end 
program test_ACS_match 
	use soc perwt using "${derived}\acs_2018_clean_analysis.dta", clear
	keep if !missing(soc) 
	merge m:1 soc using  "${derived}\polymod\onet.dta", keep(1 3) 
	
	
	gen soc_lastdigit  = substr(soc,7,1)
	gen soc_twodigit   = substr(soc,1,2) 
	gen soc_fourdigit  = substr(soc,4,4) 
	
	tab _merge if !missing(soc) 	
	tab soc_lastdigit _merge 
	tab soc_twodigit  _merge 
	tab soc_fourdigit _merge 

	// Reasons: 
	// 1) Too aggregated
	gen aggregated = inlist(soc_lastdigit,"0","X") & _merge == 1 
	// 2) Start with 55
	gen start_55 = 	soc_twodigit == "55" 
	// 3)  Not in Crosswalk
	gen not_in_xwalk = _merge == 1 & ~missing(soc) & ~inlist(soc_lastdigit,"0","X")
	assert (aggregated | start_55 | not_in_xwalk) | inlist(_merge,2,3) | missing(soc)
	
	unique soc if aggregated   == 1
	unique soc if start_55 	   == 1
	unique soc if not_in_xwalk == 1

	gen matched = _merge == 3 

	foreach v in 1 2 3  {
		local num = `v' + 1 
		gen soc_`v'  = substr(soc_fourdigit,1,`num')
		bysort soc_twodigit soc_`v': egen soc_`v'_hasmatch = max(matched) 
	}
	bysort soc_twodigit: egen soc_0_hasmatch =  max(matched)
	
	egen t =tag(soc) 
	tab matched if  t == 1 
	tab soc_3_hasmatch if (aggregated == 1 | not_in_xwalk == 1 ) & t == 1 
	tab soc_2_hasmatch if (aggregated == 1 | not_in_xwalk == 1 ) & t == 1 
	tab soc_1_hasmatch if (aggregated == 1 | not_in_xwalk == 1 ) & t == 1 
	tab soc_0_hasmatch if (aggregated == 1 | not_in_xwalk == 1 ) & t == 1 
	
	
	foreach v in face_to_face physical_proximity deal_with_customers {
		foreach num in 3 2 1 {
			bysort soc_twodigit soc_`num': egen tmp = wtmean(`v') , weight(perwt)
			replace `v' = tmp if missing(`v') 
			drop tmp 
		}
		bysort soc_twodigit: egen tmp = mean(`v') 
		replace `v' = tmp if missing(`v') 
		drop tmp 
	}
	
	
	mdesc face_to_face physical_proximity deal_with_customers  if  t == 1 
	mdesc face_to_face physical_proximity deal_with_customers  if  t == 1 & (aggregated == 1 | not_in_xwalk == 1 ) 
		
	gen impute_flag = matched == 0 
	keep if inlist(_merge,1,3) 
	keep soc face_to_face physical_proximity deal_with_customers impute_flag 
	duplicates drop 
	drop if missing(soc) | soc == "none"
	isid soc 
	save "${derived}\polymod\onet_clean.dta", replace
	
end 
program quick_descriptives 
	use "${derived}\polymod\onet_clean.dta", clear
	gen title_face_to_face 			= "Face-to-Face Discussions" 
	gen title_deal_with_customers   = "External Customers" 
	gen title_physical_proximity    = "Physical Proximity" 
	foreach v in face_to_face deal_with_customers physical_proximity {
		local t = title_`v' 
		hist `v' , /// 
			graphregion(color(white)) ///
			title("`t'") ///
			xline(25) xline(50) xline(75) ///
			fcolor(blue%30) 
			graph export "${output}/hist_`v'.png", as(png) height(400) width(600) replace 
	}

end 



// ********
// POLYMOD Fit 
program match_to_polymod

	use pernum serial soc perwt employed occ using "${derived}\acs_2018_clean_analysis.dta", clear
	keep if employed == 1 
	merge m:1 soc using  "${derived}\polymod\onet_clean.dta", keep(1 3) nogen 
	
	// Calculate Mean Count
	sort face_to_face 
	gen  numerator   = sum(perwt) 
	egen denominator = sum(perwt) 
	gen  cumulative  = numerator/denominator 
	gen legit = 1 
	append using ${derived}/number_overall_work_contacts.dta
	gsort -legit cumulative 
	replace cnt_work  = 0 if _n == 1 
	ipolate cnt_work cumulative, gen(cnt_work_hat)
	drop cnt_work 
	drop if missing(legit) 
	drop legit 
	
	// Calcualte Mean Share Infrequent Contacts 
	drop cumulative numerator denominator 
	sort deal_with_customers 
	gen  numerator   = sum(perwt) 
	egen denominator = sum(perwt)
	gen  cumulative  = numerator/denominator
	gen legit = 1 
	append using ${derived}/share_infrequent_work_contacts.dta, 
	gsort -legit cumulative 
	replace sh_infrequent = 0 if _n == 1 
	ipolate sh_infrequent cumulative , gen(sh_infrequent_hat) 
	drop sh_infrequent_round
	drop if missing(legit) 
	
	// Fill in Military People 
	egen cnt_work_median   = pctile(cnt_work_hat) , p(50) 
	egen sh_infrequent_p25 = pctile(sh_infrequent_hat) , p(25) 
	replace cnt_work_hat = cnt_work_median if substr(soc,1,2) == "55" 
	replace sh_infrequent_hat = sh_infrequent_p25 if substr(soc,1,2) == "55" 
	drop sh_infrequent_p25  cnt_work_median 
	
	if 1 == 1 {
		gen soc_2digit = substr(soc,1,2) 
		gen soc_2digit_lab = ""
	
		 replace soc_2digit_lab = 	"Management Occupations" 		if soc_2digit == "11"
		 replace soc_2digit_lab = 	"Business and Financial"        if soc_2digit == "13"
		 replace soc_2digit_lab = 	"Computer and Math"             if soc_2digit == "15"
		 replace soc_2digit_lab = 	"Architecture and Engineering"  if soc_2digit == "17"
		 replace soc_2digit_lab = 	"Science"                       if soc_2digit == "19"
		 replace soc_2digit_lab = 	"Community, Social Services"    if soc_2digit == "21"
		 replace soc_2digit_lab = 	"Legal Occupations"             if soc_2digit == "23"
		 replace soc_2digit_lab = 	"Education"                     if soc_2digit == "25"
		 replace soc_2digit_lab = 	"Media, Sports"                 if soc_2digit == "27"
		 replace soc_2digit_lab = 	"Healthcare"                    if soc_2digit == "29"
		 replace soc_2digit_lab = 	"Healthcare Support"            if soc_2digit == "31"
		 replace soc_2digit_lab = 	"Protective Service"            if soc_2digit == "33"
		 replace soc_2digit_lab = 	"Food"                          if soc_2digit == "35"
		 replace soc_2digit_lab = 	"Maintenance"                   if soc_2digit == "37"
		 replace soc_2digit_lab = 	"Personal Care"                 if soc_2digit == "39"
		 replace soc_2digit_lab = 	"Sales"                         if soc_2digit == "41"
		 replace soc_2digit_lab = 	"Office"                        if soc_2digit == "43"
		 replace soc_2digit_lab = 	"Farming"                       if soc_2digit == "45"
		 replace soc_2digit_lab = 	"Construction"                  if soc_2digit == "47"
		 replace soc_2digit_lab = 	"Installation"                  if soc_2digit == "49"
		 replace soc_2digit_lab = 	"Production"                    if soc_2digit == "51"
		 replace soc_2digit_lab = 	"Transportation"                if soc_2digit == "53"
		 replace soc_2digit_lab = 	"Military"                      if soc_2digit == "55"
		 
		 tabstat sh_infrequent_hat cnt_work_hat , by(soc_2digit_lab) 
	}	
	
	// Collapse to SOC level 
	collapse (mean) cnt_work_hat sh_infrequent_hat, by(soc occ) 

	keep soc occ  cnt_work_hat sh_infrequent_hat
	save "${derived}\polymod\ACS_workcounts.dta", replace 
	
end 




main 
