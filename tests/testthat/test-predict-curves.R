test_that("predBetaCurve returns the expected shape and errors on bad input", {
  set.seed(101)
  post <- cbind(alpha = rnorm(300, -1, 0.2), beta = rnorm(300, 2, 0.2), phi = rgamma(300, 10, 1))
  out <- predBetaCurve(post, x = seq(0, 1, length.out = 5), n_draws = 200)
  expect_s3_class(out, "tbl_df")
  expect_named(out, c("x", "mean", "lo95", "hi95", "pi_lo95", "pi_hi95"))
  expect_equal(nrow(out), 5)
  # positive beta -> mean should be increasing in x
  expect_true(all(diff(out$mean) > 0))
  # CI should nest inside PI
  expect_true(all(out$pi_lo95 <= out$lo95 + 1e-8))
  expect_true(all(out$pi_hi95 >= out$hi95 - 1e-8))

  expect_error(predBetaCurve(cbind(alpha = 1, beta = 1), x = 0), "missing required column")
})

test_that("predNegBinCurve returns the expected shape, respects offset, and PI never narrower than CI", {
  set.seed(102)
  post <- cbind(alpha = rnorm(300, -1, 0.2), beta = rnorm(300, 0.8, 0.2), r = rgamma(300, 2, 1))
  x <- c(0, 0.5, 1, 2)
  out <- predNegBinCurve(post, x, offset = log(10), eps = 0.01, n_draws = 200)
  expect_named(out, c("x", "mean", "lo95", "hi95", "pi_lo95", "pi_hi95"))
  expect_true(all(out$pi_lo95 <= out$lo95 + 1e-8))
  expect_true(all(out$pi_hi95 >= out$hi95 - 1e-8))

  out_bigger_offset <- predNegBinCurve(post, x, offset = log(1000), eps = 0.01, n_draws = 200)
  expect_true(all(out_bigger_offset$mean > out$mean))
})

test_that("predBinomialCurve supports logit and cloglog links and records pi_size", {
  set.seed(103)
  post <- cbind(alpha = rnorm(300, -2, 0.2), beta = rnorm(300, 1, 0.2))
  x <- c(0, 0.5, 1)

  out_logit <- predBinomialCurve(post, x, eps = 0.01, link = "logit", size = 1, n_draws = 200)
  expect_true(all(out_logit$mean >= 0 & out_logit$mean <= 1))
  expect_equal(attr(out_logit, "pi_size"), 1)

  out_cloglog <- predBinomialCurve(post, x, offset = log(50), eps = 0.01, link = "cloglog", size = 1, n_draws = 200)
  expect_true(all(out_cloglog$mean >= 0 & out_cloglog$mean <= 1))

  out_size5 <- predBinomialCurve(post, x, eps = 0.01, link = "logit", size = 5, n_draws = 200)
  expect_equal(attr(out_size5, "pi_size"), 5)
})
