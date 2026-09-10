#' Longitudinal antibiotic exposure data from Dethlefsen et al. (2008)
#'
#' Published V3 refOTU normalized abundances for three participants, packaged
#' with the original sample calendar for an offline descriptive example.
#'
#' @format A [TreeSummarizedExperiment::TreeSummarizedExperiment] with 5,670 rows
#'   and 18 columns, without a phylogenetic tree or a registered analysis:
#' \describe{
#'   \item{assay \code{abundance}}{Double matrix of published normalized
#'     abundances. Each column totals 43,405; these are not raw read counts.}
#'   \item{rowData}{Original refOTU identities and Phylum, Class, Order, Family
#'     and Genus annotations; surrounding taxonomy whitespace is removed.}
#'   \item{colData}{Sample, subject and episode IDs, numeric \code{day} relative
#'     to first administration, and logical \code{is_baseline}.}
#'   \item{metadata}{The \code{study} list contains citation, license, source
#'     checksum, preprocessing, time definition and episode/event tables.}
#' }
#' @details
#' All features and samples in the source worksheet are retained. Participant A
#' has samples on days -60, -6, -2, -1, 3, 5, 33 and 180; participants B and C
#' have samples on days -60, -1, 5, 33 and 180. A five-day ciprofloxacin exposure
#' is represented as `[0, 5]`, an operational duration rather than a measured final
#' dose time. No missing visits are imputed. The calendar is transcribed from
#' Table 1; abundance values come from Dataset S3, sheet `V3 refOTUs`.
#'
#' The source authors retain copyright under Creative Commons Attribution.
#' See the installed `DATA-LICENSE.md` for attribution and modifications, and
#' `data-raw/dethlefsen2008.R` in the source repository for checksum-verified
#' regeneration. The normalized table cannot establish raw sequencing depths.
#' Sparse observations and three participants do not provide recovery ground
#' truth or calibration of a universal recovery rule.
#'
#' @source Dethlefsen L, Huse S, Sogin ML, Relman DA (2008). The Pervasive
#'   Effects of an Antibiotic on the Human Gut Microbiota, as Revealed by Deep
#'   16S rRNA Sequencing. PLoS Biology 6(11): e280.
#'   \doi{10.1371/journal.pbio.0060280}. Dataset S3 and Table 1.
#' @seealso [recovery_examples], [setup_recovery()], [add_reference()]
#' @examples
#' data("dethlefsen2008", package = "recoverome")
#' dim(dethlefsen2008)
#' SummarizedExperiment::colData(dethlefsen2008)[, c("sample_id", "day")]
"dethlefsen2008"
