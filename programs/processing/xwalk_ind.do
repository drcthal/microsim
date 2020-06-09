set_dirs

import excel using "$raw\industry\2017-industry-code-list-with-crosswalk.xlsx", clear cellrange(D4:E355) firstrow
duplicates drop
drop if mi(CensusCode)
drop if regexm(CensusCode,"-")
isid CensusCode

replace NAICSCode = lower(NAICSCode)
replace NAICSCode = subinstr(NAICSCode," and ",", ",.)

gen naicsexclude = regexs(1) if regexm(NAICSCode,"exc[.] ([0-9, ]+)$")
assert !mi(naicsexclude) if regexm(NAICSCode,"exc")
split naicsexclude , p(,)
drop naicsexclude 

replace NAICSCode = regexr(NAICSCode,"exc[.] ([0-9, ]+)","")

gen naicspartial = regexs(2) if regexm(NAICSCode,"(part of|pts?[.]) ([0-9, ]+)$")
assert !mi(naicspartial) if regexm(NAICSCode,"p")
split naicspartial , p(,)
drop naicspartial 

replace NAICSCode = regexr(NAICSCode,"(part of|pts?[.]) ([0-9, ]+)$","")
split NAICSCode, p(,) gen(naicsmatch)
drop NAICSCode

reshape long naicsmatch naicspartial naicsexclude, i(CensusCode)

reshape long naics, i(CensusCode _j) j(type) str
drop _j

drop if mi(naics)
replace naics = trim(itrim(naics))
assert !mi(real(naics))

// merge on all codes
preserve
	import excel using "$raw\industry\6-digit_2017_Codes.xlsx", firstrow clear allstring
	drop if mi(NAICSCode)
	drop NAICSTitle C
	isid NAICSCode
	
	// convert so we can xwalk from any partial match
	assert length(NAICSCode)==6
	expand 5
	bys NAICSCode: gen naics = substr(NAICSCode,1,_n+1)
	tempfile a
	save `a'
restore
joinby naics using `a', unmatched(master)
assert _merge==3
drop _merge

// Drop codes that were excluded
bys CensusCode NAICSCode: egen exclude = max(type=="exclude")
drop if type=="exclude" | exclude==1

// Ignoring the partial matches and the 1:m matches, the naics can count towards multiple census codes
unique NAICSCode

drop type naics exclude
// Need to bring down to 1/NAICS - 
bys NAICSCode: gen _j = _n
reshape wide CensusCode, i(NAICSCode)

compress
isid NAICSCode
save "$derived\industry\naics_census_xwalk.dta", replace

