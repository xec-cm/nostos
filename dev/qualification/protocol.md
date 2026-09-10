# Qualification protocol: current descriptive method

Status: prespecified on 2026-09-10 for issues #41 and #43. This protocol is
committed before running recoverome on the evaluation scenarios. Source-file
inspection, checksum verification and calendar transcription precede analysis.
Changes after execution must be recorded below, with their reason and effect.
The method and its accepted RFCs will not be changed to improve these results.

## Questions and estimands

Separate three questions: do the arithmetic and documented rule agree with
independent calculations; what can the available visits establish under that
rule; and what biological conclusions remain unsupported? The target is observed
return to an explicit personal composition reference, not health, functional
restoration, causality or an inferred continuous recovery time.

The reference is the unweighted mean of individually closed baseline samples.
Bray--Curtis between compositions equals half their L1 distance. Baselines must
precede exposure start. The four rule parameters are chosen before looking at
outcomes. No parameter setting is designated scientifically optimal.

## Real source and curation

Use Dethlefsen et al. (2008), DOI 10.1371/journal.pbio.0060280, Dataset S3
(`sd003`, XLS, sheet `V3 refOTUs`) and the original Table 1. The downloaded XLS
SHA-256 is `4fbe0c8ffb0c121851ca791bdce5ee7da8977920315908e70e6014d3990273cc`.
It contains 5,670 refOTUs and 18 samples from participants A, B and C. Retain all
rows and all sample columns. These are published normalized abundances (each
sample totals 43,405), not integer raw sequencing counts. Preserve the numeric
values; keep taxonomy with whitespace trimmed. Do not rarefy, remove taxa,
impute visits or infer raw read depths. Do not manufacture a phylogenetic tree.

Transcribe original sample days relative to first ciprofloxacin administration;
verify their alignment visually against Table 1. Record a five-day exposure as
an operational interval [0, 5] days, not a known last-dose timestamp. Use one
episode per participant, origin at exposure start. All negative-day samples are
the primary baseline; compare the earliest alone and latest alone as separately
registered analyses. The article and supplement use Creative Commons Attribution;
retain author, source, attribution and preprocessing notices with packaged data.
The packaged TSE and vignette must run offline; regeneration may download the
pinned original file explicitly. Do not use the cohort as ground truth for
recovery or claim that three participants validate a general clinical method.

Primary illustrative rule: threshold 0.25, persistence 7 days, maximum gap
14 days and horizon 180 days. Report the entire grid: thresholds 0.10/0.25/0.40,
persistence 7/28 days, maximum gaps 14/35 days, horizons 33/180 days, crossed with
the three baseline selections. The wide late gap is a limitation, not a reason
to increase maximum gap until confirmation occurs. Include every episode and
non-evaluable outcome. Report baseline sample/time support, deviations, status,
first return, candidate, confirmation, rebound, last observed time and coverage.

## Synthetic scenarios

Use two features with samples at baseline days -4 and -2 and follow-up days
0, 2, 4, 6, 8, 10. Stable baseline compositions are (1, 0) twice; unstable
baselines are (1, 0) and (0.6, 0.4). Follow-up feature-2 proportions are:

| Scenario | 0 | 2 | 4 | 6 | 8 | 10 |
|---|---:|---:|---:|---:|---:|---:|
| Return | .75 | .25 | .125 | .125 | .125 | .125 |
| Rebound | .75 | .25 | .125 | .125 | .50 | .125 |
| Persistent change | .75 | .75 | .75 | .75 | .75 | .75 |
| No detected perturbation | .125 | .125 | .125 | .125 | .125 | .125 |

Reference feature-2 proportion is independently known to be 0, .2 or .4,
depending on baseline stability and selection. Expected deviation is the
absolute difference of sample and reference feature-2 proportions. Under the
primary rule (.25, 4, 3, 10), stable/full return confirms at day 6, rebound first
rebounds at 8, persistent change has no observed return, and the unperturbed
scenario has no observed perturbation. These expected outcomes are assertions,
not estimates derived from recoverome output.

Cross both baseline types, all/earliest/latest baseline selection and four
observation schedules: full; alternate follow-up visits (0, 4, 8); missing
bridge (remove day 4); and irregular times (0, 1, 4, 7, 9, 10) with compositions
retained in order. Filtering occurs BEFORE new registration. Separately compare
a subset of an already completed analysis: that historical outcome must remain
unchanged while validation records missing evidence. The irregular schedule is
a different hypothetical observation process, not a relabelling of real data.

On stable/full scenarios cross thresholds .10/.25/.40, persistence 2/4 days,
maximum gaps 2/3 days and horizons 6/10 days. Add a discordant sample with
feature-2 proportion .75 at day 2 in the return scenario: tied samples form one
visit and every sample must be within threshold for the visit to be within.

Depth checks have two parts. Exact positive column scaling (depth factors
1 and 100) must leave compositions and deviations unchanged. For finite-count
variation, use multinomial draws of both baseline and follow-up compositions
for return and rebound with unstable baselines, depths 100/1,000/10,000 and
20 replicates each, seed 20260910 using R's Mersenne-Twister/Inversion/Rejection
RNG. Report all outcomes and maximum absolute departure from target deviations;
these small simulations illustrate sensitivity, not calibrated error rates or
power. No new distance, inference or threshold estimator is introduced.

## Independent comparison and reporting

Compare all evaluated sample deviations with direct arithmetic and with
`vegan::vegdist(method = "bray")` on identical closed samples and independently
formed mean baseline profiles. Numerical tolerance is 1e-12 (double precision,
small sums); record maximum discrepancies and fail the reproduction script on
exceedance. Missing-reference episodes remain explicitly represented rather
than entering the numerical comparison as zeros. An independently implemented
visit-rule classifier checks the small synthetic primary examples.

Keep machine-readable scenario identifiers, inputs and complete outcome tables,
plus R/package versions and protocol revision. Publish a concise assessment
explaining observed consequences and limitations; the real-data vignette shows
one prespecified rule and links the complete grid, not a selected success case.
Manual/agent review checks source/calendar transcription, arithmetic, reporting
and readable plots. Package tests establish implementation behavior, not
scientific validity. Future sensitivity and plotting contracts accompany this
assessment; no future API is exported in this PR.

## Deviations from this protocol

None at registration. Append dated deviations here without rewriting the
prespecified sections after observing outcomes.
