## RosettaGBR: translation between methods for measuring COTS and coral cover on the Great Barrier Reef

## Summary

RosettaGBR is an R package that provides prediction functions for a calibration exercise between different methods for measuring Crown-of-Thorns Starfish (COTS) and coral cover on the Great Barrier Reef (GBR). Each function predicts one measure from another, along with credible and prediction intervals. RosettaGBR is built upon data obtained from 2025/2026 Reef Joint Field Management Program (RJFMP) trips, and extends [RosettaCOTS](https://github.com/Scott-Foster/RosettaCOTS), which presents the site-level calibration models from an earlier CCIP field trip (project D-02). It provides 52 pairwise models at three spatial levels (individual manta tow, cull site and reef), and also re-exports RosettaCOTS's own 32 D-02 models under the same naming convention (see "D-02 models" below).

The COTS measurement methods are:

* Manta Tow: scars and COTS counts per tow segment, with tow distance as the measure of effort. Used at tow, cull-site and reef level.
* ReefScan Surface (Transom): COTS counts detected in images taken from a surface camera system towed behind the vessel. Effort is the number of tows.
* ReefScan Deep: COTS counts detected in images taken using a different measurement platform. Used at cull-site and reef level (and, exploratorily, tow level).
* eDNA (concentration): the concentration (quantitative measure) from the PCR assay, summed over all samples at a reef. Used at reef level only.
* eDNA (proportion): as eDNA (concentration), except that the measure is dichotomous (presence/absence of COTS eDNA in an assay), accumulated to the reef level as a number of positives out of the number of assays.

The coral cover measurement methods are:

* Manta Tow: ordinal coral cover categories for each tow, converted to proportion cover.
* ReefScan Surface (Transom): proportion of classified image points that are hard coral.
* ReefScan Deep: as ReefScan Surface, except that images were taken using a different measurement platform.

The models are Beta regression (coral cover), Negative Binomial regression (COTS counts) and Binomial regression (COTS presence/absence). Each pair of methods is modelled in both directions, with the other method's measure as the predictor. Details of each model (family, link, offset and predictor transform) are available from `rosetta_models()`. How to use the package is illustrated further below. Note that this README is performing a similar role to that of a vignette for the general workflow; there is also a worked example for the manta tow versus ReefScan Surface coral cover pair.

### Installation

The `RosettaGBR` package can be installed using the `remotes` (or `devtools`) R package.

```r
install.packages('remotes')
remotes::install_github(repo = "dangladish/RosettaGBR")
```

The D-02 wrappers additionally require `RosettaCOTS` to be installed (a `Suggests`, not an `Imports`, so users of the BR-04 models alone don't need it). It is installed automatically if you ask for suggested packages:

```r
remotes::install_github(repo = "dangladish/RosettaGBR", dependencies = TRUE)
# or directly
remotes::install_github(repo = "Scott-Foster/RosettaCOTS")
```

## Usage

This package does prediction only; it does not fit models. The 52 BR-04 functions do not bundle posterior samples or data, so you supply a posterior-samples matrix (one row per draw; columns `alpha`/`beta`/`phi` for Beta models, `alpha`/`beta`/`r` for Negative Binomial models, `alpha`/`beta` for Binomial models; population-level terms only, with group effects marginalised to zero). The 32 D-02 functions need no posterior argument, since RosettaCOTS supplies its own bundled posterior internally.

```r
library(RosettaGBR)

# See every available model (both BR-04 and D-02) and its conventions
rosetta_models()
rosetta_models(source = "br04")  # BR-04 only
rosetta_models(source = "d02")   # D-02 (RosettaCOTS) only

# --- BR-04 models: supply your own posterior matrix ---
# Each model has a dedicated wrapper function, derived mechanically from
# its model name (manta_from_surf_tow -> predMantaFromSurfTow)
post <- readRDS("path/to/manta_from_surf_tow.RDS")
predMantaFromSurfTow(post, x = seq(0, 1, by = 0.1))

# NegBin / Binomial models that were fit with a log-effort offset require
# you to supply a representative effort (e.g. mean n_tows, or a specific
# tow's distance) -- see each function's documentation for which method's
# effort it expects
post_nb <- readRDS("path/to/surf_from_manta_tow_cots.RDS")
predSurfFromMantaTowCots(post_nb, x = c(0, 0.5, 1, 2), offset = log(1))

# Binomial cull/reef "rate" models (trials()-based, no offset) require a
# representative trial count instead
post_bin <- readRDS("path/to/manta_from_surf_binary_reef_cots.RDS")
predMantaFromSurfBinaryReefCots(post_bin, x = c(0, 0.5, 1), size = 12)

# Programmatic / loop-friendly alternative to the named wrappers
rosetta_predict("manta_from_surf_tow", post, x = seq(0, 1, by = 0.1))

# --- D-02 models: no posterior argument needed, RosettaCOTS supplies one ---
predCullFromManta(manta_scars = c(0, 4, 10), manta.nTows = 4)
```

Every BR-04 prediction function returns a tibble with columns `x`, `mean` (posterior mean of the fitted curve), `lo95`/`hi95` (95% credible interval on the mean), and `pi_lo95`/`pi_hi95` (95% prediction interval for a new observation, guaranteed to bracket the credible interval; see `?predNegBinCurve` for why this union is necessary for overdispersed Negative Binomial fits). D-02 functions return whatever data frame shape RosettaCOTS's own internal function returns (see each function's own documentation).

Coral cover models use a logit link, except `manta_from_surf_{tow,cull,reef}`, which use a loglog link. The link travels with the posterior as `attr(post, "link")` (default `"logit"` when absent) and is read by `predBetaCurve()`, so callers never need to specify it.

See `vignette("manta-surface-coral-calibration", package = "RosettaGBR")` for a full worked example (registry lookup, prediction, plotting) using the manta tow versus ReefScan Surface coral cover pair.

## Relationship to RosettaCOTS

[RosettaCOTS](https://github.com/Scott-Foster/RosettaCOTS) supports the D-02 **site-level** pairwise calibration models. Its only *exported* function is a single dispatcher, `RosettaCOTS::COTS_calibrate(from, to, from.metric, ...)`, built on top of 32 **unexported internal** `pred*From*()` functions, each of which reads its own bundled D-02 posterior from RosettaCOTS's installed `extdata/` folder.

RosettaGBR's 52 BR-04 models are a **standalone successor**, not a dependency on RosettaCOTS: three spatial levels (tow / cull-site / reef) and three GLM families (Beta, Negative Binomial, Binomial). They follow RosettaCOTS's naming convention (`pred<Response>From<Predictor>...()`) and posterior-matrix contract so the two packages feel like one family, but these 52 functions are RosettaGBR's own code.

### D-02 models

RosettaGBR also re-exports RosettaCOTS's own 32 D-02 models under the same discoverable naming (e.g. `predMantaFromCull()`, `predCullFromManta()`): thin, signature-preserving pass-throughs to RosettaCOTS's unexported internals (via `getFromNamespace()`), not reimplementations. These are not built on RosettaGBR's own `predBetaCurve()`/`predNegBinCurve()`/`predBinomialCurve()` engine, since each D-02 function does its own bespoke simulation. See `CHANGELOG.md` for details, including an upstream RosettaCOTS issue that was worked around (seven functions declare a default argument, `newDensity`, that does not exist; the wrappers make it a required argument instead).

## Package structure

- `R/predict-curves.R`: the three family-specific prediction engines (`predBetaCurve()`, `predNegBinCurve()`, `predBinomialCurve()`). BR-04 models only.
- `R/predict-dispatch.R`: `rosetta_predict()`, a registry-driven dispatcher used internally by every BR-04 wrapper function (and usable directly).
- `R/registry.R`: `rosetta_models()` (merges both registries, with a `source` column) and the internal BR-04 model-name to wrapper-function-name transform.
- `R/wrappers.R`: BR-04's 52 wrappers, **generated, not hand-written**; see `data-raw/generate_wrappers.R`. Re-run that script (then `devtools::document()`) whenever `inst/extdata/model_registry.csv` changes.
- `inst/extdata/model_registry.csv`: one row per BR-04 model: family, spatial level, response/predictor method, link function, offset/eps convention, grouping, and the representative trial count used for Binomial prediction intervals.
- `R/wrappers_d02.R`: D-02's 32 pass-through wrappers, **generated, not hand-written**; see `data-raw/generate_d02_wrappers.R`. Re-run that script (then `devtools::document()`) whenever `inst/extdata/d02_model_registry.csv` changes, or a new RosettaCOTS version adds, renames or changes the signature of one of these functions.
- `inst/extdata/d02_model_registry.csv`: one row per D-02 model, with notes on which RosettaCOTS internal function and bundled posterior it forwards to.
- `R/d02-helpers.R`: `rosettacots_fn()`, the single call site used to look up each unexported RosettaCOTS internal function.

## Status

v0.1.0. Prediction engine plus the full 52-model BR-04 registry and wrapper set, and 32 D-02 pass-through wrappers. Tested against synthetic posteriors and, for the D-02 wrappers, a bit-for-bit equivalence check against calling RosettaCOTS's internal function directly (`tests/testthat/`). Not yet validated against real fitted posteriors end-to-end in an automated test.

## Funding

This package is an output of the COTS Control and Innovation Program (CCIP) project BR-04 (Analysing RJFMP Data), which builds on the CCIP `Tool Comparison' project (D-02).

## Contributing Software

Fork the `RosettaGBR` repository

Clone your fork using the command:

`git clone https://github.com/<username>/RosettaGBR.git`

Contribute to your forked repository.

Create a pull request.

If your code passes the necessary checks and is documented, your changes and/or additions will be merged in the main `RosettaGBR` repository.

## Reporting Bugs

If you notice an issue with this repository, please report it using [Github Issues](https://github.com/dangladish/RosettaGBR/issues). When reporting an implementation bug, include a small example that helps to reproduce the error (a non-working minimal example). The issue will be addressed as quickly as possible.

## Seeking Support

If you have questions or need additional support, please open a [Github Issues](https://github.com/dangladish/RosettaGBR/issues).
