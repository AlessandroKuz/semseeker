batch_correlation_check <- function() {

  ssEnv <- get_session_info()
  y <- g <- 1
  i <- 1
  sample_sheet <- utils::read.csv2(file.path(ssEnv$result_folderData,"sample_sheet_result.csv"))
  localKeys <- expand.grid("FIGURE"=ssEnv$keys_figures_default[,1],"MARKER"= ssEnv$keys_markers[,1])

  batch_analysis_folder <-dir_check_and_create(ssEnv$result_folderData,"Batch_Analysis")
  chartFolder <- dir_check_and_create(ssEnv$result_folderChart,"BATCH")

  to_export <- c("localKeys", "sample_sheet", "%dorng%", "g", "dir_check_and_create", "ssEnv", "file_path_build",
    "batch_analysis_folder", "iter", "RNGseed", "checkRNGversion", "getRNG", "%||%", ".getDoParName", "getDoParName",
    "getDoBackend", "setDoBackend", "RNGtype", "showRNG", "doRNGversion", ".getRNG", ".getRNGattribute", "hasRNG",
    "isNumber", "isReal", "isInteger", "nextRNG", ".foreachGlobals", "RNGkind", "setRNG", "RNGprovider",
    ".RNGkind_length", "tail", "RNGstr")

  # summary_cor <- foreach::foreach(i = 1:nrow(localKeys), .combine = rbind ) %dorng%
  for(i in 1:nrow(localKeys))
  {
    key <- localKeys[i,]
    sample_groups <- as.data.frame(unique(sample_sheet$Sample_Group))
    sub_export <- c(to_export,"sample_groups", "ssEnv","key")
    total_data_for <- foreach::foreach(g = 1:length(sample_groups), .combine = rbind, .export = sub_export ) %dorng%
      # for(g in 1:length(sample_groups))
      {
        pop <- sample_groups[g]
        tempresult_folderData <-dir_check_and_create(ssEnv$result_folderData,c(as.character(pop) ,paste(as.character(key$MARKER),"_",as.character(key$FIGURE),sep="")))
        file_to_read <- file_path_build(tempresult_folderData, c("MULTIPLE", as.character(key$MARKER), as.character(key$FIGURE)), "fst")
        if(file.exists(file_to_read))
        {
          temp <- fst::read_fst(file_to_read, as.data.table = T)
          if(key$MARKER=="MUTATIONS" | key$MARKER=="LESIONS")
            temp$VALUE <- 1
          # if(exists("total_data_for"))
          #   total_data_for <- rbind(total_data_for,temp)
          # else
          #   total_data_for <- temp
          temp
        }
      }

    total_data <- total_data_for
    rm(total_data_for)

    if(ncol(total_data)==4)
      colnames(total_data) <- c("CHR","START","END","SAMPLEID")

    if(ncol(total_data)==5)
      colnames(total_data) <- c("CHR","START","END","VALUE","SAMPLEID")

    if(plyr::empty(total_data))
      return()

    total_data$KEY <- paste(total_data$CHR, total_data$START, total_data$END, sep="_")
    total_data$VALUE <- as.numeric(total_data$VALUE)
    # create pivot
    tempDataFrame <- reshape2::dcast(data = total_data, formula = SAMPLEID ~ KEY, value.var = "VALUE",fun.aggregate = sum, drop = TRUE)

    tempDataFrame[is.na(tempDataFrame)] <-0

    if(key$MARKER!="DELTAS" & key$MARKER!="DELTAQ")
    {
      tempDataFrame <- as.data.frame(apply(tempDataFrame, 2, as.factor))
      rownames(tempDataFrame) <- tempDataFrame$SAMPLEID
      tempDataFrame <- t(tempDataFrame[,-1])
      tempDataFrame <- as.data.frame(tempDataFrame)
      # calculate FAMD
      if(length(unique(t(unique(tempDataFrame))))!=1 & !plyr::empty(tempDataFrame))
      {
        res.famd <- FactoMineR::FAMD(tempDataFrame, graph = FALSE)
        # res.famd$var$contrib
        pca_contrib <- as.data.frame(res.famd$var$contrib)
        pca_contrib$Sample_ID <- rownames(pca_contrib)
        pca_contrib <- merge(pca_contrib, sample_sheet[,c("Sample_ID","Batch_ID")], by="Sample_ID")
        pca_contrib$Batch_ID <- as.factor(pca_contrib$Batch_ID)
        pca_summary <- as.data.frame(res.famd$eig)
        pca_summary$dim <- gsub("comp ","Dim.",rownames(pca_summary))
        pca_summary <- pca_summary[,c("dim","cumulative percentage of variance")]
      }
      else
      {
        return()
        # pca_contrib <- NULL
        # pca_summary <- data.frame("dim"="NA","cumulative percentage of variance"="NA")
      }
    }
    else
    {
      # calculate PCA
      rownames(tempDataFrame) <- tempDataFrame$SAMPLEID
      tempDataFrame <- t(tempDataFrame[,-1])
      tempDataFrame <- as.data.frame(tempDataFrame)
      pca_result <- stats::prcomp(tempDataFrame, scale=FALSE)
      pca_summary <- summary(pca_result)
      pca_summary <- data.frame("proportion"=(pca_summary$importance["Cumulative Proportion",]))
      pca_summary$dim <- gsub("PC","Dim.",rownames(pca_summary))
      #
      # # get result of variables
      res.var <- factoextra::get_pca_var(pca_result)
      pca_contrib <- as.data.frame(res.var$contrib)
      pca_contrib$Sample_ID <- rownames(pca_contrib)
      pca_contrib <- merge(pca_contrib, sample_sheet[,c("Sample_ID","Batch_ID")], by="Sample_ID")
      pca_contrib$Batch_ID <- as.factor(pca_contrib$Batch_ID)
    }
    pca_contrib <- as.data.frame(pca_contrib)
    result_file <- file_path_build(batch_analysis_folder, c("pca_contrib", as.character(key$MARKER), as.character(key$FIGURE)), "csv")
    utils::write.csv2(pca_contrib,result_file,row.names = F)

    if(length(unique(t(unique(stats::na.omit(pca_contrib[,!(colnames(pca_contrib) %in% c("Batch_ID"))])))))==1
      | plyr::empty(stats::na.omit(pca_contrib)))
    {
      return()
    }
    pca_contrib_to_plot <- pca_contrib
    pca_contrib_to_plot$Batch_ID <- as.factor(paste("Batch",pca_contrib$Batch_ID, sep=""))

    filename = paste0( chartFolder ,"/","scatterplot_",key$MARKER,"_",key$FIGURE, ".png",sep="")
    # print(filename)
    # grDevices::png(file= filename, width=2480, height = 2480, pointsize = 15, res = 144)
    ggplot2::qplot("Dim.1", "Dim.2", data= as.data.frame(pca_contrib_to_plot),
      col = "Batch_ID", xlab="Dimension 1", ylab="Dimension 2",
      main = paste(key$MARKER, " ", key$FIGURE, sep="") ) + ggplot2::labs( colour= "Batch_ID") + ggplot2::theme(legend.position = "bottom")
    # grDevices::dev.off()
    ggplot2::ggsave(
      filename,
      plot = ggplot2::last_plot(),
      scale = 1,
      width = 2480,
      height = 2480,
      units = c("px"),
      dpi = 144
    )
    # calculate correlation
    pca_contrib <- pca_contrib[,-1]
    cor.result <- Hmisc::rcorr(x = as.matrix(pca_contrib),type = c("spearman"))
    result_cor <- data.frame("p.value"=cor.result$P[,"Batch_ID"], "rho"=cor.result$r[,"Batch_ID"])
    result_cor <- result_cor[order(result_cor$p.value),]

    # save data checked
    result_cor <- result_cor[-(which(rownames(result_cor)=="Batch_ID")),]
    result_cor$dim <- rownames(result_cor)

    result_cor <- merge(result_cor, pca_summary, by="dim")

    #calculate association with dunn test

    kk <- colnames(pca_contrib[,-(which(colnames(pca_contrib)=="Batch_ID" | colnames(pca_contrib)=="Sample_ID"))])
    # dunn.results <- foreach::foreach(y = 1: length(kk), .combine= "rbind", .export = c("kk","pca_contrib")) %dorng%
    for( y in 1: length(kk))
    {
      k.formula <- stats::as.formula(paste(kk[y], "Batch_ID", sep = "~"))
      k.result <- stats::kruskal.test( k.formula, data = pca_contrib)
      dunn.result <- FSA::dunnTest( k.formula,data=pca_contrib,method="bh")
      dunn.result <- as.data.frame(t(dunn.result$res[c("Comparison","P.adj")]))
      colnames(dunn.result) <- dunn.result[1,]
      dunn.result <- dunn.result[-1,]
      dunn.result$dunn.p.value <- any(dunn.result < 0.05)
      dunn.result$dim <- kk[y]
      dunn.result$kruskal.wallis.p.value <- k.result$p.value
      if(exists("dunn.results"))
        dunn.results <- rbind(dunn.results,dunn.result)
      else
        dunn.results <- dunn.result
      # dunn.result
    }
    result_cor <- merge(result_cor, dunn.results, by="dim")
    rm(dunn.results)

    result_file <- file_path_build(batch_analysis_folder, c("batch_cor", as.character(key$MARKER), as.character(key$FIGURE)), "csv")
    utils::write.csv2(result_cor,result_file,row.names = F)

    result_cor <- subset(result_cor, result_cor$p.value < 0.05)
    result_cor <- subset(result_cor, result_cor$proportion < 0.7)
    if(!plyr::empty(result_cor))
    {
      result_cor$marker <- key$MARKER
      result_cor$figure <- key$FIGURE
    }

    if(exists("summary_cor"))
      summary_cor <- rbind(result_cor,summary_cor)
    else
      summary_cor <- result_cor
    # result_cor
  }
  result_file <- file_path_build(batch_analysis_folder, c("result","cor"), "csv")
  utils::write.csv2(summary_cor,result_file,row.names = F)

}
