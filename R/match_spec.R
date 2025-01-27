#' @rdname match_spec
#' @title Identify and filter spectra
#'
#' @description
#' \code{match_spec()} joins two \code{OpenSpecy} objects and their metadata
#' based on similarity.
#' \code{cor_spec()} correlates two \code{OpenSpecy} objects, typically one with
#' knowns and one with unknowns.
#' \code{ident_spec()} retrieves the top match values from a correlation matrix
#' and formats them with metadata.
#' \code{get_metadata()} retrieves metadata from OpenSpecy objects.
#' \code{max_cor_named()} formats the top correlation values from a correlation
#' matrix as a named vector.
#' \code{filter_spec()} filters an Open Specy object.
#'
#' @param x an \code{OpenSpecy} object, typically with unknowns.
#' @param library an \code{OpenSpecy} or \code{glmnet} object representing the
#' reference library of spectra or model to use in identification.
#' @param na.rm logical; indicating whether missing values should be removed
#' when calculating correlations. Default is \code{TRUE}.
#' @param top_n integer; specifying the number of top matches to return.
#' If \code{NULL} (default), all matches will be returned.
#' @param cor_matrix a correlation matrix for object and library,
#' can be returned by \code{cor_spec()}
#' @param order an \code{OpenSpecy} used for sorting, ideally the unprocessed
#' one; \code{NULL} skips sorting.
#' @param add_library_metadata name of a column in the library metadata to be
#' joined; \code{NULL} if you don't want to join.
#' @param add_object_metadata name of a column in the object metadata to be
#' joined; \code{NULL} if you don't want to join.
#' @param rm_empty logical; whether to remove empty columns in the metadata.
#' @param logic a logical or numeric vector describing which spectra to keep.
#' @param fill an \code{OpenSpecy} object with a single spectrum to be used to
#' fill missing values for alignment with the AI classification.
#' @param \ldots additional arguments passed \code{\link[stats]{cor}()}.
#'
#' @return
#' \code{match_spec()} and \code{ident_spec()} will return
#' a \code{\link[data.table]{data.table-class}()} containing correlations
#' between spectra and the library.
#' The table has three columns: \code{object_id}, \code{library_id}, and
#' \code{match_val}.
#' Each row represents a unique pairwise correlation between a spectrum in the
#' object and a spectrum in the library.
#' If \code{top_n} is specified, only the top \code{top_n} matches for each
#' object spectrum will be returned.
#' If \code{add_library_metadata} is \code{is.character}, the library metadata
#' will be added to the output.
#' If \code{add_object_metadata} is \code{is.character}, the object metadata
#' will be added to the output.
#' \code{filter_spec()} returns an \code{OpenSpecy} object.
#' \code{cor_spec()} returns a correlation matrix.
#' \code{get_metadata()} returns a \code{\link[data.table]{data.table-class}()}
#' with the metadata for columns which have information.
#'
#' @examples
#' data("test_lib")
#'
#' unknown <- read_extdata("ftir_ldpe_soil.asp") |>
#'   read_any() |>
#'   conform_spec(range = test_lib$wavenumber,
#'                res = spec_res(test_lib)) |>
#'   process_spec()
#' cor_spec(unknown, test_lib)
#'
#' match_spec(unknown, test_lib, add_library_metadata = "sample_name",
#'            top_n = 1)
#'
#' @author
#' Win Cowger, Zacharias Steinmetz
#'
#' @seealso
#' \code{\link{adj_intens}()} converts spectra;
#' \code{\link{get_lib}()} retrieves the Open Specy reference library;
#' \code{\link{load_lib}()} loads the Open Specy reference library into an \R
#' object of choice
#'
#' @importFrom stats cor predict
#' @importFrom glmnet predict.glmnet
#' @importFrom data.table data.table setorder fifelse .SD as.data.table rbindlist
#' @export
cor_spec <- function(x, ...) {
  UseMethod("cor_spec")
}

#' @rdname match_spec
#'
#' @export
cor_spec.default <- function(x, ...) {
  stop("object 'x' needs to be of class 'OpenSpecy'")
}

#' @rdname match_spec
#'
#' @export
cor_spec.OpenSpecy <- function(x, library, na.rm = T, ...) {
  if(sum(x$wavenumber %in% library$wavenumber) < 3)
    stop("there are less than 3 matching wavenumbers in the objects you are ",
         "trying to correlate; this won't work for correlation analysis. ",
         "Consider first conforming the spectra to the same wavenumbers.",
         call. = F)

  if(!all(x$wavenumber %in% library$wavenumber))
    warning(paste0("some wavenumbers in 'x' are not in the library and the ",
                   "function is not using these in the identification routine: ",
                   paste(x$wavenumber[!x$wavenumber %in% library$wavenumber],
                         collapse = " ")),
            call. = F)

  lib <- library$spectra[library$wavenumber %in% x$wavenumber, ]
  lib <- lib[, lapply(.SD, make_rel, na.rm = na.rm)]
  lib <- lib[, lapply(.SD, mean_replace)]

  spec <- x$spectra[x$wavenumber %in% library$wavenumber,]
  spec <- spec[,lapply(.SD, make_rel, na.rm = na.rm)]
  spec <- spec[,lapply(.SD, mean_replace)]

  cor(lib, spec, ...)
}

#' @rdname match_spec
#' @export
match_spec <- function(x, ...) {
  UseMethod("match_spec")
}

#' @rdname match_spec
#'
#' @export
match_spec.default <- function(x, ...) {
  stop("object 'x' needs to be of class 'OpenSpecy'")
}

