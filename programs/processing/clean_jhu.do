clear all
set_dirs

// Load JHU map
local i = 0
forval x = `=td(12apr2020)'/`=td(27jul2020)' {
	local f = string(`x',"%tdN-D-CY")
	import delimited using "$raw\jhu\csse_covid_19_daily_reports_us\\`f'.csv", varn(1) clear
	gen date = `x'
	
	local ++i
	tempfile f`i'
	save `f`i''
}

clear all
forval j = 1/`i' {
    append using `f`j''
}

isid province_state date
format date %td

keep province_state date confirmed deaths active
rename province_state state

// master only is territories and cruise ships
merge m:1 state using "$raw\all_statefip.dta", assert(1 3) keep(3) nogen

// load census 2019 pop estimates
preserve
	import delimited using "$raw\acs\SCPRC-EST2019-18+POP-RES.csv", varn(1) clear
	rename state statefip
	rename popestimate2019 pop
	keep statefip pop
	tempfile pop
	save `pop'
restore
merge m:1 statefip using `pop', assert(2 3) keep(3)

foreach x in confirmed deaths active {
	gen `x'_pc = `x' / pop
}

keep state date statefip abbr confirmed* deaths* active*
order state date statefip abbr confirmed* deaths* active*

compress
isid state date
save "$derived\jhu\cases.dta", replace