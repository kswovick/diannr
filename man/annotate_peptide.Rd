% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/annotate_peptide.R
\name{annotate_peptide}
\alias{annotate_peptide}
\title{Combine Metadata with Peptide-level Data}
\usage{
annotate_peptide(data = data, sample_annotation = sample_annotation)
}
\arguments{
\item{data}{The data frame output from the 'prepare_data' function}

\item{sample_annotation}{The matrix output from the 'create_metadata' function}
}
\value{
A data frame containing peptide-level MaxLFQ intensities and peptide count for each protein group
}
\description{
Annotates peptide-level data with metadata and counts the number
of times a peptide was quantified
}
