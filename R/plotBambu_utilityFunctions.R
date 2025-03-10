#' plot annotation
#' @param se a SummarizedExperiment object
#' @param gene_id a list of gene id(s)
#' @param transcript_id a list of transcript id(s)
#' @noRd
plotAnnotation <- function(se, gene_id, transcript_id) {
    if (is.null(gene_id) & (is.null(transcript_id)))
        stop("Please provide the gene_id(s) of the gene of interest or
            transcript_id(s) for the transcripts of interest!")
    if (!("TXNAME" %in% colnames(rowData(se)))) {
        if (is.null(gene_id))
            stop("Please provide the gene_id(s) of the gene of interest
                when gene expression are provided!")
        if (!all(gene_id %in% rownames(se)))
            stop("all(gene_id %in% rownames(se)) condition is not satisfied!")
        geneRanges <- rowRanges(se)[gene_id]
        names(geneRanges) <- paste0(gene_id, ":", unlist(lapply(
            strand(geneRanges), function(x) unique(as.character(x)))))
        p_annotation <- ggbio::autoplot(geneRanges, group.selfish = TRUE)
        p_expression <-
            ggbio::autoplot(as.matrix(log2(assays(se)$CPM[gene_id, ] + 1)))
        p <- gridExtra::grid.arrange(p_annotation@ggplot, p_expression)
        return(p)
    } else {
        p <- plotAnnotation_withExpression(se, gene_id, transcript_id)
        return(p)
    }
}

#' plot annotation
#' @inheritParams plotAnnotation
#' @noRd
plotAnnotation_withExpression <-  function(se, gene_id, transcript_id) {
    seGene <- transcriptToGeneExpression(se)
    if (!is.null(transcript_id)) {
        if (!all(transcript_id %in% rownames(se))) stop("all(transcript_id
            %in% rownames(se)) condition is not satisfied!")
            txRanges <- rowRanges(se)[transcript_id]
            gene_id <- unique(mcols(txRanges)$GENEID)
            geneRange <- rowRanges(seGene)[gene_id]
            names(txRanges) <- labelFeature(transcript_id, txRanges)
            names(geneRange) <- labelFeature(gene_id, geneRange)
            p <- plotAnnotation_plotFunction(geneRange, txRanges,se,transcript_id)
            return(p)
    } else {
        if (!all(gene_id %in% rowData(se)$GENEID)) stop("all(gene_id %in% 
                rowData(se)$GENEID) condition is not satisfied!")
            p <- lapply(gene_id, function(g) {
                txVec <- rowData(se)[rowData(se)$GENEID == g, ]$TXNAME
                txRanges <- rowRanges(se)[txVec]
                geneRange <- rowRanges(seGene)[gene_id]
                names(geneRange) <- labelFeature(gene_id, geneRange)
                names(txRanges) <-labelFeature(txVec, txRanges)
                p <- plotAnnotation_plotFunction(geneRange, txRanges,se,txVec)
                return(p)
            })
        return(p)
    }
}

#' label feature wtih strand added 
#' @inheritParams plotAnnotation_withExpression
#' @noRd
labelFeature <- function(feature_id,featureRange){
    paste0(feature_id, ":", as.character(unlist(unique(strand(featureRange)))))
}

#' the plotting function 
#' @inheritParams plotAnnotation_withExpression
#' @noRd
plotAnnotation_plotFunction <- function(geneRange, txRanges,se,txVec){
    p_annotation_gene <- ggbio::autoplot(geneRange,
                                         group.selfish = TRUE)
    p_annotation <- ggbio::autoplot(txRanges, group.selfish = TRUE)
    p_expression <-
        ggbio::autoplot(as.matrix(log2(assays(se)$CPM[txVec, ] + 
                                           1)), axis.text.angle = 45, hjust = 1)
    p <- gridExtra::grid.arrange(Gene = p_annotation_gene@ggplot, 
                                 Transcript = p_annotation@ggplot, p_expression,
                                 top = "", heights = c(1,min(length(txVec),4),
                                                       min(length(txVec),5)))
    return(p)
}

#' plot PCA
#' @param se a SummarizedExperiment object
#' @param count.data a dataframe of log2CPM
#' @param group.variable the sample groups
#' @importFrom stats prcomp
#' @import data.table
#' @noRd
plotPCA <- function(se, count.data, group.variable) {
    if (!is.null(group.variable)) {
        sample.info <- as.data.table(as.data.frame(colData(se)[, c(
            "name", group.variable )]))
        setnames(sample.info, seq_len(2), c("runname", "groupVar"))
        pca_result <- prcomp(t(as.matrix(count.data)))
        plotData <- data.table(pca_result$x[, seq_len(2)], keep.rownames = TRUE)
        setnames(plotData, "rn", "runname")
        if (!all(plotData$runname %in% sample.info$runname)) {
            stop("all(plotData$runname %in% sample.info$runname) 
                is not satisfied!")}
        plotData <- sample.info[plotData, on = "runname"]
        p <- ggplot2::ggplot(plotData, ggplot2::aes(x = PC1, y = PC2)) +
            ggplot2::geom_point(ggplot2::aes(col = groupVar)) +
            ggplot2::ylab(paste0("PC2 (",
            round(pca_result$sdev[2]^2 / sum(pca_result$sdev^2) * 100, 1), "%)")) +
            ggplot2::xlab(paste0("PC1 (",
            round(pca_result$sdev[1]^2 / sum(pca_result$sdev^2) * 100, 1), "%)")) +
            ggplot2::theme_minimal()
    } else {
        pca_result <- prcomp(t(as.matrix(count.data))) 
        plotData <- data.table(pca_result$x[, seq_len(2)], keep.rownames = TRUE)
        setnames(plotData, "rn", "runname")
        p <- ggplot2::ggplot(plotData, ggplot2::aes(x = PC1, y = PC2)) +
            ggplot2::geom_point(ggplot2::aes(col = runname)) +
            ggplot2::ylab(paste0("PC2 (",
            round(pca_result$sdev[2]^2 / sum(pca_result$sdev^2) * 100, 1), "%)")) +
            ggplot2::xlab(paste0("PC1 (",
            round(pca_result$sdev[1]^2 / sum(pca_result$sdev^2) * 100, 1), "%)")) +
            ggplot2::theme_minimal()
    }
    return(p)
}
#' plot heatmap
#' @param se a SummarizedExperiment object
#' @param count.data a dataframe of log2CPM
#' @param group.variable the sample groups
#' @importFrom stats cor
#' @import data.table
#' @noRd
plotHeatmap <- function(se, count.data, group.variable) {
    corData <- cor(count.data, method = "spearman")
    col_fun <- circlize::colorRamp2(
        seq(floor(range(corData)[1] * 10) / 10,
            ceiling(range(corData)[2] * 10) / 10, length.out = 2),
        c("White","Blue"))

    if (!is.null(group.variable)) {
        sample.info <- as.data.table(as.data.frame(colData(se)[,
            c("name", group.variable)]))
        setnames(sample.info, seq_len(2), c("runname", "groupVar"))
        if (!all(colnames(count.data) %in% sample.info$runname)) 
            stop("all(colnames(count.data) %in% 
                sample.info$runname) is not satisfied!")
        topAnnotation <- ComplexHeatmap::HeatmapAnnotation(
            group =
                sample.info[match(colnames(count.data), runname)]$groupVar)
        p <- ComplexHeatmap::Heatmap(corData,
            name = "Sp.R", col = col_fun,
            top_annotation = topAnnotation, show_row_names = FALSE,
            column_names_gp = grid::gpar(fontsize = 9))
    } else {
        p <- ComplexHeatmap::Heatmap(corData,
            name = "Sp.R", col = col_fun,
            show_row_names = FALSE, column_names_gp = grid::gpar(fontsize = 9))
    }
    return(p)
}
