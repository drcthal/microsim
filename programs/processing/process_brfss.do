clear all
set_dirs

// use SMART data to get MSA-level prevalences
{
	import delimited using "$raw\brfss\brfss_smart.csv", delim(",") clear

	keep year locationid locationdesc class topic question response sample_size data_value 

	replace locationdesc = "Warren-Troy-Farmington Hills, MI Metropolitan Division" if locationid == 47664

	gen important = topic == "BMI Categories" & substr(response,1,5) == "Obese"
	replace important = 1 if topic == "COPD" & response == "Yes" 
	replace important = 1 if topic == "Cardiovascular Disease" & response == "Yes"
	replace important = 1 if topic == "Cholesterol High" & response == "Yes"
	replace important = 1 if topic == "Diabetes" & response == "Yes"
	replace important = 1 if topic == "High Blood Pressure" & response == "Yes"
	replace important = 1 if topic == "Heavy Drinking" & response == "Yes"
	replace important = 1 if topic == "Kidney" & response == "Yes"
	replace important = 1 if topic == "Other Cancer" & response == "Yes"
	replace important = 1 if topic == "Current Smoker Status" & response == "Yes"

	keep if important

	replace topic = "Heart Attack" if topic == "Cardiovascular Disease" & substr(question, 21, 12) == "heart attack"
	replace topic = "Stroke" if topic == "Cardiovascular Disease" & substr(question, 21, 6) == "stroke"
	replace topic = "Angina" if topic == "Cardiovascular Disease" & substr(question, 19, 6) == "angina"

	// These seem like useless values - don't want to count in the numerator or denominator
	count if sample_size!=0 & mi(data_value)
	replace sample_size = . if mi(data_value)

	reshape wide data_value sample_size, i(locationid topic) j(year)

	egen numerator = rowtotal(data_value*)
	egen denominator = rowtotal(sample_size*)

	replace locationid = 47900 if locationid == 47894
	replace locationdesc = "Washington-Arlington-Alexandria, DC-VA-MD-WV" if locationid==47900
	 /* Change of number for Arlington, VA + Washington DC to match ACS */

	replace locationid = 42660 if locationid == 42644
	replace locationid = 42660 if locationid == 45104
	replace locationdesc = "Seattle-Tacoma-Bellevue, WA" if locationid==42660
	 /* Seattle and Tacoma are combined for ACS */
	 
	replace locationid = 37980 if locationid == 37964
	replace locationid = 37980 if locationid == 48864
	replace locationid = 37980 if locationid == 15804
	replace locationdesc = "Philadelphia-Camden-Wilmington, PA-NJ-DE-MD" if locationid==37980
	 /* Camden, Wilmington DE and Philadelphia are combined for ACS */
	 
	replace locationid = 35620 if locationid == 35614
	replace locationid = 35620 if locationid == 35644
	replace locationid = 35620 if locationid == 35084
	replace locationdesc = "New York-Newark-Jersey City, NY-NJ-PA" if locationid==35620
	 /* Jersey City, Newark, and NYC are combined for ACS */

	replace locationid = 19820 if locationid == 19804
	replace locationid = 19820 if locationid == 47664
	replace locationdesc = "Detroit-Warren-Dearborn, MI" if locationid==19820
	 /* Detroit and Warren/Farmington Hills are combined for ACS */

	replace locationid = 19100 if locationid == 19124
	replace locationid = 19100 if locationid == 23104
	replace locationdesc = "Dallas-Fort Worth-Arlington, TX" if locationid==19100
	 /* Dallas and Arlington/Fort Worth are combined for ACS */

	replace locationid = 14460 if locationid == 14454
	replace locationid = 14460 if locationid == 14484
	replace locationid = 14460 if locationid == 15764
	replace locationdesc = "Boston-Cambridge-Newton, MA-NH" if locationid==14460
	 /* Boston, Cambridge, and Quincy are combined for ACS */
	 
	collapse (sum) numerator denominator, by(locationid locationdesc topic)

	gen average_value = numerator/denominator
	rename denominator total_sample_size 

	keep topic average_value total_sample_size locationid locationdesc

	/* categories
	1 = Angina, 2 = Obese, 3 = COPD, 4 = High Cholestero, 5 = Smoker,
	6 = Diabetes, 7 = Heart Attack, 8 = Heavy Drinker, 9 = High BP, 
	10 = Kidney Disease, 11 = Other Cancer  12 = Stroke */
	 
	gen category = 1 if topic == "Angina"
	replace category = 2 if topic == "BMI Categories"
	replace category = 3 if topic == "COPD"
	replace category = 4 if topic == "Cholesterol High"
	replace category = 5 if topic == "Current Smoker Status"
	replace category = 6 if topic == "Diabetes"
	replace category = 7 if topic == "Heart Attack"
	replace category = 8 if topic == "Heavy Drinking"
	replace category = 9 if topic == "High Blood Pressure"
	replace category = 10 if topic == "Kidney"
	replace category = 11 if topic == "Other Cancer"
	replace category = 12 if topic == "Stroke"

	drop topic
	 
	reshape wide average_value total_sample_size, i(locationid) j(category)

	rename average_value3 copd_level
	rename average_value6 diabetes_level
	gen cancer_kidney_level = 0.93 * (average_value10 + average_value11)
	 /* tabulation in BRFSS indicates this multiplier to account for double counting */
	gen cardiac_level = 0.73 *(average_value1 + average_value7 + average_value12)

	keep locationid locationdesc *level

	compress
	isid locationid
	save "$derived\brfss\brfss_msa_disease_level.dta", replace
}

