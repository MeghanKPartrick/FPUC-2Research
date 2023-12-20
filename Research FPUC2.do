global origin "~/Dropbox/ECON580-2023DB"
capture cd "/Users/meghanpartrick/Documents/ECON580-Personal"

capture cd "~\Dropbox\CPS-shared"
use ECON580_cps_covid.dta, clear

***************************************************************************
*					Create variables
***************************************************************************

keep if year==2021
xtset inid date	

// Eligibility
tab whyunemp
tab whyunemp, nol
recode whyunemp 0=. 1/2=1 3/6=0, gen(ubeligible)
label var ubeligible "Eligible for unemployment benefits"
label define ubeligible 1 "UI eligible" 0 "UI ineligible"
label values ubeligible ubeligible

// Hours of work variable
recode uhrsworkt 997=. 999=.
gen fhours=f.uhrsworkt		// future hours next month in t+1
label var fhours "Hours worked in t+1"

// Employment variable
gen femployed=f.employed		// employment next month in t+1
label var femployed "Employment in t+1"

// Age group
gen age_cat = 0
replace age_cat = 1 if age>=23
label var age_cat "Age 23-64"

// Policy
gen post=1 if daydate>fpuc2_end
replace post=0 if daydate<=fpuc2_end
label define post 1 "Post-policy" 0 "Before policy" 
label values post post
label var post "FPUC-2 early withdrawal"

// Sample
keep if ubeligible<.
gen s=1 if month<9

// Vectors
global Z "female i.race i.foreign i.educ married nchild"
global FE "i.statefip i.month"
global X "ubeligible"
global M "age_cat"
sum fhours femployed $X $M $Z $FE

***************************************************************************
*					Summary statistics
***************************************************************************

// Summary statistics
reg post $M $Z if ubeligible==1, robust
outreg2 using summary_stat.xls, sum replace dec(3) label cttop("UI eligible") 
reg post $M $Z if ubeligible==0, robust
outreg2 using summary_stat.xls, sum append dec(3) label cttop("UI ineligible") 

bys ubeligible: sum fhours femployed 

// Hours over life cycle
reg fhours ubeligible##c.age##c.age, robust
margins ubeligible, at(age=(20(5)60))  // this line calculates predicted Y over the life cycle by UI status
marginsplot, xdimension(at(age)) recast(line) xlabel(20(5)60) title("Predicted Hours per Week in t+1") ytitle("hours") graphregion(fcolor(white)) plotopts(lwidth(medthick)) ciopts(lwidth(vvthin)) legend(region(fcolor(white)) region(lcolor(white))) name(predicted_by_age, replace)

// Employment over life cycle
reg femployed ubeligible##c.age##c.age, robust
margins ubeligible, at(age=(20(5)60))  // this line calculates predicted Y over the life cycle by UI status
marginsplot, xdimension(at(age)) recast(line) xlabel(20(5)60) title("Predicted Return to Work in t+1") ytitle("probability points") graphregion(fcolor(white)) plotopts(lwidth(medthick)) ciopts(lwidth(vvthin)) legend(region(fcolor(white)) region(lcolor(white))) name(predicted_by_age, replace)

***************************************************************************
*					Event Study
***************************************************************************

gen policymonth = month(fpuc2_end)
gen timeline = month - policymonth+10
label define timeline 5 "-5" 6 "-4" 7 "-3" 8 "-2" 9 "-1" 10 "0" 11 "1" 12 "2" 13 "3" 14 "4" 15 "5", modify
label values timeline timeline

reg femployed i.timeline##ubeligible $M $Z $FE if s==1 & timeline>4 & timeline<16, robust
margins i.timeline#ubeligible, noestimcheck   
marginsplot, xdimension(timeline) ytitle("") title("Predicted Employment in t+1") graphregion(fcolor(white)) ciopts(lwidth(vthin)) legend(region(color(white)) ) xline(10) name(fig3, replace)

reg fhours i.timeline##ubeligible $M $Z $FE if s==1 & timeline>4 & timeline<16, robust
margins i.timeline#ubeligible, noestimcheck   
marginsplot, xdimension(timeline) ytitle("") title("Predicted Hours in t+1") graphregion(fcolor(white)) ciopts(lwidth(vthin)) legend(region(color(white)) ) xline(10) name(fig4, replace)

graph combine fig3 fig4, graphregion(fcolor(white)) ysize(4) xsize(8) name(event, replace)


***************************************************************************
*					OLS
***************************************************************************

reg femployed $X $M $Z $FE, robust
outreg2 using ols.xls, dec(3) replace drop($FE) label

reg femployed $X##$M $Z $FE, robust 
outreg2 using ols.xls, dec(3) append drop($FE) label

