#' Extract baggr study effects
#'
#' Internal function used as a helper for plotting and printing of results.
#'
#' @param bg baggr object
#' @param summary logical; summarise result?
#' @param interval uncertainy interval width (numeric between 0 and 1) if summarising
#'
#' @return a matrix with MCMC samples or summaries
#' @export

study_effects <- function(bg, summary = FALSE, interval = .95) {
  if(class(bg) != "baggr")
    stop("study_effects only works with 'baggr' class objects")

  # m <- as.matrix(bg$fit)

  if(bg$pooling == "full"){
    tau <- treatment_effect(bg)[["tau"]] #for consistency we have a separate function for this
    k <- attr(bg$inputs, "n_groups")
    m <- replicate(k, tau)
    if(length(dim(m)) == 3)
      m <- aperm(m, c(1, 3, 2))

  } else{
    # choose correct columns for the given models:
    if(bg$model %in% c("rubin", "mutau")) {
      #replace by extract:
      # m <- m[, grepl("^tau_k", colnames(m))]
      m <- rstan::extract(bg$fit, pars = "tau_k")[[1]]
      # drop mu if model has mu (baseline/control value)
      if(bg$model == "mutau")
        m <- m[,,2]
    } else if(bg$model == "full") {
      m <- rstan::extract(bg$fit, pars = "mutau_k")[[1]][,,2]
    } else if(bg$model == "quantiles") {
      # In this case we have 3D array, last dim is quantiles
      m <- rstan::extract(bg$fit, pars = "beta_1_k")[[1]]
    }
  }
  # for consistency with quantiles, except we have 1 parameter only
  if(length(dim(m)) == 2)
    m <- array(m, dim = c(dim(m), 1))

  par_names <- attr(bg$inputs, "group_label")

  if(!is.null(par_names))
    dimnames(m)[[2]] <- par_names
  else
    dimnames(m)[[2]] <- paste0("Group ", 1:attr(bg$inputs, "n_groups"))

  # will summarise if requested:
  if(summary) {
    intval <- c((1-interval)/2, .5, 1 - (1-interval)/2)
    m <- apply(m, c(2,3), function(x) c(quantile(x, intval), mean(x), sd(x)))
    if(is.null(dimnames(m)[[2]]))
      dimnames(m)[[2]] <- 1:nrow(m)
    dimnames(m)[[1]] <- c("lci", "median", "uci", "mean", "sd")
    m <- aperm(m, c(2,1,3))
  }

  return(m)
}
