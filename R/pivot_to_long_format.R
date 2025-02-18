#' Get the pivot in long format instead of wide format
#'
#' @param phenotype_column column from the sample sheet to pair to each sample
#' @param areas_selection genomic area to select, if NULL all areas will be selected
#' @param marker marker to filer HYPER, HYPO, BOTH
#' @param figure DELTAS, DELTAQ,DELTAR, MUTATIONS
#' @param group GENE, DMR ...
#' @param subgroup TSS1500 ...
#' @param sample_sheet sample sheet of samples
#'
#' @return the pivot in a long format of 3 columnns, the phontype column with name phenotype, the value of the marker and the area investigated
#'
pivot_to_long_format <- function (marker, figure, group,subgroup, phenotype_column,sample_sheet, areas_selection=NULL)
{

  ssEnv <- get_session_info()
  area_pivot <- get_pivot(marker, figure, group, subgroup)

  area_pivot <- subset(area_pivot, area_pivot$SAMPLEID=="SAMPLE_GROUP" | area_pivot$SAMPLEID %in% areas_selection)
  study_summary <-   utils::read.csv2(file_path_build( ssEnv$result_folderData, "sample_sheet_result","csv"))
  area_pivot <- area_pivot[-1,]
  for( s in 2: ncol(area_pivot))
  {
    # s <- 2
    temp <- area_pivot[,c(1,s)]
    phenotype <- sample_sheet[sample_sheet$Sample_ID== colnames(area_pivot)[s],phenotype_column]
    colnames(temp) <- c("AREA","VALUE")
    temp$phenotype <- phenotype
    temp$VALUE <- as.numeric(temp$VALUE)
    if(exists("res"))
      res <- rbind(res, temp)
    else
      res <- temp
  }
  return(res)
}
