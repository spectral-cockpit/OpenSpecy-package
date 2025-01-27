#' @rdname sig_noise
#' @title Calculate signal and noise metrics for OpenSpecy objects
#'
#' @description
#' This function calculates common signal and noise metrics for \code{OpenSpecy}
#' objects.
#'
#' @param x an \code{OpenSpecy} object.
#' @param metric character; specifying the desired metric to calculate.
#' Options include \code{"sig"} (mean intensity), \code{"noise"} (standard
#' deviation of intensity), \code{"sig_times_noise"} (absolute value of
#' signal times noise), \code{"sig_over_noise"} (absolute value of signal /
#' noise), \code{"run_sig_over_noise"} (absolute value of signal /
#' noise where signal is estimated as the max intensity and noise is 
#' estimated as the height of a low intensity region.), 
#' \code{"log_tot_sig"} (sum of the inverse log intensities, useful for spectra  in log units), 
#' or \code{"tot_sig"} (sum of intensities).
#' @param na.rm logical; indicating whether missing values should be removed
#' when calculating signal and noise. Default is \code{TRUE}.
#' @param \ldots further arguments passed to subfunctions; currently not used.
#'
#' @return
#' A numeric vector containing the calculated metric for each spectrum in the
#' \code{OpenSpecy} object.
#'
#' @examples
#' data("raman_hdpe")
#'
#' sig_noise(raman_hdpe, metric = "sig")
#' sig_noise(raman_hdpe, metric = "noise")
#' sig_noise(raman_hdpe, metric = "sig_times_noise")
#'
#' @importFrom stats median
#' @importFrom data.table frollapply
#'
#' @export
sig_noise <- function(x, ...) {
  UseMethod("sig_noise")
}

#' @rdname sig_noise
#'
#' @export
sig_noise.default <- function(x, ...) {
  stop("object 'x' needs to be of class 'OpenSpecy'", call. = F)
}

#' @rdname sig_noise
#'
#' @export
sig_noise.OpenSpecy <- function(x, metric = "run_sig_over_noise",
                                na.rm = TRUE, ...) {
  vapply(x$spectra, function(y) {
    if(length(y[!is.na(y)]) < 20) {
      warning("Need at least 20 intensity values to calculate the signal or ",
              "noise values accurately; returning NA", call. = F)
      return(NA)
    }

    if(metric == "run_sig_over_noise") {
      max <- frollapply(y[!is.na(y)], 20, max)
      max[(length(max) - 19):length(max)] <- NA
      signal <- max(max, na.rm = T)#/mean(x, na.rm = T)
      noise <- median(max[max != 0], na.rm = T)
    }
    else {
      signal = mean(y, na.rm = na.rm)
      noise = sd(y, na.rm = na.rm)
    }

    if(metric == "sig") return(signal)
    if(metric == "noise") return(noise)
    if(metric == "sig_times_noise") return(abs(signal * noise))

    if(metric %in% c("sig_over_noise", "run_sig_over_noise"))
      return(abs(signal/noise))
    if(metric == "tot_sig") return(sum(y))
    if(metric == "log_tot_sig") return(sum(exp(y)))
  }, FUN.VALUE = numeric(1))
}
