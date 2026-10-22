test_that("rosetta_models() returns a well-formed, de-duplicated registry", {
  reg <- rosetta_models(source = "br04")
  expect_s3_class(reg, "tbl_df")
  expect_false(any(reg$is_diagnostic))
  expect_equal(nrow(reg), length(unique(reg$model_name)))
  expect_true(all(reg$family %in% c("beta", "negbin", "binomial")))
  expect_true(all(reg$level %in% c("tow", "cull_site", "reef")))

  reg_all <- rosetta_models(include_diagnostic = TRUE, source = "br04")
  expect_true(nrow(reg_all) > nrow(reg))
  expect_true(all(is.na(reg_all$wrapper_fun[reg_all$is_diagnostic])))
})

test_that("rosetta_models() default includes both br04 and d02 sources, uniquely", {
  reg <- rosetta_models()
  expect_setequal(unique(reg$source), c("br04", "d02"))
  expect_equal(nrow(reg), length(unique(paste(reg$source, reg$model_name))))
  expect_equal(nrow(rosetta_models(source = "d02")), 32)

  reg <- rosetta_models()
  d02 <- reg[reg$source == "d02", ]
  expect_false(any(d02$is_diagnostic))
  expect_true(all(is.na(d02$family)))
})

test_that("every non-diagnostic model has a corresponding, correctly-named, exported wrapper function", {
  reg <- rosetta_models()
  for (fn_name in reg$wrapper_fun) {
    expect_true(exists(fn_name, mode = "function"), info = fn_name)
  }
  # spot-check the naming transform itself
  expect_equal(RosettaGBR:::model_name_to_wrapper("manta_from_surf_binary_cull_cots"), "predMantaFromSurfBinaryCullCots")
  expect_equal(RosettaGBR:::model_name_to_wrapper("eDNAconc_from_manta_reef"), "predEDNAconcFromMantaReef")
})

test_that("D-02 wrappers forward to RosettaCOTS's own internal function, not a reimplementation", {
  skip_if_not_installed("RosettaCOTS")
  set.seed(8831)
  direct <- RosettaGBR:::rosettacots_fn("predCullFromManta")(manta_scars = 10, manta.nTows = 4)
  set.seed(8831)
  via_wrapper <- predCullFromManta(manta_scars = 10, manta.nTows = 4)
  expect_equal(via_wrapper, direct)
})

test_that("rosetta_predict() dispatches to the correct family and matches the direct wrapper", {
  set.seed(104)
  post_beta <- cbind(alpha = rnorm(200, -1, 0.2), beta = rnorm(200, 2, 0.2), phi = rgamma(200, 10, 1))
  set.seed(1)
  a <- rosetta_predict("manta_from_surf_tow", post_beta, x = c(0, 0.5), n_draws = 200)
  set.seed(1)
  b <- predMantaFromSurfTow(post_beta, x = c(0, 0.5), n_draws = 200)
  expect_equal(a, b)

  expect_error(rosetta_predict("not_a_real_model", post_beta, x = 0), "Unknown model_name")
  expect_error(rosetta_predict("_d02_spotcheck_coral", post_beta, x = 0), "diagnostic")
})
