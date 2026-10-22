# RosettaGBR Changelog

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
