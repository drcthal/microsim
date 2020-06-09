program define create_inds
	frame copy person industry, replace
	
	frame industry {
		drop if ind==0

		gen n = 1
		collapse (sum) n, by(met2013 ind)
		merge 1:1 met2013 ind using "$derived\industry\avg_size_by_ind_msa.dta", assert(2 3) keep(3) nogen
		
		// This method will always work, but it's really slow (create a completely unecessarily rectangular file then reshape)
		if 0 {
			gen tot = 0
			local i = 0
			count if tot<n
			local n = r(N)
			while `n' != 0 {
				local ++i
				// This will create a weird truncated case. e.g. if my size is 50 and N is 100, I may do 48, 51, 1 which is not reasonable
				gen employees`i' = min(n-tot, max(1,rpoisson(ind_size)))
				replace tot = tot + employees`i'
				count if tot<n
				local n = r(N)
			}
			drop n ind_size tot
			reshape long employees, i(met2013 ind)
		}
		
		// Instead this should always work, we create enough industries
		// Todo: change to a smaller expand, but do it in a while loop that continues.
		expand max(20, ceil(3 * n/ind_size))
		
		sort met2013 ind
		gen employees = rpoisson(ind_size)
		drop ind_size
		
		by met2013 ind: gen x = sum(cond(_n==1,0,employees[_n-1]))
		replace employees = min(n - x, employees)
		
		drop if employees <=0
		
		by met2013 ind: egen check = total(employees)
		
		assert check==n
		
		keep met2013 ind employees
		gen indid = _n
	}	
end
