# RosettaGBR Changelog

## 1.0.0 -- first stable release; eDNA models refitted with manta tows from all eight voyages

- **First stable release.** The interface (`GBR_calibrate()`, `GBR_curve()`, `GBR_posterior()`) has been unchanged since 0.3.0 and the 52
  calibration models are those of the BR-04 final report. Later refits on new data will be minor or patch releases.
  (This release was developed as 0.5.2 and relabelled 1.0.0 before publication.)

- **Data update, no change to the interface.** The 3-voyage exclusion exists because of ReefScan data quality,
  so the manta <-> eDNA models now use manta tows from all eight FMPCRS voyages (they previously used the five
  ReefScan-filtered voyages). Together with a case-sensitivity fix in the eDNA reef matching (eDNA `21-250A` is
  manta `21-250a`), the reef set for those models grows from 24 to 32 reefs (the eDNA <-> eDNA models use the same
  32 reefs); the eDNA <-> ReefScan Surface models gain one reef (17 to 18) and still use the ReefScan-filtered data.
- **Refitted and re-bundled (10 posteriors):** the four manta <-> eDNA models, the two eDNA <-> eDNA models and
  the four eDNA <-> ReefScan Surface models. All other bundled posteriors are unchanged.
- **Size of the changes (slope, posterior mean):** `eDNAconc_from_manta_reef` 0.23 -> 0.30, `eDNAprop_from_manta_reef`
  0.17 -> 0.23, `manta_from_eDNAconc_binary_reef` 0.35 -> 0.25, `manta_from_eDNAprop_binary_reef` 0.47 -> 0.27,
  `eDNAconc_from_eDNAprop_reef` 1.53 -> 1.59, `eDNAprop_from_eDNAconc_reef` 0.88 -> 0.98; the ReefScan Surface pairs
  move by less than 0.35. No slope changes sign. Two borderline intervals cross zero: `eDNAconc_from_manta_reef`
  (now 0.08 to 0.53, previously -0.02 to 0.51) and `eDNAconc_from_surf_reef` (now -0.01 to 0.64, previously 0.00 to 0.66).
- `predictor_range.csv`: the eDNA rows now give the ranges over the 32 reefs (concentration per assay 0-116.6,
  proportion positive 0-0.958), which sets the default `GBR_curve()` grid and the `observed` flag.
- Model registry (family, link, offset, `eps`) unchanged.

## 0.5.1 -- refitted on the November 2026 COTSpotter re-export

- **Data update, no change to the interface.** COTSpotter re-exported its detections (more detections
  certified, some revised; 302 detections versus 251 before, 59 of them genuinely new). Every model that uses
  a ReefScan Surface or ReefScan Deep COTS count as predictor or response was refitted: 28 bundled
  posteriors changed (the 24 cross-method COTS models between manta tow, ReefScan Surface and ReefScan
  Deep, at tow, cull-site and reef level, and the four eDNA <-> ReefScan Surface models). The coral models,
  the manta <-> eDNA models and the eDNA <-> eDNA models are unchanged.
- **Size of the changes.** For 27 of the 28 models the slope moved by less than one posterior SD and no
  model changed whether its 95% credible interval excludes zero. The exception is
  `surf_from_eDNAconc_reef` (slope 3.8 -> 1.6; only 17 reefs, and reef 21-491 carries most of the signal).
  The manta <-> ReefScan Surface slopes are 8-25% smaller.
- `predictor_range.csv`: the ReefScan Surface and ReefScan Deep rows now give the ranges of the new counts
  (Surface tow 0-12, cull site 0-2.8, reef 0-0.95; Deep tow 0-56, cull site 0-5.33, reef 0-1.8), which sets
  the default `GBR_curve()` grid and the `observed` flag.
- Model registry (family, link, offset, `eps`) unchanged.

## 0.5.0 -- the manta predictor now uses feeding-scar COUNTS

- **Change to the manta COTS-plus-scars index.** BR-04 previously added scar *presence* (0/1 per
  tow, i.e. the number of tows with scars) to the COTS count. The manta data carry a numeric
  per-tow scar count (`ScarsCount`) for tows from 14 June 2025 (FMPCRS 2025-03 onward); the index
  is now (COTS seen + feeding scars counted) per tow. For FMPCRS 2025-02, which pre-dates the
  count, scarred tows were imputed from the category (present = 2, common = 11).
- **Refitted and re-bundled (10 posteriors):** `surf_from_manta_{tow,cull,reef}_cots`,
  `deep_from_manta_{tow,cull,reef}_cots`, `eDNAprop_from_manta_reef`, `eDNAconc_from_manta_reef`,
  and the tow-level combined-count responses `manta_from_{surf,deep}_combined_tow_cots`. The other
  posteriors are unchanged (the manta-as-response models on the COTS-or-scar presence indicator,
  and every coral and non-manta model).
