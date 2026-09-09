.recovery_reference_profiles <- function(values, samples, episode_ids) {
  compositions <- sweep(values, 2L, colSums(values), "/")
  available <- episode_ids[episode_ids %in% samples$episode_id]
  profiles <- matrix(
    NA_real_,
    nrow = nrow(values),
    ncol = length(available),
    dimnames = list(rownames(values), available)
  )
  episodes <- S4Vectors::DataFrame(
    episode_id = episode_ids,
    support = rep("missing_baseline", length(episode_ids)),
    n_samples = integer(length(episode_ids)),
    n_times = integer(length(episode_ids)),
    first_time = rep(NA_real_, length(episode_ids)),
    last_time = rep(NA_real_, length(episode_ids)),
    baseline_diameter = rep(NA_real_, length(episode_ids))
  )

  for (row in seq_along(episode_ids)) {
    selected <- which(samples$episode_id == episode_ids[[row]])
    if (!length(selected)) {
      next
    }

    baseline <- compositions[, selected, drop = FALSE]
    times <- samples$time[selected]
    n_samples <- length(selected)
    n_times <- length(unique(times))
    support <- if (n_times > 1L) "multiple_times" else "single_time"
    if (n_samples == 1L) {
      support <- "single_sample"
    }

    profiles[, episode_ids[[row]]] <- rowMeans(baseline)
    episodes$support[[row]] <- support
    episodes$n_samples[[row]] <- n_samples
    episodes$n_times[[row]] <- n_times
    episodes$first_time[[row]] <- min(times)
    episodes$last_time[[row]] <- max(times)
    episodes$baseline_diameter[[row]] <- .recovery_baseline_diameter(baseline)
  }

  list(episodes = episodes, profiles = profiles)
}

.recovery_baseline_diameter <- function(compositions) {
  n_samples <- ncol(compositions)
  if (n_samples < 2L) {
    return(NA_real_)
  }

  diameter <- 0
  for (sample in seq_len(n_samples - 1L)) {
    remaining <- compositions[, seq.int(sample + 1L, n_samples), drop = FALSE]
    distances <- colSums(abs(remaining - compositions[, sample])) / 2
    diameter <- max(diameter, distances)
  }

  diameter
}
