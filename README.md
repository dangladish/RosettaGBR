
## RosettaGBR: translation between methods for measuring COTS and coral cover on the Great Barrier Reef

<!-- badges: start -->

[![R-CMD-check](https://github.com/dangladish/RosettaGBR/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/dangladish/RosettaGBR/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

## Summary

RosettaGBR is an R package that provides the results of a calibration
exercise between different methods for measuring Crown-of-Thorns
Starfish (COTS) and coral cover on the Great Barrier Reef (GBR). Its
main function `GBR_calibrate` is a tool that predicts one measure from
another, along with confidence and prediction intervals. Two further
functions help with analysing the results: `GBR_curve` returns the whole
calibration curve for a pair of tools, and `GBR_posterior` returns the
fitted posterior draws. RosettaGBR is built upon data obtained during
2025/2026 Reef Joint Field Management Program (RJFMP) trips, and extends
[RosettaCOTS](https://github.com/Scott-Foster/RosettaCOTS), which
presents the site-level calibration models from the CCIP D-02 field
trip. Where RosettaCOTS works at the site level, RosettaGBR works at
three spatial levels: the individual manta tow, the cull site and the
reef. It presents the results of the pair-wise models of the methods
that measure COTS and of the methods that measure coral cover. The
fitted models are bundled with the package.

The COTS measurement methods are:

- Manta Tow (`Manta`): the number of COTS seen on each tow, and a
  feeding-scar code for each tow (absent, present or common). Used
  together, as a combined density of COTS plus tows with scars.
- ReefScan Surface (`ReefScan_surface`): COTS detected in images taken
  from a camera system towed behind the vessel (the “Transom”). Effort
  is the number of tows.
- ReefScan Deep (`ReefScan_deep`): as ReefScan Surface, except that
  images were taken using a different measurement platform.
- eDNA concentration (`eDNA_conc`): the concentration (quantitative
  measure) from each PCR assay. There is a hierarchy to this sampling:
  multiple samples at a reef, and replicate assays on each sample.
- eDNA proportion (`eDNA_prop`): as eDNA concentration, except that the
  measure is dichotomous (presence/absence of COTS eDNA in a sample).
  This is accumulated to the reef by taking the proportion of positive
  samples.

The coral cover measurement methods are:

- Manta Tow (`coral_manta`): an ordinal hard coral cover category for
  each tow, converted to the category midpoint.
- ReefScan Surface (`coral_surface`): the proportion of classified image
  points that are hard coral.
- ReefScan Deep (`coral_deep`): as ReefScan Surface, except that images
  were taken using a different measurement platform.

The tool names are the values used for the `from` and `to` arguments.
Predictions can only be made within COTS measurements and within coral
measurements. The models are Beta regression (coral cover), Negative
Binomial regression (COTS counts) and Binomial regression (COTS
presence/absence), with reef included as a random effect where the data
allow. Every pair is modelled in both directions. How to use the package
is illustrated further below. Note that this README is performing a
similar role to that of a vignette (so there is no vignette).

### Installation

The `RosettaGBR` package can be installed using the `remotes` (or
`devtools`) R package.

``` r
install.packages('remotes')
remotes::install_github(repo = "dangladish/RosettaGBR")
```

## Which pairs are available

Every pair of tools exists at reef level. Cull-site and tow level exist
for the manta tow and ReefScan tools but not for eDNA, which is only
sampled at the reef. Predicting a manta COTS *count* is possible from
the ReefScan tools only; predicting manta *presence* is possible from
every COTS tool.

| from             | to               | levels               |
|:-----------------|:-----------------|:---------------------|
| eDNA_conc        | eDNA_prop        | reef                 |
| eDNA_conc        | Manta            | reef                 |
| eDNA_conc        | ReefScan_surface | reef                 |
| eDNA_prop        | eDNA_conc        | reef                 |
| eDNA_prop        | Manta            | reef                 |
| eDNA_prop        | ReefScan_surface | reef                 |
| Manta            | eDNA_conc        | reef                 |
| Manta            | eDNA_prop        | reef                 |
| Manta            | ReefScan_deep    | tow, cull_site, reef |
| Manta            | ReefScan_surface | tow, cull_site, reef |
| ReefScan_deep    | Manta            | tow, cull_site, reef |
| ReefScan_deep    | ReefScan_surface | tow, cull_site, reef |
| ReefScan_surface | eDNA_conc        | reef                 |
| ReefScan_surface | eDNA_prop        | reef                 |
| ReefScan_surface | Manta            | tow, cull_site, reef |
| ReefScan_surface | ReefScan_deep    | tow, cull_site, reef |

COTS pairs and the levels at which they are available.

The three coral cover tools (`coral_manta`, `coral_surface`,
`coral_deep`) can each be predicted from either of the other two, at
tow, cull-site and reef level.

## Using the package

The main function is `GBR_calibrate`. You give it the observations from
the `from` tool in the units they are normally recorded in, a label for
the site each observation belongs to, and the tool you want to predict.
It returns one row per site, with a summary of your input data, the
effort assumed for the prediction, the predicted value, a confidence
interval (how far the mean prediction may vary) and a prediction
interval (how far a new observation may vary). The `level` argument says
whether observations are tows, or are combined within cull sites or
reefs.

### Coral cover

Here we predict what manta tow coral cover would be at two reefs, given
ReefScan Surface cover (proportions) from several tows at each.

``` r
library(RosettaGBR)
set.seed(7416)

surf <- data.frame(
  reef  = rep(c("reefA", "reefB"), each = 5),
  cover = c(0.10, 0.15, 0.20, 0.12, 0.18, 0.40, 0.45, 0.35, 0.50, 0.42)
)

GBR_calibrate(
  from = "coral_surface", to = "coral_manta", level = "reef",
  from.metric = surf$cover, sites = surf$reef
)
#>    site coral_surface_cover coral_surface_nObs mean_coral_manta lowerCI_coral_manta upperCI_coral_manta lowerPI_coral_manta upperPI_coral_manta
#> 1 reefA               0.150                  5         0.236890           0.2063297           0.2712871          0.09222477           0.4220530
#> 2 reefB               0.424                  5         0.436909           0.3571007           0.5190252          0.23456966           0.6367375
```

The manta tow categories can be supplied as they are recorded (`"0"`,
`"1-"`, `"1+"`, …, `"5+"`) and are converted to their midpoints.

### COTS from manta tows

Manta tows need the COTS seen on each tow (`from.metric`) and the
feeding-scar code of each tow (`from.scars`: `"a"`, `"p"` or `"c"`).
Here we predict the number of COTS that ReefScan Surface would detect
over 27 tows (the median number of tows at a reef in the BR-04 data, and
the default) at two reefs.

``` r
manta <- data.frame(
  reef  = rep(c("reefA", "reefB"), each = 6),
  cots  = c(0, 0, 1, 0, 0, 0, 0, 2, 1, 0, 3, 1),
  scars = c("a", "a", "p", "a", "a", "a", "p", "p", "p", "a", "c", "p")
)

GBR_calibrate(
  from = "Manta", to = "ReefScan_surface", level = "reef",
  from.metric = manta$cots, from.scars = manta$scars, sites = manta$reef
)
#> Predictions are made using 27 tows (median of the BR-04 data at this level).
#>    site Manta_COTS Manta_scars Manta_tows Manta_density ReefScan_surface_nTows mean_ReefScan_surface lowerCI_ReefScan_surface upperCI_ReefScan_surface lowerPI_ReefScan_surface upperPI_ReefScan_surface
#> 1 reefA          1           1          6     0.3333333                     27              3.570544                0.6926795                  22.0624                        0                  24.0250
#> 2 reefB          7           5          6     2.0000000                     27             49.118136                2.7783756                 457.3918                        0                 457.3918
```

The effort assumed in the prediction can be changed with `to.nTows` (for
a cull site or reef), so that a prediction for 10 tows is

``` r
GBR_calibrate(
  from = "Manta", to = "ReefScan_surface", level = "reef",
  from.metric = manta$cots, from.scars = manta$scars, sites = manta$reef,
  to.nTows = 10
)
#>    site Manta_COTS Manta_scars Manta_tows Manta_density ReefScan_surface_nTows mean_ReefScan_surface lowerCI_ReefScan_surface upperCI_ReefScan_surface lowerPI_ReefScan_surface upperPI_ReefScan_surface
#> 1 reefA          1           1          6     0.3333333                     10              1.257901                0.2614193                 7.231467                        0                     9.00
#> 2 reefB          7           5          6     2.0000000                     10             18.749274                0.9547399               177.310041                        0                   177.31
```

### Predicting manta tows

When the manta tow is the tool being predicted, there are two kinds of
prediction, chosen by `to.type`. The default, `"presence"`, is the
probability that a tow has a scar present or at least one COTS seen (at
cull-site and reef level, the proportion of `to.nTows` tows that do).
The alternative, `"count"`, is the combined COTS-plus-scar count, and is
only available from the ReefScan tools. At tow level the effort is the
tow distance in metres (`to.effort`).

``` r
# eDNA detections (0/1) for the 24 samples taken at a reef
detections <- c(rep(1, 6), rep(0, 18))

GBR_calibrate(
  from = "eDNA_prop", to = "Manta", level = "reef",
  from.metric = detections, sites = rep("reefA", length(detections)),
  to.type = "presence"
)
#> Predictions are made using 27 tows (median of the BR-04 data at this level).
#>    site eDNA_prop_samples eDNA_prop Manta_presence_nTows mean_Manta_presence lowerCI_Manta_presence upperCI_Manta_presence lowerPI_Manta_presence upperPI_Manta_presence
#> 1 reefA                24      0.25                   27          0.02721077            0.009998479             0.05155126                      0              0.2601852

# Tow level: one row per tow, ReefScan Surface counts from three tows
GBR_calibrate(
  from = "ReefScan_surface", to = "Manta", level = "tow",
  from.metric = c(0, 1, 3), to.type = "count", to.effort = 200
)
#>    site ReefScan_surface_COTS ReefScan_surface_effort ReefScan_surface_density Manta_count_distance_m mean_Manta_count lowerCI_Manta_count upperCI_Manta_count lowerPI_Manta_count upperPI_Manta_count
#> 1 tow_1                     0                       1                        0                    200      0.003270746        0.0008748721         0.007735527                   0         0.007735527
#> 2 tow_2                     1                       1                        1                    200      0.389610395        0.1078433401         0.958992487                   0         3.000000000
#> 3 tow_3                     3                       1                        3                    200      0.709080723        0.1766294763         1.931767472                   0         4.000000000
```

### eDNA

For `eDNA_conc`, `from.metric` is the concentration of each PCR assay,
and the predictor is the total concentration per assay. When `eDNA_conc`
is the tool being predicted, the prediction is the total concentration
over `to.effort` assays (default 48). For `eDNA_prop` it is a proportion
of `to.effort` samples (default 24). Both exist at reef level only.

## Calibration curves

`GBR_curve` returns the whole calibration curve for a pair of tools
rather than predictions for particular observations: the expected value
of the `to` tool over a grid of values of the `from` tool, with
confidence and prediction intervals. It uses the same tool names,
levels, `to.type`, `to.nTows` and `to.effort` as `GBR_calibrate`. The
result is an ordinary data frame, ready for `ggplot2` or any other
plotting tool, and it has a `plot` method that draws the mean, the
confidence band and the prediction band. The mean line is dashed where
the curve is an extrapolation beyond the range of the predictor in the
BR-04 data (the `observed` column).

``` r
set.seed(2931)
par(mfrow = c(1, 2))

# How manta tow coral cover relates to ReefScan Surface cover, by reef
cover_curve <- GBR_curve(from = "coral_surface", to = "coral_manta", level = "reef")
plot(cover_curve)

# Chance that a manta tow finds COTS or scars, as ReefScan Surface density rises
cots_curve <- GBR_curve(from = "ReefScan_surface", to = "Manta", level = "tow")
#> Predictions are made using 188.6 metre tows (median of the BR-04 data).
plot(cots_curve)
```

![](README_files/figure-gfm/curve-1.png)<!-- -->

``` r
head(cots_curve)
#>             x        mean      lowerCI     upperCI lowerPI     upperPI observed
#> 1 0.000000000 0.003232692 0.0008312731 0.008715772       0 0.008715772     TRUE
#> 2 0.001122334 0.011113177 0.0042192303 0.022502677       0 0.022502677     TRUE
#> 3 0.004489338 0.021721790 0.0094431926 0.039684184       0 0.039684184     TRUE
#> 4 0.010101010 0.032696769 0.0146152247 0.057407952       0 1.000000000     TRUE
#> 5 0.017957351 0.043838563 0.0195946727 0.075850394       0 1.000000000     TRUE
#> 6 0.028058361 0.055078719 0.0247881502 0.095141864       0 1.000000000     TRUE
```

The axis labels are kept with the curve, so the scale of `x` and of the
prediction is always recorded.

``` r
attr(cots_curve, "xlab")
#> [1] "ReefScan_surface density (COTS per tow)"
attr(cots_curve, "ylab")
#> [1] "Probability a tow has a scar or COTS"
```

You can give your own grid of predictor values with `x`, and the `x`
scale is the one the models were fitted on: a proportion for coral cover
and `eDNA_prop`, COTS per tow for the ReefScan tools, the combined
density for `Manta` (COTS seen plus tows with scars, per tow), and the
concentration per assay for `eDNA_conc`. Overlaying your own
observations is then a matter of adding points to the plot.

## Posterior draws

`GBR_posterior` returns the fitted posterior draws behind a pair of
tools, as an ordinary data frame with one row per draw. No Bayesian
software is needed to use them. The draws are for the average reef
(group effects are set to zero).

``` r
draws <- GBR_posterior(from = "coral_surface", to = "coral_manta", level = "reef")
head(draws)
#>        alpha     beta      phi
#> 1 -0.7148631 2.285596 36.08983
#> 2 -0.5553514 1.543406 21.92564
#> 3 -0.8206184 2.714107 25.74112
#> 4 -0.9710413 3.311695 20.27698
#> 5 -0.4935571 1.277098 30.22880
#> 6 -0.5977761 1.710061 20.87790
```

The `model_info` attribute says which model it is and how the parameters
combine:

``` r
attr(draws, "model_info")$equation
#> [1] "Beta regression, loglog link. mean = exp(-exp(-eta)) with eta = alpha + beta * x; x = ReefScan_surface hard coral cover (proportion). Response ~ Beta(mean * phi, (1 - mean) * phi), so phi is the precision. Group effects (reef) are set to zero."
```

A one-row-per-parameter summary is available with `summary = TRUE`:

``` r
GBR_posterior(from = "Manta", to = "ReefScan_surface", level = "reef", summary = TRUE)
#>   parameter       mean        sd        q2.5        q50     q97.5
#> 1     alpha -1.0888677 1.1646544 -2.77296452 -1.2583890 1.7072765
#> 2      beta  1.1741258 0.3749211  0.53376349  1.1470541 1.9822017
#> 3         r  0.2738394 0.2093011  0.05694921  0.2185941 0.8364702
```

and the draws can be used for your own calculations. For example, the
posterior distribution of manta tow coral cover when ReefScan Surface
cover is 30%:

``` r
info <- attr(draws, "model_info")
eta <- draws$alpha + draws$beta * 0.3
mu <- if (info$link == "loglog") exp(-exp(-eta)) else plogis(eta)
quantile(mu, c(0.025, 0.5, 0.975))
#>      2.5%       50%     97.5% 
#> 0.3009403 0.3458816 0.3943262
```

The parameters are `alpha` and `beta` for every model, plus `phi` (Beta
precision, coral cover models), `r` (Negative Binomial size, COTS count
models), and `obs_re_sd` (the standard deviation of an observation-level
reef effect, reef-level presence models). See `?GBR_posterior` for
details.

### Intervals and randomness

The confidence and prediction intervals are 95% unless `intLevel` says
otherwise. Predictions are for the average reef. The prediction
intervals are simulated, so use `set.seed()` first if you need
reproducible numbers. Some pairs involving ReefScan Deep rest on very
few reefs; `GBR_calibrate` prints a message when such a model is used,
and these should be treated as exploratory.

See `?GBR_calibrate`, `?GBR_curve` and `?GBR_posterior` for the full
list of arguments and the units each tool expects.

## Funding

This package is an output of the COTS Control and Innovation Program
(CCIP) project BR-04 (Analysing RJFMP Data), which builds on the CCIP
\`Tool Comparison’ project (D-02).

## Contributing Software

Fork the `RosettaGBR` repository

Clone your fork using the command:

`git clone https://github.com/<username>/RosettaGBR.git`

Contribute to your forked repository.

Create a pull request.

If your code passes the necessary checks and is documented, your changes
and/or additions will be merged in the main `RosettaGBR` repository.

## Reporting Bugs

If you notice an issue with this repository, please report it using
[Github Issues](https://github.com/dangladish/RosettaGBR/issues). When
reporting an implementation bug, include a small example that helps to
reproduce the error (a non-working minimal example). The issue will be
addressed as quickly as possible.

## Seeking Support

If you have questions or need additional support, please open a [Github
Issues](https://github.com/dangladish/RosettaGBR/issues).
