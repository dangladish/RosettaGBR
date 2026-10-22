reg_br04 <- rosetta_models(source = "br04")

test_that("every BR-04 model has a well-formed bundled posterior", {
  for (i in seq_len(nrow(reg_br04))) {
    m <- reg_br04$model_name[i]
    post <- rosetta_posterior(m)
    needed <- switch(reg_br04$family[i],
      beta = c("alpha", "beta", "phi"),
      negbin = c("alpha", "beta", "r"),
      binomial = c("alpha", "beta")
    )
    expect_true(is.matrix(post) && is.numeric(post), info = m)
    expect_true(all(needed %in% colnames(post)), info = m)
    expect_true(nrow(post) >= 2000, info = m)
    expect_false(anyNA(post), info = m)
    if (!is.null(attr(post, "link"))) expect_equal(attr(post, "link"), reg_br04$link[i], info = m)
  }
})

test_that("loglog coral models carry their link, others default to logit", {
  for (m in c("manta_from_surf_tow", "manta_from_surf_cull", "manta_from_surf_reef")) {
    expect_equal(attr(rosetta_posterior(m), "link"), "loglog", info = m)
  }
  expect_null(attr(rosetta_posterior("surf_from_manta_tow"), "link"))
})

test_that("reef-level binomial models carry a valid observation-level reef SD column", {
  post <- rosetta_posterior("manta_from_surf_binary_reef_cots")
  col <- attr(post, "obs_re_sd")
  expect_true(col %in% colnames(post))
  expect_true(all(post[, col] > 0))
})

test_that("every wrapper runs with no `post` argument and returns a sane tibble", {
  set.seed(3017)
  for (i in seq_len(nrow(reg_br04))) {
    m <- reg_br04$model_name[i]
    fn <- get(reg_br04$wrapper_fun[i], mode = "function")
    x <- if (reg_br04$family[i] == "beta") c(0.1, 0.5, 0.9) else c(0, 0.5, 2)
    args <- list(x = x, n_draws = 200)
    if ("size" %in% names(formals(fn))) args$size <- 5
    out <- do.call(fn, args)
    expect_s3_class(out, "tbl_df")
    expect_equal(nrow(out), 3, info = m)
    expect_true(all(is.finite(as.matrix(out))), info = m)
    expect_true(all(out$pi_lo95 <= out$lo95 + 1e-12), info = m)
    expect_true(all(out$pi_hi95 >= out$hi95 - 1e-12), info = m)
  }
})

test_that("the default posterior matches an explicit rosetta_posterior() call", {
  set.seed(5)
  a <- predMantaFromSurfTow(x = c(0.2, 0.6), n_draws = 300)
  set.seed(5)
  b <- predMantaFromSurfTow(rosetta_posterior("manta_from_surf_tow"), x = c(0.2, 0.6), n_draws = 300)
  expect_equal(a, b)
  set.seed(5)
  d <- rosetta_predict("manta_from_surf_tow", x = c(0.2, 0.6), n_draws = 300)
  expect_equal(a, d)
})

test_that("a new-reef effect widens the binomial prediction interval only", {
  post <- rosetta_posterior("manta_from_surf_binary_reef_cots")
  post_no_re <- post
  attr(post_no_re, "obs_re_sd") <- NULL
  set.seed(11)
  with_re <- predBinomialCurve(post, x = 0.5, link = "logit", size = 50, n_draws = 1500)
  set.seed(11)
  without_re <- predBinomialCurve(post_no_re, x = 0.5, link = "logit", size = 50, n_draws = 1500)
  expect_equal(with_re$lo95, without_re$lo95)
  expect_equal(with_re$hi95, without_re$hi95)
  expect_gt(with_re$pi_hi95 - with_re$pi_lo95, without_re$pi_hi95 - without_re$pi_lo95)
})

test_that("rosetta_posterior() errors clearly on unknown models", {
  expect_error(rosetta_posterior("nope"), "No bundled posterior")
})
