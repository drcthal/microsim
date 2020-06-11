program define link_frames
	frame put met2013, into(community)
	frame put hhid, into(household)
	
	frame community: duplicates drop
	frame household: duplicates drop
	
	frlink m:1 met2013, frame(community)
	frlink m:1 met2013 indid, frame(work)
	frlink m:1 hhid, frame(household)
end