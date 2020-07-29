clear all
set_dirs

frame create national
frame national {
	import delimited using "$raw\trends\yougov-chart.csv", clear varn(1) encoding("utf-8")
	gen date = date(substr(datetime,1,10),"YMD")
	format date %td
	
	gen pct_masked = usa / 100
	keep date pct_masked
	gen abbr = "US"
}

// This data is a snapshot from 3/26-4/29
frame create by_state
frame by_state {
	import delimited using "$raw\trends\data-G5kpu.csv", clear varn(1)
	rename x1 state
	merge 1:1 state using "$raw\all_statefip.dta", assert(3) nogen
	
	gen pct_masked = thatselected / 100
	
	keep abbr pct_masked
}

frame create trends
frame trends {
	import delimited using "$raw\trends\mask_search_trends.csv", clear varn(1)
	gen temp = date(date,"YMD")
	drop date
	rename temp date
	format date %td
	
	rename geo abbr
	drop keyword
}

frame create jhu
frame jhu {
	use "$derived\jhu\cases.dta", clear
	
	preserve
		gen pop = active / active_pc
		collapse (sum) pop active, by(date)
		gen active_pc = active/pop
		gen abbr = "US"
		drop active pop
		tempfile natl
		save `natl'
	restore
	appen using `natl'
	
	keep abbr date active_pc	
}

frame copy trends default, replace
keep if abbr=="US"

frlink 1:1 abbr date, frame(jhu)
frget active_pc, from(jhu)

tsset date
egen search_avg_2wk = filter(hits), lags(0/13)
egen inf_avg_2wk = filter(active_pc), lags(0/13)
replace search_avg_2wk = search_avg_2wk / 14
replace inf_avg_2wk = inf_avg_2wk / 14

egen search_avg_1wk = filter(hits), lags(0/6)
egen inf_avg_1wk = filter(active_pc), lags(0/6)
replace search_avg_1wk = search_avg_1wk / 7
replace inf_avg_1wk = inf_avg_1wk / 7

frlink 1:1 date, frame(national)
frget pct_masked, from(national)
drop if mi(pct_masked)

*tw sc pct_masked date || sc hits date, yaxis(2) || sc search_avg_1wk date, yaxis(2) || sc search_avg_2wk date, yaxis(2)
*tw sc pct_masked date || sc active_pc date, yaxis(2) || sc inf_avg_1wk date, yaxis(2) || sc inf_avg_2wk date, yaxis(2)

corr pct_masked hits active_pc *avg_1wk *avg_2wk
reg pct_masked *avg_1wk
reg pct_masked *avg_2wk

reg hits active_pc 

frame copy trends default, replace
drop if abbr=="US"

frlink 1:1 abbr date, frame(jhu)
frget active_pc, from(jhu)
drop jhu

egen dumb = group(abbr)
tsset dumb date
egen search_avg_mo = filter(hits), lags(0/34)
// Only have data through 4/12
egen inf_avg_mo = filter(active_pc), lags(0/17)
drop dumb
replace search_avg_mo = search_avg_mo / 18
replace inf_avg_mo = inf_avg_mo / 35

keep if inlist(date,td(12apr2020),td(29apr2020))
reshape wide search_avg_mo inf_avg_mo hits active_pc, i(abbr) j(date)

keep abbr hits`=td(12apr2020)' search_avg_mo`=td(29apr2020)' active_pc`=td(12apr2020)' inf_avg_mo`=td(29apr2020)'
rename *avg_mo* *[1]avg_mo
rename hits* search_avg_mid
rename active_pc* inf_avg_mid

frlink 1:1 abbr, frame(by_state)
frget pct_masked, from(by_state)

corr pct_masked *avg_mo *avg_mid
reg pct_masked *avg_mo
reg pct_masked *avg_mid


frame copy trends default, replace

frlink 1:1 abbr date, frame(jhu)
frget active_pc, from(jhu)
reg hits active_pc if abbr!="US"
