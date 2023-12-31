% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/vctrs_variables.R
\name{currency}
\alias{currency}
\title{Create a currency vector}
\usage{
currency(x = double(), code = "USD", digits = 2, locale = TRUE, log = NULL)
}
\arguments{
\item{x}{A numeric vector.}

\item{code}{Currency code. See \link{currencies} for a list of possibilities.}

\item{digits}{How many digits to round to when displaying the number.
If \code{NULL}, all digits will be shown. Default is 2.}

\item{locale}{Should the variable be displayed using its locale?}

\item{log}{Should the variable's distribution be shown on the log scale?
If not specified, an inference will be made based on its values.}
}
\description{
Create a currency vector
}
