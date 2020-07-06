clear all
set_dirs

import delimited using "$raw\rt\rt.csv", delim(",") clear
gen temp = date(date,"YMD")
format temp %td
drop date
rename temp date

gen day = date - td(31mar2020)

keep if inrange(date,td(1apr2020),td(31may2020))
// Use posterior mean
rename mean r0_actual
rename lower* r0_lower*
rename upper* r0_upper*
rename region abbr
merge m:1 abbr using "$raw\all_statefip.dta", assert(3) nogen

// calculate national as infection-weighted average
preserve
	// Placeholder: mean of a CI is a weird construct
	collapse (mean) r0_actual r0_lower* r0_upper* [aw=infections], by(day)
	gen national = 1
	tempfile national
	save `national'
restore
append using `national'
replace national = 0 if mi(national)

keep statefip national day r0_actual r0_lower* r0_upper*
order statefip national day r0_actual r0_lower* r0_upper*

compress
isid statefip day, missok
save "$derived\rt\actual_r0s.dta", replace

