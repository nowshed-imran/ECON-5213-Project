/*******************************************************************************

    ECON 5213 Replication and Extension Project
    Submitted by: Nowshed Hossain Imran

    Paper replicated:
        Paaso, Mikael, Vesa Pursiainen, and Sami Torstila. 2025. "Entrepreneur
        Debt Aversion and Financing Decisions: Evidence from COVID-19 Support
        Programs." Management Science 72 (5): 4474-4498.
    Target exhibits: Table 1, Table 3 Panel A, Table 4 and Table 10 Panel A

    Required data files (in data/raw/paaso/), from the authors' Management
    Science replication package (used with the authors' permission):
        cleaned_survey.dta        survey of Finnish SMEs, May to June 2020
        2023_cleaned_survey.dta   follow-up survey, April 2023 (table 10)
    The data are not in the repository. Download the replication package
    from the paper's page, https://doi.org/10.1287/mnsc.2022.03007, unzip it
    and copy the two files from its Data/ folder into data/raw/paaso/.

    BEFORE YOU BEGIN
        1. keep this do-file in the project folder, next to data/, output/
           and report/.
        2. open that folder in stata (File > Change Working Directory), or
           type: cd "path to the project folder"
        3. run the whole file. it installs estout (esttab, estpost) if it is
           missing.

    AI use: The study design, hypotheses, model choices and interpretation are my
        own. The code was written with the help of Claude (Anthropic), which I
        used to build this do-file from the course do-files, find and fix
        errors, and implement the extension tests. I have reviewed the code
        extensively and would appreciate any suggestions for improvement.

    NOTE: every table lands in output/. interpretations are in the report.

    CONTENTS
        0. check files
        1. the data
        2. table 1: summary statistics
        3. estimation sample (singletons)
        4. replication: table 3 panel a, table 4, table 10 panel a
        5. extension
           E1 probit and logit vs the linear probability model     (ch 17)
           E2 heteroskedasticity tests and wls for the lpm         (ch 8)
           E3 functional form of the debt aversion score           (ch 6, 7)
           E4 measurement error: instrumental variables            (ch 15, final version)
           E5 differences across groups: chow-type tests           (ch 7)
           E6 the 2023 sample with probit                          (ch 17)
        6. key numbers
        7. figures for the report

*******************************************************************************/

version 15.1
clear all
set more off
capture log close
capture mkdir "output"
log using "output/paaso_replication_output.log", text replace


/*==============================================================================
    0. CHECK THAT THE DATA FILES ARE IN PLACE
    The two survey files come from the replication package of Paaso,
    Pursiainen and Torstila (2025), available on the paper's page:
    https://doi.org/10.1287/mnsc.2022.03007
==============================================================================*/

foreach f in "data/raw/paaso/cleaned_survey.dta" "data/raw/paaso/2023_cleaned_survey.dta" {
    capture confirm file "`f'"
    if _rc != 0 {
        display as error "stata cannot find `f'"
        display as error "open the project folder first (see BEFORE YOU BEGIN)."
        exit 601
    }
}

* esttab and estpost come from the estout package
capture which esttab
if _rc != 0 ssc install estout


/*==============================================================================
    1. THE DATA
    Unit of observation: one firm (the entrepreneur who answered the survey)
==============================================================================*/

use "data/raw/paaso/cleaned_survey.dta", clear
describe
count

* the file has 917 firms; regressions use the firms with non-missing answers
assert r(N)==917

* the attitude controls used in every regression with fixed effects
global controls "risk_appetite optimism distrust_people distrust_banks"

* fixed effects (dummy variables) used in the paper: firm size, industry,
* survival expectation, expected survival time, field and level of education
global fe2 "n_employees industry firm_survival survival_time edu_sector education"
* table 4, columns 3 and 6 also add the covid sales impact and the expected
* time to return to normal
global fe3 "n_employees industry firm_survival survival_time sales_impact time_to_normal edu_sector education"

