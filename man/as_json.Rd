% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/pipe_functions.R
\name{as_json}
\alias{as_json}
\title{Convert any trelliscope R6 object to JSON}
\usage{
as_json(trdf, pretty = TRUE)
}
\arguments{
\item{trdf}{A trelliscope data frame created with \code{\link[=as_trelliscope_df]{as_trelliscope_df()}}
or a data frame which will be cast as such.}

\item{pretty}{Adds indentation whitespace to JSON output. Can be TRUE/FALSE
or a number specifying the number of spaces to indent.}
}
\description{
Convert any trelliscope R6 object to JSON
}
