test_that("inference_file_name", {

  ssEnv <- semseeker:::init_env(tempFolder,parallel_strategy = parallel_strategy)

  inference_details <- expand.grid("independent_variable"= "Phenotest",
    "covariates"=c("Covariates1+Covariates2"),
    "family_test"=c("gaussian"),
    "transformation"="logn",
    "depth_analysis"=3,
    "filter_p_value" = FALSE)

  fileToRead <- "3_Phenotest_logn_gaussian_Covariates1_Covariates2"
  fileNameResults <- semseeker:::file_path_build(ssEnv$result_folderInference,fileToRead, extension = "csv")
  testthat::expect_true(inference_file_name(inference_details)==fileNameResults)


})
