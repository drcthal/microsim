program drop _all
set_dirs

use "$derived\acs_2018_clean.dta", clear

// Assume all non-metro folks in a state are their own community.
// Could merge on micro areas, or could instead model states as communities rather than MSAs

assert met2013 > 100 if met2013!=0
qui: levelsof statefip, local(states)
foreach state of local states {
	replace met2013 = `state' if statefip==`state' & met2013==0
	label define `:value label met2013' `state' "Non-metro `:label (statefip) `state''", modify
}

gen perid = _n
rename serial hhid

recode race (1=1) (2=2) (3=3) (4/6 = 4) (7=6) (8/9=7), gen(raceeth)
replace raceeth = 5 if hispan!=0
label define raceeth_lbl 1 "White" 2 "Black" 3 "AIAN" 4 "Asian/PI" 5 "Hispanic" 6 "Other" 7 "Multiple", replace
label values raceeth raceeth_lbl

gen male = sex==1

// combine none and unemployed
replace ind = 0 if ind==9920
replace occ = 0 if occ==9920
replace hhincome = . if hhincome<0 | hhincome==9999999

// Deterministic portion of comorbs
add_comorb, check_ev prob
identify_essential, prob
add_contact_Ns
add_taus
seed_infections, prob

keep perid hhid met2013 statefip male age raceeth educ hhincome perwt occ ind cardiac_risk diabetes_risk copd_risk cancer_kidney_risk essential pr_essential N_c N_w_c N_w_w base_tau_w base_tau_c base_tau_h tau_e tau_ne cuml_pr_inf_*
order perid hhid met2013 statefip male age raceeth educ hhincome perwt occ ind cardiac_risk diabetes_risk copd_risk cancer_kidney_risk essential pr_essential N_c N_w_c N_w_w base_tau_w base_tau_c base_tau_h tau_e tau_ne cuml_pr_inf_*

compress
isid perid
save "$derived\simulation_afile.dta", replace