global fe2_dummies "i.n_employees i.industry i.firm_survival i.survival_time i.edu_sector i.education"
global fe3_dummies "i.n_employees i.industry i.firm_survival i.survival_time i.sales_impact i.time_to_normal i.edu_sector i.education"

label variable has_debt              "Has debt (0/1)"
label variable had_debt_5y           "Has had debt in the past 5 years (0/1)"
label variable high_debt_aversion    "High debt aversion (0/1)"
label variable debt_aversion         "Debt aversion (0 to 10)"
label variable applied_new_bank_loan "Applied for new bank loan during COVID-19 (0/1)"

* look at the data (as in the ch01 do-file)
describe has_debt had_debt_5y applied_new_bank_loan high_debt_aversion debt_aversion $controls municipality
codebook has_debt had_debt_5y applied_new_bank_loan high_debt_aversion
summarize has_debt had_debt_5y applied_new_bank_loan high_debt_aversion debt_aversion $controls
summarize debt_aversion, detail
list has_debt applied_new_bank_loan high_debt_aversion debt_aversion $controls in 1/10, clean

tabulate high_debt_aversion, missing
tabulate debt_aversion, missing
* high debt aversion is a score of 8 or more
tabulate debt_aversion high_debt_aversion

* the raw version of the main result: share with debt by debt aversion group
tabstat has_debt had_debt_5y applied_new_bank_loan, by(high_debt_aversion) ///
    statistics(n mean sd min max) columns(statistics)

* variables the authors removed before posting the data (orbis ratios and
* self-reported sales and debt), so table 3 panel b cannot be replicated
foreach v in total_debt_to_assets net_debt_to_ebit net_debt_to_turnover cash_to_assets ///
    sales_reply_k_w debt_reply_k_w {
    capture confirm variable `v'
    if _rc display "`v': not in the posted data"
}

* the 2023 follow-up survey used in table 10
preserve
use "data/raw/paaso/2023_cleaned_survey.dta", clear
describe
count
restore


/*==============================================================================
    2. TABLE 1: SUMMARY STATISTICS
==============================================================================*/

global firm    "emp_1 emp_24 emp_59 emp_1050 emp_51250 emp_250 has_debt had_debt_5y"
global traits  "high_debt_aversion debt_aversion risk_appetite optimism distrust_people distrust_banks stress_much"
global actions "applied_new_bank_loan applied_any_loan applied_direct_support applied_equity has_laid_off has_furloughed canceled_investments unpaid_ent_comp unpaid_taxes unpaid_wages"

estpost summarize $firm $traits $actions, detail
esttab using "output/table1_summary_stats.csv", replace ///
    cells("mean(fmt(3)) sd(fmt(3)) p10(fmt(3)) p50(fmt(3)) p90(fmt(3)) count(fmt(0))") ///
    noobs nonumber nomtitle label


/*==============================================================================
    3. ESTIMATION SAMPLE FOR THE FIXED EFFECTS REGRESSIONS
    the paper uses reghdfe, which drops "singletons": a firm that is the only
    one in its category of some fixed effect. its dummy fits that firm exactly,
    so the firm adds nothing to the estimate. to get the same sample with -reg-
    and dummy variables, i mark the estimation sample and drop singletons
    until none are left.
==============================================================================*/

capture program drop mark_sample
program define mark_sample
    syntax varlist, fe(varlist) gen(name)
    marksample touse
    markout `touse' `fe'
    local more 1
    while `more' {
        local more 0
        foreach f of local fe {
            tempvar n
            quietly bysort `touse' `f': gen `n' = _N if `touse'
            quietly count if `touse' & `n'==1
            if r(N) > 0 {
                quietly replace `touse' = 0 if `n'==1
                local more 1
            }
            drop `n'
        }
    }
    gen byte `gen' = `touse'
end


/*==============================================================================
    4. REPLICATION
    Question: do entrepreneurs with higher debt aversion use less debt, and
    were they less likely to apply for a bank loan during COVID-19?
    Model: linear probability model (OLS on a 0/1 outcome)
    Standard errors: clustered by municipality (44 clusters)
==============================================================================*/

