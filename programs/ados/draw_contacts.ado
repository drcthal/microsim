program define draw_contacts
	syntax, day(int) [c_spread(real -1) w_spread(real -1) h_spread(real -1) ///
					c_spread_mod(real 1) w_spread_mod(real 1) h_spread_mod(real 1) ///
					cross_msa_weight(real 0.9999) mask_factor(real 0.33) debug]
	
	local vol = cond(!mi("`debug'"),"noi","qui")
	`vol' {
		// If not specified, back spread rate out from Chris's 15% number
		// So 15% = cuml over 7 days, so .85 = (1-p)^7
		foreach x in c w h {
			if ``x'_spread'==-1 local `x'_spread = (1 - exp(ln(.85)/7))
			// alternative way of specifying: use that assumption and apply a modifier
			local `x'_spread = ``x'_spread' * ``x'_spread_mod'
		}
		
		tempname community work household
		
		/* NB: the community and work stuff is kinda whacky. rather than draw actual individuals
			I'm going to calculate the weighted average chance that an individual you do come into contact with is infected
			some issues: this includes yourself (although you should be a vanishingly small contribution for large workplaces or the community)
			in the workplace that's less true, I could be a lot of my job if it's a 5-person workplace.
			For infected people this doesn't matter, but for the uninfected this does, 
			e.g. in a 2 person workplace where the other guy is infected 100% of my coworkers are sick, not 50%
			
			Another issue is the N, e.g. we weight your coworkers way higher, 
			but if I have a 2 person workplace and I have 20 worktime contacts, it can't be that more than 2 of my contacts are from work
			
			optimization - can we speed up by ignoring some irrelevant cases? e.g. when taking the sum of infected across hh, keep infected first and we'll have a smaller set to collapse down
			don't need to do anything for HH with no infected anyways
			or industries, with no indivs at the place infected, just add in the msa interaction piece?
			not quite, because there I do need to follow the total weight of the uninfected, so they crowd out other interactions
			
			related - currently there's nothing altering the number of contacts. e.g. if I have 8 community hours I always interact with N_c people - should probably have that scale to total weight that's not locked down?
			e.g. it's N_c if the MSA is going as usual, but if the MSA is 50% locked down it's lower?
		*/
		
		frame put met2013 infectious perwt N_w_c N_c tau_c tau_w  base_tau_c base_tau_w, into(`community')
		frame `community' {
			// Each person's community contacts will be pulled from their MSA
			// So calculate the probability that a person you meet during community-time is infected
			// Each person is weighted by their number of contacts in the community during community time and work time
			
			gen community_weight = ((N_c * tau_c / base_tau_c) + cond(base_tau_w!=0, N_w_c * tau_w / base_tau_w, 0)) * perwt
			gen community_infectious = infectious * community_weight
			// calculate the MSA-wide infection rate
			gcollapse (sum) community_infectious community_weight, by(met2013)
			
			// For infection during community phase, include cross-msa spread by taking the average of your MSA plus all others, weighted very heavily to yours
			// These include the data from your own MSA, so subtract that out later
			// TODO: could replace with distance matrix
			egen total_community_infectious = total(community_infectious)
			egen total_community_weight = total(community_weight)
			
			gen community_infectious_chance = `cross_msa_weight' * (community_infectious / community_weight) + ///
										(1 - `cross_msa_weight') * ((total_community_infectious - community_infectious) / (total_community_weight - community_weight))
		}
		
		frame put met2013 indid infectious perwt N_w_w tau_w base_tau_w, into(`work' )
		frame `work' {
			// workplace contacts pulled from your workplace, with indivs weighted by how many coworker contacts they have
			// NB: given workplace sizes this may be nonsense, e.g. if I have a workplace of size 10 yet a number of work contacts of 12.
			// But the relative magnitudes are what matter
			gen work_weight = (N_w_w * tau_w / base_tau_w) * perwt
			gen work_infectious = infectious * work_weight
			gcollapse (sum) work_weight work_infectious, by(met2013 indid)
			
			gen work_infectious_chance = (work_infectious / work_weight) 
		}
		
		frame put hhid infectious, into(`household')
		frame `household' {
			// No weighting etc, you just come into contact with all HH members, so we only care about the # infected in the house
			// This is wrong for people who are infected (includes self) but we don't care, they're already sick
			// only care about positives
			keep if infectious
			if _N==0 {
				// can't collapse but need to frget, so create dummy data
				drop _all
			    set obs 1
				gen hhid = -1
				gen household_infectious = 0
			}
			else gcollapse (sum) household_infectious = infectious, by(hhid)
		}
		
		// Drag values over to the permament cwh frames
		local community_link met2013
		local work_link met2013 indid
		local household_link hhid
		foreach x in community work household {
			frame `x' {
				frlink 1:1 ``x'_link', frame(``x'')
				if "`x'"=="household" {
					frget `x'_infectious_`day' = `x'_infectious, from(``x'')
					replace `x'_infectious_`day' = 0 if mi(`x'_infectious_`day')
				}
				else {
					frget `x'_infectious_chance_`day' = `x'_infectious_chance, from(``x'')
				}
				if "`x'"=="community" {
					// TODO: completely arbitrary: assume for every 1pp change in infection rate, mask wearing goes up 10pp
				    gen pct_masked_`day' = max(0,min(1, pct_masked + 10*(`x'_infectious_chance_`day' - `x'_infectious_chance_1)))
				}
			}
		}
		
		// Now draw contacts
		frame person {
			tempvar community_infectious_chance community_contacts community_infectious pct_masked is_masked ///
					work_infectious_chance work_contacts work_infectious household_infectious /// pr_infected
					c_spread_rate w_spread_rate infected_c infected_w infected_h
			
			gen `community_contacts' = rpoisson(N_c * tau_c / base_tau_c + cond(base_tau_w!=0, N_w_c * tau_w / base_tau_w, 0))
			frget `community_infectious_chance' = community_infectious_chance_`day', from(community)
			frget `pct_masked' = pct_masked_`day', from(community)
			gen `community_infectious' = cond(`community_contacts' > 0 & !mi(`community_contacts'), rbinomial(`community_contacts', `community_infectious_chance'), 0)
			
			gen `work_contacts' = rpoisson(N_w_w * tau_w / base_tau_w)
			frget `work_infectious_chance' = work_infectious_chance_`day', from(work)
			gen `work_infectious' = cond(`work_contacts' > 0 & !mi(`work_contacts'), rbinomial(`work_contacts', `work_infectious_chance'), 0)
			
			frget `household_infectious' = household_infectious_`day', from(household)
			
			// Determine if individual is masked
			// TODO: this currently just checks am I masked, and says nothing about the other people.
			gen `is_masked' = runiform() <= `pct_masked'
			gen `c_spread_rate' = cond(`is_masked'==1,`c_spread' * `mask_factor',`c_spread')
			gen `w_spread_rate' = cond(`is_masked'==1,`w_spread' * `mask_factor',`w_spread')
			
			// Do we care about tracing source of infection?
			// e.g. gen infected_cwh = rbinomial(`cwh_infectious',`c_spread')>0, gen replace day_infected = infected_c|w|h ==1
			*gen `pr_infected' = 1 - binomial(`community_infectious',0,`c_spread') * binomial(`work_infectious',0,`w_spread') * binomial(`household_infectious',0,`h_spread')
			*assert !mi(`pr_infected')
			gen `infected_c' = max(rbinomial(`community_infectious', `c_spread_rate'),0) > 0 // rbinomial(0,x) gives missing rather than 0, thankfully max(.,0) is somehow 0
			gen `infected_w' = max(rbinomial(`work_infectious', `w_spread_rate'),0) > 0
			// Assume no masks at home
			gen `infected_h' = max(rbinomial(`household_infectious', `h_spread'),0) > 0
			
			replace day_infected = `day' if mi(day_infected) & (`infected_c' | `infected_w' | `infected_h')
			replace infection_source = `infected_c'*"c" + `infected_w'*"w" + `infected_h'*"h" if mi(infection_source)
		}
	}
end
