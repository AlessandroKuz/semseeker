
# sliding_window_size <- 11
# bonferroni_threshold <- 0.01
# grouping_column <- "GENE"
# mutationAnnotatedSortedLocal <- utils::read.csv2("/home/lcorsaro/Documents/SEMSEEKER_TEST_BWS/mutations_annotated_sorted_gene.csv")

#' @importFrom dplyr %>%
#' @importFrom rlang .data
lesions_get <- function(sliding_window_size, bonferroni_threshold, grouping_column, mutation_annotated_sorted)
{

  if( is.null(mutation_annotated_sorted))
    return (mutation_annotated_sorted)

  if(nrow(mutation_annotated_sorted)==0)
    return (mutation_annotated_sorted)

    # browser()
  mutationAnnotatedSortedLocal <- mutation_annotated_sorted
  summed <- stats::aggregate(mutationAnnotatedSortedLocal$MUTATIONS, by = list(mutationAnnotatedSortedLocal[,grouping_column]), FUN = sum)
  colnames(summed) <- c(grouping_column,"MUTATIONS_COUNT")
  counted <- stats::aggregate(mutationAnnotatedSortedLocal$MUTATIONS, by = list(mutationAnnotatedSortedLocal[,grouping_column]), FUN = length)
  colnames(counted) <- c(grouping_column,"PROBES_COUNT")
  mutationAnnotatedSortedLocal <- merge(mutationAnnotatedSortedLocal,summed, by = grouping_column)
  mutationAnnotatedSortedLocal <- merge(mutationAnnotatedSortedLocal,counted, by = grouping_column)
  rm(counted)
  rm(summed)

  #function to calculate rolled sum, returns a vector
  enrichement_calculator<-function(x,lags){
    missedWindowLength <- ((lags - 1) / 2)
    y <- c(rep(0,missedWindowLength))
    tmp <- c(y,x,y)
    tmp=zoo::rollsum( tmp, lags, align = "center", fill = 0)
    tmp <- tmp[(missedWindowLength+1):(missedWindowLength+ length(x))]
    tmp=as.numeric(tmp)
    return(tmp)
  }

  # browser()
  # calculate enrichment for each window
  mutationAnnotatedSortedLocal <- mutationAnnotatedSortedLocal %>% dplyr::group_by(eval(parse(text = grouping_column))) %>%
    dplyr::mutate(ENRICHMENT = stats::ave( .data$MUTATIONS, eval(parse(text = grouping_column)),
                                           FUN = function(x) enrichement_calculator(x, sliding_window_size))) %>% dplyr::ungroup ()

  basepair_calculator<-function(x,lags){
    tmp_min=-zoo::rollmax( -x, lags, align = "center", fill = 0)
    tmp_max=zoo::rollmax( x, lags, align = "center", fill = 0)
    tmp= tmp_max - tmp_min
    tmp=as.numeric(tmp)
    return(tmp)
  }
  #calculate the base pair count for each window
  mutationAnnotatedSortedLocal <- mutationAnnotatedSortedLocal %>% dplyr::group_by(eval(parse(text = grouping_column))) %>%
    dplyr::mutate(BASEPAIR_COUNT = stats::ave( .data$START, eval(parse(text = grouping_column)),
                                              FUN = function(x) basepair_calculator(x, sliding_window_size))) %>% dplyr::ungroup ()

  mutationAnnotatedSortedLocal$ENRICHMENT[ is.na(mutationAnnotatedSortedLocal$ENRICHMENT)] <- 0

  lesionpValue <- suppressWarnings(stats::dhyper(mutationAnnotatedSortedLocal$ENRICHMENT, mutationAnnotatedSortedLocal$MUTATIONS_COUNT, mutationAnnotatedSortedLocal$PROBES_COUNT, sliding_window_size))

  lesionpValue[is.nan(lesionpValue)] <- 1
  lesionpValue[is.na(lesionpValue)] <- 1

  tt <- data.frame(mutationAnnotatedSortedLocal,lesionpValue)

  ## correction by Bonferroni
  lesionWeighted <- (tt$lesionpValue ) < ( bonferroni_threshold/( length(tt$PROBES_COUNT) * log10(tt$BASEPAIR_COUNT) ))
  table(lesionWeighted)
  rm(tt)

  lesionWeighted <- data.frame(as.data.frame(mutationAnnotatedSortedLocal), "LESIONS" = lesionWeighted)

  lesionWeighted <- sort_by_chr_and_start(lesionWeighted)
  lesionWeighted <- subset(lesionWeighted, lesionWeighted$LESIONS == TRUE)[, c("CHR", "START", "END")]

  if (dim(lesionWeighted)[1] > dim(mutationAnnotatedSortedLocal)[1]) {

  }

  # message("INFO: ", Sys.time(), " Got lesions for sample !")
  return(lesionWeighted)

}