/*--- (a) Table 3, Panel A: current and past debt use ---*/
* H1: entrepreneurs with high debt aversion are less likely to have debt
*     now and to have had debt in the past five years.

local i = 0
foreach y in has_debt had_debt_5y {
    foreach x in high_debt_aversion debt_aversion {
        local i = `i' + 1
        * without controls or fixed effects
        eststo t3_`i'a: reg `y' `x', vce(cluster municipality)
        * with controls and fixed effects
        mark_sample `y' `x' $controls municipality, fe($fe2) gen(s_t3_`i')
        eststo t3_`i'b: reg `y' `x' $controls $fe2_dummies if s_t3_`i', vce(cluster municipality)
    }
}

* column order as in the paper: (1) to (8)
esttab t3_1a t3_1b t3_2a t3_2b t3_3a t3_3b t3_4a t3_4b ///
    using "output/table3a_debt_use.csv", replace ///
    keep(high_debt_aversion debt_aversion $controls) ///
    b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) stats(N r2, fmt(0 3)) ///
    mtitles("Has debt" "Has debt" "Has debt" "Has debt" ///
            "Had debt 5y" "Had debt 5y" "Had debt 5y" "Had debt 5y") label

/*--- (b) Table 4: applied for a new bank loan during COVID-19 ---*/
* H2: entrepreneurs with high debt aversion were less likely to apply for
*     a new bank loan during COVID-19.