#' @rdname match_spec
#'
#' @export
match_spec.OpenSpecy <- function(x, library, na.rm = T, top_n = NULL,
                                 order = NULL, add_library_metadata = NULL,
                                 add_object_metadata = NULL, fill = NULL, ...) {
  if(is_OpenSpecy(library)) {
    res <- cor_spec(x, library = library) |>
      ident_spec(x, library = library, top_n = top_n,
                 add_library_metadata = add_library_metadata,
                 add_object_metadata = add_object_metadata)
  } else {
    res <- ai_classify(x, library, fill)
  }

  if(!is.null(order)) {
    .reorder <- NULL
    match <- match(colnames(order$spectra), res$object_id)
    setorder(res[, .reorder := order(match)], .reorder)[, .reorder := NULL]
  }

  return(res)
}

#' @rdname match_spec
#'
#' @export
ident_spec <- function(cor_matrix, x, library, top_n = NULL,
                       add_library_metadata = NULL,
                       add_object_metadata = NULL, ...){
  if(is.numeric(top_n) && top_n > ncol(library$spectra)){
    top_n = NULL
    message("'top_n' larger than the number of spectra in the library; ",
            "returning all matches")
  }

  out <-  as.data.table(cor_matrix, keep.rownames = T) |> melt(id.vars = "rn")

  names(out) <- c("library_id", "object_id", "match_val")

  if(is.numeric(top_n)) {
    match_val <- NULL # workaround for data.table non-standard evaluation
    setorder(out, -match_val)
    out <- out[!is.na(match_val), head(.SD, top_n), by = "object_id"]
  }

  if(is.character(add_library_metadata))
    out <- merge(out, library$metadata,
                 by.x = "library_id", by.y = add_library_metadata, all.x = T)

  if(is.character(add_object_metadata))

    out <- merge(out, x$metadata,
                 by.x = "object_id", by.y = add_object_metadata, all.x = T)

  return(out)
}

#' @rdname match_spec
#'
#' @export
get_metadata <- function(x, ...) {
  UseMethod("get_metadata")
}

#' @rdname match_spec
#'
#' @export
get_metadata.default <- function(x, ...) {
  stop("object 'x' needs to be of class 'OpenSpecy'")
}

#' @rdname match_spec
#'
#' @export
get_metadata.OpenSpecy <- function(x, logic, rm_empty = TRUE, ...) {
  if(is.character(logic))
    logic <- which(names(x$spectra) %in% logic)

  res <- x$metadata[logic, ]

  if(rm_empty)
    res <- res[, !sapply(res, is_empty_vector), with = F]

  return(res)
}

#' @rdname match_spec
#'
#' @export
max_cor_named <- function(cor_matrix, na.rm = T) {
  # Find the indices of maximum correlations
  max_cor_indices <- apply(cor_matrix, 2, function(x) which.max(x))

  # Use indices to get max correlation values
  max_cor_values <- vapply(1:length(max_cor_indices), function(idx) {
    cor_matrix[max_cor_indices[idx],idx]}, FUN.VALUE = numeric(1))

  # Use indices to get the corresponding names
  names(max_cor_values) <- rownames(cor_matrix)[max_cor_indices]

  return(max_cor_values)
}

#' @rdname match_spec
#'
#' @export
filter_spec <- function(x, ...) {
  UseMethod("filter_spec")
}

#' @rdname match_spec
#'
#' @export
filter_spec.default <- function(x, ...) {
  stop("object 'x' needs to be of class 'OpenSpecy'")
}

#' @rdname match_spec
#'
#' @export
filter_spec.OpenSpecy <- function(x, logic, ...) {
  if(is.character(logic)){
    logic = which(names(x$spectra) %in% logic)
  }
  x$spectra <- x$spectra[, logic, with = F]
  x$metadata <- x$metadata[logic,]

  return(x)
}

#' @rdname match_spec
#'
#' @export
ai_classify <- function(x, ...) {
  UseMethod("ai_classify")
}

#' @rdname match_spec
#'
#' @export
ai_classify.default <- function(x, ...) {
  stop("object 'x' needs to be of class 'OpenSpecy'")
}

#' @rdname match_spec
#'
#' @export
ai_classify.OpenSpecy <- function(x, library, fill = NULL, ...) {
  if(!is.null(fill)) {
    filled <- .fill_spec(x, fill)
  } else {
    filled <- x
  }
  filled$spectra$wavenumber <- filled$wavenumber
  proc <- transpose(filled$spectra, make.names = "wavenumber") |>
    as.matrix()

  pred <- predict(library$model,
                  newx = proc,
                  min(library$model$lambda),
                  type = "response") |>
    as.data.table()
  names(pred)[1:3] <- c("x", "y", "z")
  pred$x <- as.integer(pred$x)
  pred$y <- as.integer(pred$y)
  pred <- merge(pred, data.table(x = 1:dim(proc)[1]), all.y = T)

  value <- NULL # workaround for data.table non-standard evaluation
  filt <- pred[, .SD[value == max(value, na.rm = T) | is.na(value)], by = "x"]

  res <- merge(filt, library$dimension_conversion, all.x = T,
               by.x = "y", by.y = "factor_num")
  setorder(res, "x")

  return(res)
}

.fill_spec <- function(x, fill) {
  blank_dt <- x$spectra[1,]

  blank_dt[1,] <- NA

  test <- rbindlist(lapply(1:length(fill$wavenumber), function(x) {
    blank_dt
  }
  ))[, lapply(.SD, function(x) {
    unlist(fill$spectra)
  })]

  test[match(x$wavenumber, fill$wavenumber),] <- x$spectra

  x$spectra <- test

  x$wavenumber <- fill$wavenumber

  x
}
