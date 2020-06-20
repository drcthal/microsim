program define set_dirs
	if "`c(username)'"=="DThal" {
		global root "C:\Projects\microsim"
		global raw "$root\raw"
		global derived "$root\derived"
		global progs "$root\programs"
		global output "$root\output"
	}
	else if "`c(username)'" == "cavery" {
		global root "C:\Users\cavery\Dropbox\covid19"
		global raw "$root\raw"
		global derived "$root\derived"
		global progs "$root\programs"
		global output "$root\output"
	}
	else if "`c(username)'" == "gamcc" {
		global root "C:\Users\gamcc\Dropbox\Research\project_covid19_analysis"
		global raw "$root\data\raw"
		global derived "$root\data\derived"
		global progs "$root\scripts"
		global output "$root\output"
	}
	else {
		di as error "Set your location in set_dirs.ado"
	}
	
	qui adopath ++ "$progs\ados"

	set type double
	set varabbrev off
end