local y applied_new_bank_loan
local i = 0
foreach x in high_debt_aversion debt_aversion {
    local i = `i' + 1
    eststo t4_`i'a: reg `y' `x', vce(cluster municipality)
    mark_sample `y' `x' $controls municipality, fe($fe2) gen(s_t4_`i'b)
    eststo t4_`i'b: reg `y' `x' $controls $fe2_dummies if s_t4_`i'b, vce(cluster municipality)
    mark_sample `y' `x' $controls municipality, fe($fe3) gen(s_t4_`i'c)
    eststo t4_`i'c: reg `y' `x' $controls $fe3_dummies if s_t4_`i'c, vce(cluster municipality)
}

esttab t4_1a t4_1b t4_1c t4_2a t4_2b t4_2c ///
    using "output/table4_new_bank_loan.csv", replace ///
    keep(high_debt_aversion debt_aversion $controls) ///
    b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) stats(N r2, fmt(0 3)) ///
    nomtitles label

/*--- (c) Table 10, Panel A: the 2023 follow-up survey ---*/
* the authors' definitions: debt aversion is the 0 to 10 attitude question,
* high debt aversion is a score above 7 (0 when the score is missing).
* fixed effects: industry, firm size, organizational form. robust errors.

* H3: the debt aversion effect on debt use holds in the 2023 survey.
preserve
use "data/raw/paaso/2023_cleaned_survey.dta", clear
gen debt_aversion = debt_attitude if !missing(debt_attitude)
gen high_debt_aversion = (debt_aversion > 7) & !missing(debt_aversion)
label variable isdebt "Has debt (0/1)"
label variable debt_aversion "Debt aversion (0 to 10)"
label variable high_debt_aversion "High debt aversion (0/1)"

eststo t10_1: reg isdebt high_debt_aversion, vce(robust)
mark_sample isdebt high_debt_aversion, fe(d_industry d_n_empl d_orgform) gen(s_t10_2)
eststo t10_2: reg isdebt high_debt_aversion i.d_industry i.d_n_empl i.d_orgform if s_t10_2, vce(robust)
eststo t10_3: reg isdebt debt_aversion, vce(robust)
mark_sample isdebt debt_aversion, fe(d_industry d_n_empl d_orgform) gen(s_t10_4)
eststo t10_4: reg isdebt debt_aversion i.d_industry i.d_n_empl i.d_orgform if s_t10_4, vce(robust)

esttab t10_1 t10_2 t10_3 t10_4 using "output/table10a_2023_sample.csv", replace ///
    keep(high_debt_aversion debt_aversion) ///
    b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) stats(N r2, fmt(0 3)) nomtitles label

/*--- E6 belongs here because it uses the 2023 file (see section 5) ---*/
* H9: in 2023 the effect of high debt aversion is the same in a probit or
*     logit as in the lpm.
* probit with the same fixed effects, average partial effect of high aversion
probit isdebt i.high_debt_aversion i.d_industry i.d_n_empl i.d_orgform if s_t10_2, vce(robust)
eststo e6_probit: margins, dydx(high_debt_aversion) post
logit isdebt i.high_debt_aversion i.d_industry i.d_n_empl i.d_orgform if s_t10_2, vce(robust)
eststo e6_logit: margins, dydx(high_debt_aversion) post
esttab t10_2 e6_probit e6_logit using "output/ext6_2023_probit_logit.csv", replace ///
    keep(high_debt_aversion 1.high_debt_aversion) ///
    b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) stats(N, fmt(0)) ///
    mtitles("LPM" "Probit APE" "Logit APE")
restore


/*==============================================================================
    5. EXTENSION
    the paper uses only linear probability models with clustered errors.
    each test below checks one assumption behind those estimates.
    main specifications: table 3a column (2) for has_debt (sample s_t3_1)
    and table 4 column (2) for applied_new_bank_loan (sample s_t4_1b).
==============================================================================*/

/*--- E1. Probit and logit vs the linear probability model (ch 17) ---*/
* H4: the effect of high debt aversion is the same in a probit or logit
*     model as in the lpm. compare average partial effects (ape).

foreach y in has_debt applied_new_bank_loan {
    if "`y'"=="has_debt" local s s_t3_1
    else local s s_t4_1b
    if "`y'"=="has_debt" local t hd
    else local t ab

    * lpm, as in the paper
    eststo e1_lpm_`t': reg `y' i.high_debt_aversion $controls $fe2_dummies if `s', vce(cluster municipality)
    * fitted probabilities outside 0 to 1 (a known weakness of the lpm)
    predict phat_`t' if e(sample), xb
    count if phat_`t' < 0 & e(sample)
    scalar n_below_`t' = r(N)
    count if phat_`t' > 1 & phat_`t' < . & e(sample)
    scalar n_above_`t' = r(N)
    display "`y': fitted values below 0 = " n_below_`t' ", above 1 = " n_above_`t'

    * probit and logit; margins gives the average partial effect of the dummy
    probit `y' i.high_debt_aversion $controls $fe2_dummies if `s', vce(cluster municipality)
    eststo e1_probit_`t': margins, dydx(high_debt_aversion) post
    logit `y' i.high_debt_aversion $controls $fe2_dummies if `s', vce(cluster municipality)
    eststo e1_logit_`t': margins, dydx(high_debt_aversion) post
}

esttab e1_lpm_hd e1_probit_hd e1_logit_hd ///
       e1_lpm_ab e1_probit_ab e1_logit_ab ///
    using "output/ext1_probit_logit.csv", replace keep(1.high_debt_aversion) ///
    b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) stats(N, fmt(0)) ///
    mtitles("Has debt LPM" "Has debt Probit" "Has debt Logit" ///
            "Applied LPM" "Applied Probit" "Applied Logit")

/*--- E2. Heteroskedasticity tests and WLS for the LPM (ch 8) ---*/
* H5: the lpm errors are homoskedastic. in an lpm Var(u|x) = p(x)(1-p(x)),
*     so this should fail. then estimate wls with h = yhat(1-yhat).

file open het using "output/ext2_heteroskedasticity.csv", write replace
file write het "outcome,test,stat,df1,df2,p_value" _n

foreach y in has_debt applied_new_bank_loan {
    if "`y'"=="has_debt" local s s_t3_1
    else local s s_t4_1b
    if "`y'"=="has_debt" local t hd
    else local t ab

    quietly reg `y' high_debt_aversion $controls $fe2_dummies if `s'
    scalar n_h = e(N)
    predict yhat_`t' if e(sample), xb
    predict uhat_`t' if e(sample), residual
    gen uhatsq_`t' = uhat_`t'^2
    gen yhatsq_`t' = yhat_`t'^2

    * breusch-pagan: regress uhat squared on all regressors
    quietly reg uhatsq_`t' high_debt_aversion $controls $fe2_dummies if `s'
    scalar k1 = e(df_m)
    scalar r2_bp = e(r2)
    scalar F_bp  = (r2_bp/k1)/((1-r2_bp)/(n_h-k1-1))
    scalar LM_bp = n_h*r2_bp
    display "`y' breusch-pagan: F = " F_bp " p = " Ftail(k1, n_h-k1-1, F_bp) ///
            "  LM = " LM_bp " p = " chi2tail(k1, LM_bp)
    file write het "`y',Breusch-Pagan F," %9.3f (F_bp) "," %4.0f (k1) "," %6.0f (n_h-k1-1) "," %9.4f (Ftail(k1, n_h-k1-1, F_bp)) _n
    file write het "`y',Breusch-Pagan LM," %9.3f (LM_bp) "," %4.0f (k1) ",," %9.4f (chi2tail(k1, LM_bp)) _n

    * or simply use the stata command for the breusch-pagan test (as in ch08)
    quietly reg `y' high_debt_aversion $controls $fe2_dummies if `s'
    estat hettest, rhs fstat

    * special case of the white test: uhat squared on yhat and yhat squared
    quietly reg uhatsq_`t' yhat_`t' yhatsq_`t' if `s'
    scalar r2_w = e(r2)
    scalar F_w  = (r2_w/2)/((1-r2_w)/(n_h-2-1))
    scalar LM_w = n_h*r2_w
    display "`y' white (special): F = " F_w " p = " Ftail(2, n_h-3, F_w) ///
            "  LM = " LM_w " p = " chi2tail(2, LM_w)
    file write het "`y',White special F," %9.3f (F_w) ",2," %6.0f (n_h-3) "," %9.4f (Ftail(2, n_h-3, F_w)) _n
    file write het "`y',White special LM," %9.3f (LM_w) ",2,," %9.4f (chi2tail(2, LM_w)) _n

    * or simply use the stata command for the full white test (as in ch08).
    * with about 55 regressors, most of them dummies, the full test needs more
    * squares and cross products than there are firms, so it may not run.
    * capture keeps the do-file going; the special case above is the one i
    * report, which is why the textbook offers it.
    quietly reg `y' high_debt_aversion $controls $fe2_dummies if `s'
    capture noisily estat imtest, white

    * wls for the lpm: weights 1/h with h = yhat(1-yhat).
    * fitted values outside (0,1) give h <= 0, so they are set to 0.01 or 0.99
    gen p_`t' = yhat_`t'
    replace p_`t' = 0.01 if p_`t' < 0.01 & p_`t' < .
    replace p_`t' = 0.99 if p_`t' > 0.99 & p_`t' < .
    gen h_`t' = p_`t'*(1-p_`t')
    eststo e2_ols_`t': reg `y' high_debt_aversion $controls $fe2_dummies if `s', vce(cluster municipality)
    eststo e2_wls_`t': reg `y' high_debt_aversion $controls $fe2_dummies [aweight=1/h_`t'] if `s', vce(cluster municipality)
}
file close het

esttab e2_ols_hd e2_wls_hd e2_ols_ab e2_wls_ab ///
    using "output/ext2_wls.csv", replace keep(high_debt_aversion) ///
    b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) stats(N, fmt(0)) ///
    mtitles("Has debt OLS" "Has debt WLS" "Applied OLS" "Applied WLS")

/*--- E3. Functional form of the debt aversion score (ch 6 and 7) ---*/
* H6: the effect of the 0 to 10 score is linear. alternatives: a dummy for
*     every score (most flexible), a quadratic, and the reset test.

file open ff using "output/ext3_functional_form.csv", write replace
file write ff "outcome,test,stat,df1,df2,p_value" _n

foreach y in has_debt applied_new_bank_loan {
    if "`y'"=="has_debt" local s s_t3_2
    else local s s_t4_2b
    if "`y'"=="has_debt" local t hd
    else local t ab

    * restricted model: the score enters linearly
    quietly reg `y' debt_aversion $controls $fe2_dummies if `s'
    scalar ssr_r = e(rss)
    predict yh_`t' if e(sample), xb
    gen yh2_`t' = yh_`t'^2
    gen yh3_`t' = yh_`t'^3

    * unrestricted model: a dummy for each score (score 0 is the base)
    quietly reg `y' i.debt_aversion $controls $fe2_dummies if `s'
    scalar ssr_ur = e(rss)
    scalar df_ur  = e(df_r)
    * linear = 10 dummy coefficients described by 1 slope: 9 restrictions
    scalar F_lin = ((ssr_r-ssr_ur)/9)/(ssr_ur/df_ur)
    display "`y' linear vs dummies: F = " F_lin " p = " Ftail(9, df_ur, F_lin)
    file write ff "`y',Linear vs score dummies F," %9.3f (F_lin) ",9," %6.0f (df_ur) "," %9.4f (Ftail(9, df_ur, F_lin)) _n

    * same restriction with clustered errors: b_k = k * b_1 for k = 2 to 10
    eststo e3_dummies_`t': reg `y' i.debt_aversion $controls $fe2_dummies if `s', vce(cluster municipality)
    test (_b[2.debt_aversion] = 2*_b[1.debt_aversion])
    forvalues k = 3/10 {
        test (_b[`k'.debt_aversion] = `k'*_b[1.debt_aversion]), accumulate
    }
    file write ff "`y',Linear vs score dummies (clustered Wald F)," %9.3f (r(F)) "," %4.0f (r(df)) "," %6.0f (r(df_r)) "," %9.4f (r(p)) _n

    * quadratic in the score
    capture drop da_sq
    gen da_sq = debt_aversion^2
    eststo e3_quad_`t': reg `y' debt_aversion da_sq $controls $fe2_dummies if `s', vce(cluster municipality)
    display "`y' turning point of the quadratic: " -(_b[debt_aversion])/(2*_b[da_sq])
    file write ff "`y',Quadratic term t," %9.3f (_b[da_sq]/_se[da_sq]) ",1," %6.0f (e(df_r)) "," %9.4f (2*ttail(e(df_r), abs(_b[da_sq]/_se[da_sq]))) _n

    * reset test: add yhat squared and cubed to the linear model
    quietly reg `y' debt_aversion yh2_`t' yh3_`t' $controls $fe2_dummies if `s'
    test yh2_`t' yh3_`t'
    file write ff "`y',RESET F," %9.3f (r(F)) "," %4.0f (r(df)) "," %6.0f (r(df_r)) "," %9.4f (r(p)) _n
}
file close ff

esttab e3_dummies_hd e3_dummies_ab ///
       e3_quad_hd e3_quad_ab ///
    using "output/ext3_score_dummies_quadratic.csv", replace ///
    keep(*.debt_aversion debt_aversion da_sq) ///
    b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) stats(N r2, fmt(0 3)) ///
    mtitles("Has debt dummies" "Applied dummies" "Has debt quadratic" "Applied quadratic")

