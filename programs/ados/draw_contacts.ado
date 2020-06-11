program define draw_contacts
	syntax, day(int) [c_spread(real -1) w_spread(real -1) h_spread(real -1) cross_msa_weight(real 0.99999) relative_work_weight(real 0.99) debug]
	
	local vol = cond(!mi("`debug'"),"noi","qui")
	`vol' {
		if `h_spread' == -1 {
			// go from chris's 15% number
			// if p = daily chance of catching it, and 15% = cumulative chance over 7 days,
			// then .85 = (1-p)^7
			local h_spread = 1 - exp(ln(.85)/7)
		}
		// Assume community and work chance are 1/2 of that if not specified
		if `c_spread' == -1 local c_spread = (1 - exp(ln(.85)/7)) / 2
		if `w_spread' == -1 local w_spread = (1 - exp(ln(.85)/7)) / 2
		
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
		
		frame put met2013 infectious perwt tau_c tau_w , into(`community')
		frame `community' {
			// Each person's community contacts will be pulled from their MSA
			// So calculate the probability that a person you meet during community-time is infected
			// This is weighted by the time each person spends in the community, plus the time spent at work for people in jobs like retail etc
			// For now we assume all jobs are community-facing
			
			// also calculate a version that uses community-only time. 
			// This will be used for both cross-MSA spreading (i.e. assume people only travel during their own time?)
			// And also for work interactions (e.g. at work I interact with my coworkers plus customers)
			// Maybe that's dumb and it should just all be non-home time (e.g. at work I interact with customers plus deliveries etc; or people travel for work)	
			
			gen community_weight = (tau_c + tau_w) * perwt
			gen community_only_weight = tau_c * perwt
			gen community_infectious = infectious * community_weight
			gen community_only_infectious = infectious * community_only_weight
			// calculate the MSA-wide infection rate
			gcollapse (sum) community_infectious community_weight community_only_infectious community_only_weight, by(met2013)
			gen community_only_infectious_chance = community_only_infectious / community_only_weight 
			
			// For infection during community phase, include cross-msa spread by taking the average of your MSA plus all others, weighted very heavily to yours
			// These include the data from your own MSA, so subtract that out later
			// TODO: could replace with distance matrix
			egen total_community_infectious = total(community_only_infectious)
			egen total_community_weight = total(community_only_weight)
			
			gen community_infectious_chance = `cross_msa_weight' * (community_infectious / community_weight) + ///
										(1 - `cross_msa_weight') * ((total_community_infectious - community_only_infectious) / (total_community_weight - community_only_weight))
		}
		
		frame put met2013 indid infectious perwt tau_w, into(`work' )
		frame `work' {
			// workplace contacts pulled from your workplace, and from community for community-facing jobs?
			gen work_weight = tau_w * perwt
			gen work_infectious = infectious * work_weight
			gcollapse (sum) work_weight work_infectious, by(met2013 indid)
			frlink m:1 met2013, frame(`community')
			frget community_only_infectious_chance, from(`community')
			
			// Assume contacts with workplace are much more likely, so upweight that
			gen work_infectious_chance = `relative_work_weight' * (work_infectious / work_weight) + ///
									(1 - `relative_work_weight') * community_only_infectious_chance
		}
		
		frame put hhid infectious, into(`household')
		frame `household' {
			// No weighting etc, you just come into contact with all HH members, so we only care about the # infected in the house
			// This is wrong for people who are infected (includes self) but we don't care, they're already sick
			// only care about positives
			keep if infectious
			gcollapse (sum) household_infectious = infectious, by(hhid)
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
			}
		}
		
		// In terms of optimization, what's better for frames? e.g. do I do everything in a tempframe and then relink each time?
		// Or is it faster to have a permanent link to the industry file, and the update tempframe links to the ind file
		// then I'm keeping stable the link to the person file, and only relinking the industries, which has a way lower N, each time?
		// Ditto MSA connections. So basically keep static many:few link, and reupdate few:few links? Could also save a history that way, e.g. the permanent few keeps the record of daily chances
		// Now draw contacts
		frame person {
			tempvar community_infectious_chance community_contacts community_infectious ///
					work_infectious_chance work_contacts work_infectious household_infectious /// pr_infected
					infected_c infected_w infected_h
			
			gen `community_contacts' = rpoisson(tau_c * N_c)
			frget `community_infectious_chance' = community_infectious_chance_`day', from(community)
			gen `community_infectious' = cond(`community_contacts' > 0 & !mi(`community_contacts'), rbinomial(`community_contacts', `community_infectious_chance'), 0)
			
			gen `work_contacts' = rpoisson(tau_w * N_w)
			frget `work_infectious_chance' = work_infectious_chance_`day', from(work)
			gen `work_infectious' = cond(`work_contacts' > 0 & !mi(`work_contacts'), rbinomial(`work_contacts', `work_infectious_chance'), 0)
			
			frget `household_infectious' = household_infectious_`day', from(household)
			
			// Do we care about tracing source of infection?
			// e.g. gen infected_cwh = rbinomial(`cwh_infectious',`c_spread')>0, gen replace day_infected = infected_c|w|h ==1
			*gen `pr_infected' = 1 - binomial(`community_infectious',0,`c_spread') * binomial(`work_infectious',0,`w_spread') * binomial(`household_infectious',0,`h_spread')
			*assert !mi(`pr_infected')
			gen `infected_c' = max(rbinomial(`community_infectious', `c_spread'),0) > 0 // rbinomial(0,x) gives missing rather than 0, thankfully max(.,0) is somehow 0
			gen `infected_w' = max(rbinomial(`work_infectious', `w_spread'),0) > 0
			gen `infected_h' = max(rbinomial(`household_infectious', `h_spread'),0) > 0
			
			replace day_infected = `day' if mi(day_infected) & (`infected_c' | `infected_w' | `infected_h')
			replace infection_source = `infected_c'*"c" + `infected_w'*"w" + `infected_h'*"h" if mi(infection_source)
		}
	}
end
