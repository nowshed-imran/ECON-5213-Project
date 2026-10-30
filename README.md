# Entrepreneur Debt Aversion and Bank Borrowing: A Replication of Paaso, Pursiainen and Torstila (2025)

Replication paper for ECON 5213 Econometric Analysis, Oklahoma State University (Fall 2026).

Status: in progress (October 30, 2026). The replication and five of the six extension tests are done and reported. The instrumental variables test for measurement error (H7, chapter 15) is added in the final version, due December 10, 2026, after it is covered in class. See Project status below.

Paaso, Pursiainen and Torstila (2025) survey 917 Finnish owner-managers in 2020 and find that owners who dislike debt run firms that use less of it, and were less likely to apply for a bank loan during COVID-19. This project replicates their Tables 1, 3A, 4 and 10A with the authors' survey data and my own Stata code, then tests the assumptions behind their linear probability models. The full write-up is in `report/paaso_replication.pdf`.

## Main results

- Replication: high debt aversion lowers the probability of having debt by 0.093 (clustered standard error 0.027), against 0.094 (0.030) in the paper. All 18 coefficients in Tables 3A, 4 and 10A are within 0.001 of the paper's. The 2020 sample with dummies has 884 firms against the paper's 883, and some clustered standard errors are smaller in the third decimal.
- Extension: the debt use result holds under probit and logit (average partial effect of 0.094), weighted least squares (0.062), score dummies and the 2023 survey (0.196). The bank loan result is weaker. It is 0.046 with p = 0.053 in the paper's model, not significant in the logit, and the linear model predicts negative probabilities for 142 firms. The 0 to 10 score works more like a threshold at 7 and above than a straight line.

## Hypotheses

Replication (from the paper):

- H1. Owners with high debt aversion are less likely to have debt now and to have had debt in the past five years (Table 3A).
- H2. Owners with high debt aversion were less likely to apply for a new bank loan during COVID-19 (Table 4).
- H3. The effect on debt use holds in the 2023 survey (Table 10A).

Extension (assumptions of the linear probability model):

- H4. The effect is the same in probit and logit as in the linear model.
- H5. The errors are homoskedastic, and weighted least squares gives the same effect.
- H6. The effect of the 0 to 10 score is linear.
- H7. The score is measured without error (instrumental variables). Added in the final version.
- H8. The effect is the same for women and men, and for small and larger firms.
- H9. In the 2023 survey, the effect is the same in probit and logit as in the linear model.

## Method in brief

The paper's model is a linear probability model of a 0/1 outcome on a high debt aversion indicator (score of 8 or more), four traits (risk appetite, optimism, distrust of people, distrust of banks) and dummies for firm size, industry, expected survival, survival time and the owner's education. The paper absorbs the dummies with `reghdfe`; I include them directly with `reg y x i.var`, drop singletons as the paper does, and cluster standard errors by municipality (44 clusters). I read the authors' specifications but did not run or copy their code.

The extension follows the cross-section chapters of Wooldridge's *Introductory Econometrics*: probit and logit with average partial effects (chapter 17), Breusch-Pagan and special White tests and WLS for the linear probability model (chapter 8), score dummies, a squared term and RESET (chapters 6 and 7), and interactions with Chow tests (chapter 7). Two stage least squares with childhood lessons about debt as instruments (chapter 15) is added in the final version.

## Repository

| File | Content |
| :--- | :--- |
| `paaso_replication_nowshed.do` | The full analysis in one Stata do-file: data checks, Table 1, estimation sample, replication, extension E1 to E6, key numbers, figures |
| `report/` | Findings report: PDF, LaTeX source, `elsarticle.cls`, `elsarticle-harv.bst` and the three figures |
| `output/` | Tables, figures and the Stata log produced by the do-file |
| `data/README.md` | Where the data come from and how to rebuild the folder |
| `papers/README.md` | The paper, the backup paper and the papers considered |
| `LICENSE` | MIT (does not cover the Elsevier files or the data) |

## Data

The data are the authors' survey from the Management Science replication package (DOI 10.1287/mnsc.2022.03007): `cleaned_survey.dta` (2020, 917 owner-managers) and `2023_cleaned_survey.dta` (2023 follow-up, 1,041 firms). Under the journal's terms the files may be used to verify the published results, and the authors agreed to their use for the extension. The files are not in this repository and must not be shared. `data/README.md` explains how to download the package and where to put the two files. The paper's Table 3B uses Orbis debt ratios that were removed from the package, so it cannot be replicated.

## How to run

1. Put the two data files in `data/raw/paaso/` (see `data/README.md`).
2. Open the project folder in Stata (File > Change Working Directory) and run `paaso_replication_nowshed.do`. It installs `estout` if it is missing, and writes every table, the figures and the log to `output/`.
3. To rebuild the report, compile `report/paaso_replication.tex` with pdflatex twice. The figures it uses are copies of the three PNG files in `output/`.

## Output

| File | Table or figure in the report |
| :--- | :--- |
| `output/table1_summary_stats.csv` | Table 1 |
| `output/table3a_debt_use.csv` | Table 2 (replication of the paper's Table 3A) |
| `output/table4_new_bank_loan.csv` | Table 3 (Table 4) |
| `output/table10a_2023_sample.csv` | Section 5.2 and Table 4 (Table 10A) |
| `output/key_numbers.csv` | Benchmark table, fitted values outside 0 and 1 |
| `output/ext1_probit_logit.csv`, `output/ext2_wls.csv`, `output/ext6_2023_probit_logit.csv` | Table 5 (estimators) |
| `output/ext2_heteroskedasticity.csv`, `output/ext3_functional_form.csv` | Table 6 (specification tests) |
| `output/ext3_score_dummies_quadratic.csv` | Figure 2 and Section 6.2 |
| `output/ext5_group_interactions.csv`, `output/ext5_group_tests.csv` | Table 7 (groups) |
| `output/fig1_debt_by_score.png`, `output/fig2_score_dummies.png`, `output/fig3_estimators.png` | Figures 1 to 3 |
| `output/paaso_replication_output.log` | Full Stata log |

## Project status

| Part | Status |
| :--- | :--- |
| Replication of Tables 1, 3A, 4 and 10A, with the benchmark against the paper | Done |
| E1 probit and logit (H4), E2 heteroskedasticity and WLS (H5), E3 functional form (H6), E5 groups (H8), E6 the 2023 survey (H9) | Done |
| E4 instrumental variables for measurement error (H7) | To be added after chapter 15 is covered in class |
| Course presentation | December 1 or 3, 2026 |
| Final paper and code | December 10, 2026 |

## Report format

The findings report is written in LaTeX using Elsevier's elsarticle template (elsarticle.cls), the template for the Journal of Financial Economics and other Elsevier journals. The class file is kept in `report/` so the source compiles as is. `elsarticle.cls` and `elsarticle-harv.bst` are copyright Elsevier Ltd and are included unmodified under the LaTeX Project Public License; the MIT license of this repository does not cover them.

## AI assistance

The study design, hypotheses, model choices and interpretation are my own. The code was written with the help of Claude (Anthropic), which I used to build this do-file from the course do-files, find and fix errors, and implement the extension tests. I have reviewed the code extensively and would appreciate any suggestions for improvement.