/*--- E4. Measurement error: instrumental variables (ch 15) ---*/
* H7: the survey score measures debt aversion with error, which biases ols
*     toward zero. this part is added in the final version, after chapter 15
*     is covered in class.

/*--- E5. Differences across groups: Chow-type tests (ch 7) ---*/
* H8: the effect of high debt aversion is the same for women and men, and
*      for smaller firms (under 5 employees) and larger firms.

gen larger = (n_employees >= 3) if !missing(n_employees)
label variable larger "Firm has 5 or more employees"
gen hdaXfemale = high_debt_aversion*female
gen hdaXlarger = high_debt_aversion*larger

file open grp using "output/ext5_group_tests.csv", write replace
file write grp "outcome,group,test,stat,df1,df2,p_value" _n

foreach y in has_debt applied_new_bank_loan {
    if "`y'"=="has_debt" local s s_t3_1
    else local s s_t4_1b
    if "`y'"=="has_debt" local t hd
    else local t ab

    foreach g in female larger {
        * (a) does the debt aversion effect differ? interaction, clustered
        * "larger" is already absorbed by the firm-size dummies, so only
        * female enters on its own; the interaction is identified either way
        if "`g'"=="female" local main female
        else local main
        eststo e5_`g'_`t': reg `y' high_debt_aversion `main' hdaX`g' $controls $fe2_dummies if `s', vce(cluster municipality)
        test hdaX`g'
        file write grp "`y',`g',Interaction Wald F," %9.3f (r(F)) "," %4.0f (r(df)) "," %6.0f (r(df_r)) "," %9.4f (r(p)) _n

        * (b) classic chow test on the model with the controls
        *     (whole regression function differs across the two groups)
        quietly reg `y' high_debt_aversion $controls if `s'
        scalar ssr_r = e(rss)
        scalar n_c   = e(N)
        scalar k     = e(df_m)
        quietly reg `y' high_debt_aversion $controls if `s' & `g'==0
        scalar ssr1 = e(rss)
        quietly reg `y' high_debt_aversion $controls if `s' & `g'==1
        scalar ssr2 = e(rss)
        scalar F_chow = ((ssr_r-(ssr1+ssr2))/(k+1)) / ((ssr1+ssr2)/(n_c-2*(k+1)))
        display "`y' chow test by `g': F = " F_chow " p = " Ftail(k+1, n_c-2*(k+1), F_chow)
        file write grp "`y',`g',Chow F," %9.3f (F_chow) "," %4.0f (k+1) "," %6.0f (n_c-2*(k+1)) "," %9.4f (Ftail(k+1, n_c-2*(k+1), F_chow)) _n
    }
}
file close grp