- **Behaviour change in `GBR_calibrate(from = "Manta")`:** `from.scars` now takes the number of
  scars counted on each tow. Numeric values were previously read as 0/1 presence and are now read
  as counts. The codes `"a"`, `"p"`, `"c"` are still accepted and are converted to 0, 2 and 11
  scars (with a message). The `Manta_scars` output column is now the total number of scars (it was
  the number of tows with scars) and `Manta_density` = (COTS + scars) / tows.
- `predictor_range.csv`: the manta rows now give the range of the new index (tow 0-20, cull site
  0-7, reef 0-2.15), which also sets the default `GBR_curve()` grid and the `observed` flag.
- Docs, README and tests updated (new test: code-to-count conversion and numeric counts; the
  direct-calculation test for `surf_from_manta_reef_cots` allows 6% rather than 3% because the new
  reef-level posterior has a heavier tail and `GBR_calibrate()` averages a 2000-draw subsample).

## 0.4.1 -- fix predictor offset (`eps`) for 25 COTS models

- **Bug fix.** `model_registry.csv` recorded `eps = 1e-04` for the 24
  cross-method COTS models (manta, ReefScan Surface and ReefScan Deep, all
  levels) and for `eDNAprop_from_surf_reef`. The bundled posteriors were fitted
  with `eps = 0.01` (the BR-04 production value since 2026-10-08), so
  `GBR_calibrate()`, `GBR_curve()` and the model descriptions were adding the
  wrong constant inside `log(x + eps)`. Predictions at low or zero density were
  affected most (for `x = 0`, `log(0.0001)` is about -9.2 against about -4.6
  with the fitted 0.01); the difference fades as density grows. All 34
  Negative Binomial and Binomial models now carry `eps = 0.01`, and the model
  notes (shown by `GBR_posterior()`) say so. Coral (Beta) models do not use
  `eps`.
- The binomial prediction branch now stops with an informative error if the
  link stored on a bundled posterior (`attr(post, "link")`) disagrees with the
  registry link, and for any link other than logit or cloglog. No bundled model
  trips this today.
- New tests: every non-Beta registry row has `eps = 0.01`; the tow-level
  cloglog models match a direct calculation from the posterior; the link guard.
- README output regenerated.

## 0.4.0 -- `GBR_curve()` and `GBR_posterior()`

- New `GBR_curve(from, to, level, x, nPoints, to.effort, to.nTows, to.type,
  intLevel)` returns the whole calibration curve for a pair of tools: the
  mean, confidence band and prediction band over a grid of predictor values,
  plus an `observed` flag marking where the grid lies within the range of the
  BR-04 data. It has a base-graphics `plot()` method and carries axis labels
  as attributes. It uses the same tool names, models and default efforts as
  `GBR_calibrate()`.
- New `GBR_posterior(from, to, level, to.type, summary)` returns the bundled
  posterior draws as a data frame (or a per-parameter summary), with a
  `model_info` attribute describing the model and how its parameters combine.
  No Bayesian software is needed.
- New `inst/extdata/predictor_range.csv`: the observed range of each
  predictor, by tool and level, used for the default curve grid and the
  `observed` flag.
- `DESCRIPTION` now imports graphics and grDevices.

## 0.3.0 -- redesigned around a single function, `GBR_calibrate()`

The package now follows the structure of RosettaCOTS: one exported function,
fitted posteriors bundled in `inst/extdata`, one help page, and a README that
doubles as the vignette.

- New `GBR_calibrate(from, to, level, from.metric, from.effort, from.scars,
  to.effort, to.nTows, to.type, sites, intLevel)`. It takes observations in
  the units each tool is normally reported in, aggregates them by site,
  converts them to the predictors the models were fitted on, chooses the model
  from `from`, `to` and `level`, and returns one row per site with the input
  summary, the assumed effort, the prediction, confidence interval and
  prediction interval.
- It is now the only exported function. The 52 `pred*From*()` wrappers, the
  three curve engines, `rosetta_models()`, `rosetta_predict()` and
  `rosetta_posterior()` are gone (the engines are internal).
- The re-exported RosettaCOTS D-02 wrappers were removed; use
  `RosettaCOTS::COTS_calibrate()` for the D-02 site-level models. RosettaGBR
  no longer depends on or suggests RosettaCOTS.
- Typical efforts used when none is supplied (median of the BR-04 data):
  1 / 3 / 27 tows for tow / cull-site / reef, 188.6 m tows, 48 eDNA assays and
  24 eDNA samples per reef.
- The vignette was replaced by the README (`README.Rmd`).
- `DESCRIPTION` no longer imports tibble.

The earlier wrapper-based interface remains in the git history (v0.2.0).

## 0.2.0 -- bundled posteriors, standalone package

