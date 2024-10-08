##
## CHOLESKY_UNIT_TRACE stuff (Mittelbach et al)
## This is the unit_trace.R file in beyondWhittle
##
# library(Rcpp)
# sourceCpp("mittelbach_util.cpp")

#' Get U (Hpd with unit trace) matrix from
#' phi (hyperspherical coordinates) vector.
#' This is unit_trace_U_from_phi() in beyondWhittle(unit_trace.R)
#' @keywords internal
cholesky_UFromPhi <- function(phi) {
  x <- cholesky_xFromPhi(phi)
  L <- cholseky_LFromx(x)
  return(L %*% Adj(L))
}

#' Get mu vector, see (36) in Mittelbach et al.
#' Helping function for \code{unit_trace_runif}
#' This is unit_trace_mu() in beyondWhittle(unit_trace.R)
#' @keywords internal
cholesky_muVec <- function(p, q) { # (36) in Mittelbach
  N <- length(p); stopifnot(length(q)==N); stopifnot(N>1)
  res <- rep(pi/2, N)
  i <- 1
  while (i*i < N) {
    l <- i*i
    res[l] <- atan(sqrt(q[l]/p[l]))
    i <- i+1
  }
  res
}

#' Get sigma2 vector, see (37) in Mittelbach et al.
#' Helping function for \code{unit_trace_runif}
#' This is unit_trace_sigma2() in beyondWhittle(unit_trace.R)
#' @keywords internal
cholesky_sigma2Vec <- function(p, q) { # (37) in Mittelbach
  N <- length(p); stopifnot(length(q)==N); stopifnot(N>1)
  1 / (sqrt(p) + sqrt(q))^2
}

#' Get log(c) vector, see (70) in Mittelbach et al.
#' Helping function for \code{unit_trace_runif}
#' This is unit_trace_log_c() in beyondWhittle(unit_trace.R)
#' @keywords internal
cholesky_log_cVec <- function(p, q) { # log of (70) in Mittelbach
  N <- length(p); stopifnot(length(q)==N); stopifnot(N>1)
  res <- rep(NA, N)
  i <- 1
  for (l in 1:N) {
    if (l == i*i) {
      res[l] <- log(2) + lgamma( (p[l]+1)/2 + (q[l]+1)/2 ) -
        lgamma( (p[l]+1)/2 ) - lgamma( (q[l]+1)/2 )
      i <- i+1
    } else {
      res[l] <- -log(pi)/2 + lgamma( (q[l]+1)/2 + 1/2 ) -
        lgamma( (q[l]+1)/2 )
    }
  }
  res
}

#' Is l quadratic? in beyondWhittle(unit_trace.R)
#' @keywords internal
is_quadratic <- function(l, thresh=1e-15) { # a bit hacky
  sl <- sqrt(l)
  sl-as.integer(sl) < 1e-15
}

#' Range intervals I_l, see (63) in Mittelbach et al.
#' This is unit_trace_I_l() in beyondWhittle(unit_trace.R)
#' @keywords internal
cholesky_I_l <- function(l) { # see (63) in Mittelbach
  stopifnot(length(l)==1) # only call me with scalars
  if (is_quadratic(l)) {
    I_l <- c(0,pi/2)
  } else {
    I_l <- c(0,pi)
  }
  I_l
}

#' Get log(f_l), see (66) in Mittelbach et al.
#' Helping function for \code{unit_trace_runif}
#' This is unit_trace_log_f_l() in beyondWhittle(unit_trace.R)
#' @keywords internal
cholesky_log_f_l <- function(phi, p, q, log_c, l) { # log of (66) in Mittelbach
  N <- length(p); stopifnot(length(q) == N && length(log_c) == N && N > 1)
  stopifnot(l >= 1 && l <= N)
  I_l <- cholesky_I_l(l)
  if (phi <= I_l[1] || phi >= I_l[2]) {
    lf_l <- -Inf
  }
  else {
    lf_l <- log_c[l]
    if (p[l] != 0) {
      lf_l <- lf_l + p[l] * log(cos(phi))
    }
    if (q[l] != 0) {
      lf_l <- lf_l + q[l] * log(sin(phi))
    }
  }
  lf_l
}

#' Get log(d) vector, see (39) in Mittelbach et al, adjusted to complex case
#' Helping function for \code{unit_trace_runif}
#' This unit_trace_log_d() in beyondWhittle(unit_trace.R)
#' @keywords internal
cholesky_log_dVec <- function(p, q) { # log of (39) in Mittelbach (adjusted to complex case)
  # TODO is that valid?
  N <- length(p); stopifnot(length(q)==N && N > 1)
  res <- rep(0,N)
  i <- 1
  while (i*i < N) {
    l <- i*i
    res[l] <- p[l]/2 * log(1+q[l]/p[l]) + q[l]/2 * log(1+p[l]/q[l])
    i <- i + 1
  }
  res
}

#' Get log(nu) vector, see (38) in Mittelbach et al.
#' Helping function for \code{unit_trace_runif}
#' This is unit_trace_nu() in beyondWhittle(unit_trace.R)
#' @keywords internal
cholesy_log_nuVec <- function(sigma2_vec, log_c_vec, log_d_vec) { # log of (38) in Mittelbach
  log(2*pi*sigma2_vec) / 2 + log_c_vec - log_d_vec
}


#' Obtain one uniform draw from d times d Hpd matrices with unit trace
#' See Algorithm 2 in Mittelbach et al. (adjusted to complex case)
#' This is unit_trace_runif_single() in beyondWhittle(unit_trace.R)
#' @keywords internal
cholseky_runif_single <- function(d) {
  N <- d*d-1
  phi_res <- rep(NA, N)
  p <- cholesky_pVec(d)
  q <- cholesky_qVec(d)
  log_c <- cholesky_log_cVec(p,q)
  log_d <- cholesky_log_dVec(p,q)
  mu <- cholesky_muVec(p,q)
  sigma2 <- cholesky_sigma2Vec(p,q)
  log_nu <- cholesy_log_nuVec(sigma2, log_c, log_d)
  for (l in 1:N) {
    #print(l)
    accepted <- F
    while (!accepted) {
      sigma_l <- sqrt(sigma2[l])
      phi_star <- rnorm(1, mu[l], sigma_l)
      alpha <- cholesky_log_f_l(phi_star,
                                p,
                                q,
                                log_c,
                                l) -
        dnorm(phi_star, mu[l], sigma_l, log=T) -
        log_nu[l]
      accepted <- (log(runif(1,0,1)) < alpha)
    }
    phi_res[l] <- phi_star
  }
  U <- cholesky_UFromPhi(phi_res)
  list(phi=phi_res, U=U)
}

#' Draw uniformly from Hpd matrices with unit trace
#' This is unit_trace_runif() in beyondWhittle(unit_trace.R)
#' @keywords internal
cholesky_runif <- function(n, d, verbose=F) {
  N <- d*d-1
  phi_res <- matrix(NA, nrow=N, ncol=n)
  U_res <- array(NA, dim=c(d,d,n))
  for (j in 1:n) {
    if (verbose) print(j)
    tmp <- cholseky_runif_single(d)
    phi_res[,j] <- tmp$phi
    U_res[,,j] <- tmp$U
  }
  list(phi=phi_res, U=U_res)
}
# tmp <- cholesky_runif(100, 8, T)
# apply(tmp$U, 3, matCond)