esttab e5_female_hd e5_larger_hd e5_female_ab e5_larger_ab ///
    using "output/ext5_group_interactions.csv", replace ///
    keep(high_debt_aversion female hdaXfemale hdaXlarger) ///
    b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) stats(N r2, fmt(0 3)) ///
    mtitles("Has debt x female" "Has debt x larger" "Applied x female" "Applied x larger")


/*==============================================================================
    6. KEY NUMBERS FOR THE REPORT
==============================================================================*/

file open kn using "output/key_numbers.csv", write replace
file write kn "name,value" _n
foreach m in t3_1a t3_1b t3_2a t3_2b t3_3a t3_3b t3_4a t3_4b t4_1a t4_1b t4_1c t4_2a t4_2b t4_2c {
    estimates restore `m'
    capture scalar b = _b[high_debt_aversion]
    if _rc != 0 scalar b = _b[debt_aversion]
    capture scalar se = _se[high_debt_aversion]
    if _rc != 0 scalar se = _se[debt_aversion]
    file write kn "b_`m'," %9.4f (b) _n
    file write kn "se_`m'," %9.4f (se) _n
    file write kn "n_`m'," %9.0f (e(N)) _n
}
foreach t in hd ab {
    file write kn "lpm_fitted_below0_`t'," %9.0f (n_below_`t') _n
    file write kn "lpm_fitted_above1_`t'," %9.0f (n_above_`t') _n
}
file close kn