- The posterior draws for all 52 BR-04 models are now bundled in
  `inst/extdata/posteriors/` (about 10 MB). Only the population-level columns
  needed for prediction are kept (`alpha`/`beta` plus `phi` or `r` where
  relevant), together with the `link` attribute and, for the reef-level
  Binomial models, the observation-level reef SD draws. The package no longer
  depends on any external files.
- New `rosetta_posterior(model_name)` loads a bundled posterior.
- Every `pred*From*()` wrapper and `rosetta_predict()` now default to
  `post = NULL`, which uses the bundled posterior. Passing your own `post`
  works as before.
- `predBinomialCurve()` now honours an `obs_re_sd` attribute on the posterior:
  the prediction interval draws a new reef's observation-level effect, so it
  reflects between-reef overdispersion. Mean curves and credible intervals are
  unchanged. This affects the 7 reef-level Binomial models.
- `data-raw/build_posteriors.R` rebuilds the bundle from a directory of full
  posterior files.
- The vignette now uses the bundled posteriors instead of toy draws.
- Tests cover every bundled posterior and every wrapper.

## 2026-10-15 -- `predBetaCurve()` made link-aware (loglog support)

`manta_from_surf_{tow,cull,reef}` were switched from a logit to a loglog
link. Since `predBetaCurve()` previously hardcoded `stats::plogis()` as the
inverse link for every Beta model, predictions for these three models would
have been silently wrong with the refit posteriors.

`predBetaCurve()` now reads `attr(post, "link")` from the supplied posterior
matrix (defaulting to `"logit"` when absent, so every other model is
unaffected) and applies the matching inverse link: `plogis` for `"logit"`,
`exp(-exp(-eta))` for `"loglog"`. The attribute travels with the posterior,
so the generated wrappers do not need a `link` argument.

The registry's `link` column and notes for the three affected rows, the
generated wrappers and `.Rd` files, and the vignette were updated to match.

## 2026-10-06 -- D-02 / RosettaCOTS integration

The installed `RosettaCOTS` (v1.0.2) exports a single dispatcher,
`COTS_calibrate(from, to, from.metric, ...)`, built on 32 **unexported**
internal `pred*From*()` functions that each read their own bundled D-02
posterior. RosettaGBR's own design (bring-your-own-posterior, one function
per model, no bundled data) remains the right fit for the BR-04 models, but
is not architecturally identical to RosettaCOTS.

Added `pred*From*()` wrapper functions for all 32 of RosettaCOTS's D-02
models, generated rather than hand-written:

- `inst/extdata/d02_model_registry.csv`: one row per D-02 model
  (`model_name` is RosettaCOTS's own internal function name, verbatim,
  including its `predCullFromeDNAoonc` spelling).
- `data-raw/generate_d02_wrappers.R`: reads each function's actual signature
  from the installed `RosettaCOTS` namespace (via `formals()`) and writes a
  thin, signature-preserving pass-through wrapper to `R/wrappers_d02.R`,
  forwarding via `rosettacots_fn()` (`R/d02-helpers.R`,
  `utils::getFromNamespace()`). These are deliberately not reimplemented on
  RosettaGBR's own prediction engine, since each D-02 function does its own
  bespoke simulation.
- **Upstream issue worked around**: seven RosettaCOTS internal functions
  (`predDeepFromTransect`, `predDeepFromTransom`, `predMantaCoralFromDeep`,
  `predMantaCoralFromTransect`, `predMantaCoralFromTransom`,
  `predTransomFromDeep`, `predTransomFromTransect`) declare a default
  argument value of the bare symbol `newDensity`, which does not exist in
  RosettaCOTS, so calling them without supplying it errors with
  `object 'newDensity' not found`. The generator emits that argument as
  required (no default) instead.
- `rosetta_models()` gained a `source` argument (`"br04"` / `"d02"` / both)
  and a `source` column. `rosetta_predict()` gives a specific error if called
  with a D-02 model name.
- `DESCRIPTION`: `RosettaCOTS` added to `Suggests`, plus
  `Remotes: Scott-Foster/RosettaCOTS`.
- Verified that the generated `predCullFromManta()` wrapper is bit-identical
  to calling `RosettaCOTS:::predCullFromManta()` with the same seed.

## 2026-10-06 -- initial v0.1.0

Prediction engine (`predBetaCurve()` / `predNegBinCurve()` /
`predBinomialCurve()`) and the full 52-model BR-04 registry and wrapper set
(18 coral Beta and 34 COTS Negative Binomial / Binomial models, across tow,
cull-site and reef levels), generated from `inst/extdata/model_registry.csv`
via `data-raw/generate_wrappers.R`. Tested against synthetic posteriors
(`tests/testthat/`), with a self-contained vignette
(`manta-surface-coral-calibration`).
