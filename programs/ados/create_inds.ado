program define create_inds
	syntax , [debug]
	
	local vol = cond(!mi("`debug'"),"noi","qui")
	`vol' {
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
			expand max(5, ceil(1.5 * n/ind_size))
			gen employees = rpoisson(ind_size)
			bys met2013 ind: egen check = total(employees)
			
			count if check<n
			local needmore = r(N)
			while `needmore'>0 {
			    expand 2 if check<n, gen(temp)
				replace employees = rpoisson(ind_size) if temp==1
				drop check 
				bys met2013 ind: egen check = total(employees)
				count if check<n
				local needmore = r(N)
				drop temp
			}
			
			sort met2013 ind
			
			drop check ind_size
			
			by met2013 ind: gen x = sum(cond(_n==1,0,employees[_n-1]))
			replace employees = min(n - x, employees)
			
			drop if employees <=0
			
			by met2013 ind: egen check = total(employees)
			
			assert check==n
			
			keep met2013 ind employees
			gen indid = _n
			
			preserve
				expand employees
				bys met2013 ind (indid): gen merger = _n
				keep met2013 ind indid merger
				tempfile indmerge
				save `indmerge'
			restore
		}
		
		frame person {
			bys met2013 ind (perid): gen merger = _n
			merge 1:1 met2013 ind merger using `indmerge', assert(1 3)
			assert _merge==3 if ind!=0
			drop merger _merge
		}
		
		
		// Now figure out students
		// Count the total number of students in each MSA
		tempname stus schs
		frame copy person `stus', replace
		frame `stus' {
			keep if age>=5 & age<=18 & ind==0
			gen n_stu = 1
			collapse (sum) n_stu, by(met2013)
		}
		
		frame copy industry `schs', replace
		
		// Apportion students in fixed ratio to staff across all elementary/secondary schools
		frame `schs' {
			keep if ind==7860
			bys met2013: egen n_emp = total(employees)
			bys met2013: gen n_sch = _N
			
			frlink m:1 met2013, frame(`stus')
			assert r(unmatched)==0
			
			frget n_stu = n_stu, from(`stus')
			
			gen students = round(n_stu * employees / n_emp)
			
			// Rounding will cause us to be off slightly
			bys met2013: egen check = total(students)
			// add/subtract from schools
			bys met2013 (indid): replace students = students - sign(check-n_stu) if _n <= abs(check-n_stu)
			drop check
			bys met2013: egen check = total(students)
			assert check==n_stu
			
			assert students!=0
		}
		
		frame industry {
			frlink 1:1 met2013 indid, frame(`schs')
			frget students = students, from(`schs')
			replace students = 0 if ind!=7860
			
			order met2013 ind indid employees students
			
			// Assign
			preserve
				keep if ind==7860
				expand students
				bys met2013 (indid): gen merger = _n
				gen isstu = 1
				rename indid schid
				keep met2013 schid isstu merger 
				tempfile schmerge
				save `schmerge'
			restore
		}
		
		frame person {
			gen isstu = age>=5 & age<=18 & ind==0
			bys met2013 isstu (perid): gen merger = _n
			merge 1:1 met2013 isstu merger using `schmerge', assert(1 3)
			assert _merge==3 if isstu==1
			replace indid = schid if isstu
			drop merger isstu _merge schid
		}	
	}	
end