/*==============================================================================
    7. FIGURES FOR THE REPORT
==============================================================================*/

/*--- Figure 1: share of firms with debt at each debt aversion score ---*/
graph bar (mean) has_debt if !missing(debt_aversion), over(debt_aversion) ///
    ytitle("Share of firms with debt") ///
    b1title("Debt aversion score (0 to 10)") ///
    title("Debt use by debt aversion score") ///
    note("Source: Paaso, Pursiainen and Torstila (2025) survey, 2020. N = 899.")
graph export "output/fig1_debt_by_score.png", replace width(1600)

/*--- Figure 2: effect of each score relative to score 0 (extension E3) ---*/
* coefficients and standard errors from the score dummy regression
estimates restore e3_dummies_hd
matrix B = e(b)
matrix V = e(V)
preserve
clear
set obs 11
gen score = _n - 1
gen b  = 0
gen se = 0
forvalues k = 1/10 {
    replace b  = el(B, 1, colnumb(B, "`k'.debt_aversion")) if score==`k'
    replace se = sqrt(el(V, colnumb(V, "`k'.debt_aversion"), colnumb(V, "`k'.debt_aversion"))) if score==`k'
}
gen lo = b - 1.96*se
gen hi = b + 1.96*se
twoway (rcap lo hi score if score>0, lcolor(gs8)) ///
       (scatter b score, mcolor(navy)), ///
    yline(0, lpattern(dash)) xlabel(0(1)10) ///
    ytitle("Change in probability of having debt") ///
    xtitle("Debt aversion score (0 = base)") ///
    title("Has debt: effect of each score relative to score 0") ///
    legend(order(2 "Estimate" 1 "95% confidence interval")) ///
    note("Linear probability model with controls and fixed effects; errors clustered by municipality.")
