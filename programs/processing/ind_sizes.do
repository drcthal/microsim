set_dirs

// the by-MSA files have only privately owned data
qui {
	local files: dir "$raw\industry\2019.annual.by_area" files "*MSA.csv", respectcase
	local i = 0
	foreach f of local files {
		import delimited using "$raw\industry\2019.annual.by_area\\`f'", delim(",") clear
		
		// only has private employers
		assert industry_code=="10" if own_code!=5
		keep if own_code==5
		isid industry_code
		
		keep if agglvl_code==48
		assert length(industry_code)==6
		keep area_fips industry_code annual_avg_estabs_count annual_avg_emplvl 
		// I think this indicates junk
		replace annual_avg_estabs_count = 0 if annual_avg_emplvl==0
		
		local ++i
		tempfile f`i'
		save `f`i''
	}
	
	//grab public sector data - national level
	local files: dir "$raw\industry\2019.annual.by_industry" files "2019.annual 92*", respectcase
	foreach f of local files {
		// Only do the 6-digit codes
		assert regexm("`f'","2019.annual (92([0-9]+)?) NAICS")
		local code = regexs(1)
		if length("`code'")!=6 continue
		
		import delimited using "$raw\industry\2019.annual.by_industry\\`f'", delim(",") clear
		isid area_fips own_code
		tostring industry_code, replace
		
		// No overall, instead federal/state/local - convert to overall
		assert inlist(own_code,1,2,3)
		// National and by state and county, but not MSA; just use overall
		assert inlist(agglvl_code, 18,58,78)
		keep if agglvl_code==18
		
		// Don't count places with 0 employees
		replace annual_avg_estabs_count = 0 if annual_avg_emplvl==0
		collapse (sum) annual_avg_estabs_count annual_avg_emplvl, by(industry_code)
		
		local ++i
		tempfile f`i'
		save `f`i''
	}

	clear
	forval j = 1/`i' {
		append using `f`j''
	}
}
isid area_fips industry_code, missok

// Pretend the public sector data is for the first MSA - it'll get retangularized across all
replace area_fips = "C1018" if mi(area_fips)

rename industry_code NAICSCode
merge m:1 NAICSCode using "$derived\industry\naics_census_xwalk.dta", keep(3) nogen

// Some industries match to multiple census codes - expand so that they count separately
reshape long CensusCode, i(area_fips NAICSCode)
drop if mi(CensusCode)

// Now sum together all the NAICS within a census code
collapse (sum) annual_avg_estabs_count annual_avg_emplvl, by(area_fips CensusCode)
count if annual_avg_emplvl==0

gen ind_size = annual_avg_emplvl / annual_avg_estabs_count

// Rectangularize using average from other MSAs, and also impute missings
preserve
	collapse (sum) annual_avg_estabs_count annual_avg_emplvl, by(CensusCode)
	count if annual_avg_emplvl==0
	gen avg_ind_size = annual_avg_emplvl / annual_avg_estabs_count
	drop annual_avg_emplvl annual_avg_estabs_count
	tempfile avg
	save `avg'
restore

fillin area_fips CensusCode
merge m:1 CensusCode using `avg', assert(3) nogen
replace ind_size = avg_ind_size if mi(ind_size)

gen long met2013 = 10*real(substr(area_fips,2,.))

// Append on ind sizes based on the average for the fips codes masquerading as MSAs that we'll use in the sims
preserve
	use "$raw\all_statefip.dta", clear
	gen one = 1
	tempfile state
	save `state'
	
	use `avg', clear
	gen one = 1
	joinby one using `state'
	drop one
	
	rename statefip met2013
	rename avg_ind_size ind_size
	tempfile statelvl
	save `statelvl'
restore
append using `statelvl'

// Railroad workers, for some reason, are always missing
count if mi(ind_size)
assert (CensusCode=="6080") == (mi(ind_size))
// Assign RR the mean from the other transport codes
preserve
	keep if inrange(real(CensusCode),6070,6390)
	collapse (sum) annual_avg_estabs_count annual_avg_emplvl, by(met2013)
	gen avg_transp_size = annual_avg_emplvl / annual_avg_estabs_count
	
	qui: summ annual_avg_estabs_count 
	local tot_estabs = r(sum)
	qui: summ annual_avg_emplvl 
	local avg_avg_transp_size = r(sum) / `tot_estabs'
	
	keep met2013 avg_transp_size 
	
	tempfile transp
	save `transp'
restore
merge m:1 met2013 using `transp', assert(3) nogen
replace ind_size = avg_transp_size if CensusCode=="6080"
replace ind_size = `avg_avg_transp_size' if CensusCode=="6080" & mi(ind_size)

destring CensusCode, gen(ind)

keep met2013 ind ind_size
assert !mi(ind_size)

isid met2013 ind
compress
save "$derived\industry\avg_size_by_ind_msa.dta", replace