reg fhours $X $M $Z $FE, robust
outreg2 using ols.xls, dec(3) append drop($FE) label

reg fhours $X##$M $Z $FE, robust 
outreg2 using ols.xls, dec(3) append drop($FE) label


***************************************************************************
*				 2-way	DID
***************************************************************************

reg femployed i.post $X $M $Z $FE if s==1, robust
outreg2 using did.xls, replace dec(3) drop($FE) label

reg fhours i.post $X $M $Z $FE if s==1, robust
outreg2 using did.xls, append dec(3) drop($FE) label


***************************************************************************
*				 Triple difference
***************************************************************************

clonevar group=ubeligible
reg femployed
outreg2 using did2fe_short.xls, replace ctitle(fake) nocons
outreg2 using did2fe_long.xls, replace ctitle(fake) nocons
foreach v in femployed fhours  {
	reg `v' i.post##group $M $Z $FE if s==1, robust
	outreg2 using did2fe_short.xls, append dec(3) label keep(i.post##group) addtext(State FE, Yes, Month FE, Yes, Controls, Yes) nocons
	outreg2 using did2fe_long.xls, append dec(3) label drop($FE) addtext(State FE, Yes, Month FE, Yes) nocons
}

*Visualize 
qui reg femployed i.post##group $M $Z $FE if s==1, robust
margins i.group, at(post=(0(1)1)) 
marginsplot, xdimension(post) ytitle("probability") title("Predicted Employment in t+1") graphregion(fcolor(white)) ciopts(lwidth(vthin)) legend(region(color(white)) label(1 "Before") label(2 "After")) name(fig1, replace)

qui reg fhours i.post##group $M $Z $FE if s==1, robust
margins i.group, at(post=(0(1)1)) 
marginsplot, xdimension(post) ytitle("probability") title("Predicted Hours in t+1") graphregion(fcolor(white)) ciopts(lwidth(vthin)) legend(region(color(white)) label(1 "Before") label(2 "After")) name(fig2, replace)

graph combine fig1 fig2, graphregion(fcolor(white)) ysize(4) xsize(8)

***************************************************************************
*					DID with IPW
***************************************************************************

probit group $M $Z i.statefip if post==0 & s==1 	// note no time FEs
predict pscore 													
gen ipw=1/(1-pscore) if group==0
replace ipw=1/pscore if group==1
label var pscore "Propensity score"
label var ipw "Inverse Propensity Weight"

foreach v in femployed fhours  {
	reg `v' i.post##group $M $Z $FE if s==1 [pw=ipw], robust
	outreg2 using did2fe_short.xls, append dec(3) label keep(i.post##group) addtext(State FE, Yes, Month FE, Yes, Controls, Yes) nocons cttop(ipw)
	outreg2 using did2fe_long.xls, append dec(3) label drop($FE) addtext(State FE, Yes, Month FE, Yes) nocons cttop(ipw)
}

***************************************************************************
*					Map
***************************************************************************

use ECON580_cps_covid.dta, clear
keep if year==2021
rename statefip stateid

recode whyunemp 0=. 1/2=1 3/6=0 , gen(ubeligible)
label var ubeligible "Eligible for unemployment benefits"
label define ubeligible 1 "UI recipient" 0 "UI non-recipient"
label values ubeligible ubeligible

collapse ubeligible [pw=wtfinl], by(stateid)
replace ubeligible=ubeligible*100
label var ubeligible "% UI Eligible Among Unemployed, 2021"
xtset, clear
tempfile state_data					
save `state_data'

use "usastates.dta", clear
destring STATEFP, gen(stateid)
merge 1:1 stateid using `state_data'
tab NAME if _m==1
drop if _m==1
drop _m
grmap, activate
spset, modify shpfile(usastates_shp)
drop if inlist(NAME, "Alaska", "Hawaii")
format ubeligible %3.1f			// format values**
grmap ubeligible, clnumber(4) name(map1, replace) title("% UI Eligible Among Unemployed, 2021")

***************************************************************************
*					Panel view
***************************************************************************

use "$origin/Policies/UItracker_monthly.dta", clear

keep if year==2021
gen post=2 if saturday> fpuc2_end
replace post=1 if  saturday<=fpuc2_end
replace post=3 if  saturday>td(06sep2021)
panelview post, i(statename) t(month) type(treat) xtitle("Month 2021",size(vsmall)) ytitle("State",size(vsmall)) title("FPUC-2 Policy Timeline") bytiming legend(label(1 "FPUC-2 Benefits") label(2 "Withdrew early") label(3 "Program ended")) mycolor(Reds) name(policy1, replace)