graph export "output/fig2_score_dummies.png", replace width(1600)
restore

/*--- Figure 3: effect of high debt aversion across estimators (E1, E2) ---*/
tempname post
tempfile est
postfile `post' str25 outcome str12 method b se using `est'
foreach y in has_debt applied_new_bank_loan {
    if "`y'"=="has_debt" local t hd
    else local t ab
    foreach m in lpm probit logit wls {
        if "`m'"=="wls" estimates restore e2_wls_`t'
        else estimates restore e1_`m'_`t'
        capture scalar bb = _b[1.high_debt_aversion]
        if _rc != 0 scalar bb = _b[high_debt_aversion]
        capture scalar ss = _se[1.high_debt_aversion]
        if _rc != 0 scalar ss = _se[high_debt_aversion]
        post `post' ("`y'") ("`m'") (bb) (ss)
    }
}
postclose `post'
preserve
use `est', clear
gen lo = b - 1.96*se
gen hi = b + 1.96*se
gen id = _n
replace id = id + 1 if outcome=="applied_new_bank_loan"
label define idl 1 "Has debt: LPM" 2 "Has debt: Probit APE" 3 "Has debt: Logit APE" 4 "Has debt: WLS" ///
                 6 "Applied: LPM" 7 "Applied: Probit APE" 8 "Applied: Logit APE" 9 "Applied: WLS"
label values id idl
export delimited using "output/fig3_estimates.csv", replace
twoway (rcap lo hi id, horizontal lcolor(gs8)) ///
       (scatter id b, mcolor(navy)), ///
    xline(0, lpattern(dash)) ylabel(1 2 3 4 6 7 8 9, valuelabel angle(0)) yscale(reverse) ///
    ytitle("") xtitle("Effect of high debt aversion (probability)") ///
    title("High debt aversion across estimators") ///
    legend(order(2 "Estimate" 1 "95% confidence interval")) ///
    note("Controls and fixed effects as in Table 3A col. (2) and Table 4 col. (2).")
graph export "output/fig3_estimators.png", replace width(1600)
restore


/*==============================================================================
    FINISH
==============================================================================*/

log close
display "done. tables are in output/, the log is output/paaso_replication_output.log"


/*==============================================================================
    COMMON ERRORS
    - "file data/raw/paaso/cleaned_survey.dta not found": stata is not in the
      project folder. use cd "path to the project folder" first.
    - "command esttab is unrecognized": run  ssc install estout  once.
    - "program mark_sample already defined": run the whole file from the top
      (the capture program drop line clears it).
    - "variable phat_has_debt already defined": run the whole file from the
      top, since -clear all- resets the data.
    - probit or logit may note that some dummies "predict failure perfectly"
      and drop those firms. that is expected with many category dummies;
      the N in ext1_probit_logit.csv shows how many firms remain.
    - N in the fixed effects columns is 884, the paper reports 883; the
      coefficients match to three decimals. reghdfe and -reg- with dummies
      can differ by one observation in how singletons are found.
==============================================================================*/