// use microdata to get risk factors
{
	fdause "$raw\brfss\LLCP2018.XPT", clear

	gen cancer = chcocncr == 1

	gen obese = _bmi5 >= 3000 & _bmi5 < 9999
	 
	 /* last two digits are decimal values of BMI, 9999 is missing */
	// heart attack, angina, or stroke
	gen cardiac = cvdinfr4 == 1 | cvdcrhd4 == 1 | cvdstrk3 == 1
	gen diabetes = diabete3 == 1
	gen copd = chccopd1 == 1
	// kidney disease or cancer
	gen other = chckdny1  == 1 | chcocncr == 1

	gen male = sex1 == 1 if inlist(sex1,1,2)

	gen income_group = 1 if income2 <= 5
	replace income_group = 2 if income2 == 6 | income2 == 7
	replace income_group = 3 if income2 == 8
	replace income_group = 4 if income2 == 77 | income2 == 99 | income2 == .

	// metro, rural, micro
	gen geography = 1 if _metstat == 1
	replace geography = 2 if _urbstat == 2
	replace geography = 3 if _metstat == 2 & _urbstat == 1
	
	// Data only goes down to 18-24 yo, so no actual data for 0-18
	gen age_group = 2 if _ageg5yr <= 6 
	replace age_group = 3 if _ageg5yr == 7  | _ageg5yr == 8
	replace age_group = 4 if _ageg5yr >= 9 & _ageg5yr <= 13
	 
	/* Complicated weighting scheme - I found this suggested code on a BRFSS site 
	The downside is that it then requires running everything with the svyset command, which is limited. */
	svyset[pweight=_llcpwt], strata(_ststr) psu(_psu)

	tempfile pfile
	tempname pname
	postfile `pname' male income_group geography age_group cardiac_risk diabetes_risk copd_risk cancer_kidney_risk using `pfile'

	// Could do something more complex to model joint probabilities for the diseases. Could also do some partial pooling
	qui {
		forval m = 0/1 {
			forval inc = 1/4 {
				forval g = 1/3 {
					forval a = 2/4 {
						svy: mean cardiac diabetes copd other if male == `m' & income_group == `inc' & geography==`g' & age_group == `a'
						mat means = r(table)
						post `pname' (`m') (`inc') (`g') (`a') (`=means[1,1]') (`=means[1,2]') (`=means[1,3]') (`=means[1,4]')	
					}
					
					// For younger ages, estimate the local log-linear effect of age among the 18-34 group, then extrapolate down to _ageg5yr==-1 (0-17 would be -2, -1, and 0 so -1 is about the average)
					local postline (`m') (`inc') (`g') (1) 
					foreach x in cardiac diabetes copd other {
						svy: logit `x' _ageg5yr if male == `m' & income_group == `inc' & geography==`g' & inrange(_ageg5yr, 1, 3)
						local xb = _b[_cons] - _b[_ageg5yr]
						local pr = exp(`xb') / (1+exp(`xb'))
						di `pr'
						local postline `postline' (`pr') 
					}
					post `pname' `postline'
				}
			}
		}
	}

	postclose `pname'
	use `pfile', clear
	sort male income_group age_group geography
	
	compress
	isid male income_group age_group geography
	save "$derived\brfss\brfss_risks.dta", replace
}
