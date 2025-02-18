% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/read_multiple_bed.R
\name{read_multiple_bed}
\alias{read_multiple_bed}
\title{read multiple bed with annotated data as per input parameter}
\usage{
read_multiple_bed(sample_group, marker, figure)
}
\arguments{
\item{sample_group}{name of the population used to build the data path}

\item{marker}{marker definition used to label folder and files eg MUTATIONS, LESIONS}

\item{figure}{figures like hypo/hyper to built the data path}
}
\value{
list of pivot by column identified with column Label and by Sample
}
\description{
read multiple bed with annotated data as per input parameter
}
