% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/conform_spec.R
\name{conform_spec}
\alias{conform_spec}
\alias{conform_spec.default}
\alias{conform_spec.OpenSpecy}
\title{Conform spectra to a standard wavenumber series}
\usage{
conform_spec(x, ...)

\method{conform_spec}{default}(x, ...)

\method{conform_spec}{OpenSpecy}(x, range = NULL, res = 5, type = "interp", ...)
}
\arguments{
\item{x}{a list object of class \code{OpenSpecy}.}

\item{range}{a vector of new wavenumber values, can be just supplied as a
min and max value.}

\item{res}{spectral resolution adjusted to or \code{NULL} if the raw range
should be used.}

\item{type}{the type of wavenumber adjustment to make. \code{"interp"}
results in linear interpolation while \code{"roll"} conducts a nearest
rolling join of the wavenumbers.}

\item{\ldots}{further arguments passed to \code{\link[stats]{approx}()}}
}
\value{
\code{adj_intens()} returns a data frame containing two columns
named \code{"wavenumber"} and \code{"intensity"}
}
\description{
Spectra can be conformed to a standard suite of wavenumbers to be compared
with a reference library or to be merged to other spectra.
}
\examples{
data("raman_hdpe")
conform_spec(raman_hdpe, c(1000, 2000))

}
\seealso{
\code{\link{restrict_range}()} and  \code{\link{flatten_range}()} for
adjusting wavenumber ranges;
\code{\link{subtr_baseline}()} for spectral background correction
}
\author{
Win Cowger, Zacharias Steinmetz
}
