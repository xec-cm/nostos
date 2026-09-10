# Assisted-by: OpenAI Codex; see inst/PROVENANCE.md.
# From the repository root:
# Rscript --vanilla data-raw/dethlefsen2008.R path/to/original-sd003.xls
# Requires readxl (curation only). With no path, explicitly downloads the source.
arguments <- commandArgs(trailingOnly = TRUE)
source_url <- paste0(
  "https://journals.plos.org/plosbiology/article/file?",
  "id=10.1371/journal.pbio.0060280.sd003&type=supplementary"
)
source_sha256 <- "4fbe0c8ffb0c121851ca791bdce5ee7da8977920315908e70e6014d3990273cc"
source_file <- if (length(arguments)) arguments[[1L]] else tempfile(fileext = ".xls")
if (!length(arguments)) {
  utils::download.file(source_url, source_file, mode = "wb")
}
stopifnot(identical(digest::digest(file = source_file, algo = "sha256"), source_sha256))

original <- readxl::read_excel(source_file, sheet = "V3 refOTUs")
samples <- utils::read.csv("data-raw/dethlefsen2008-samples.csv")
stopifnot(identical(names(original)[2:19], samples$sample_id))
abundance <- as.matrix(original[, samples$sample_id])
rownames(abundance) <- original[["refOTU designation"]]
stopifnot(
  identical(dim(abundance), c(5670L, 18L)),
  !anyDuplicated(rownames(abundance)),
  all(is.finite(abundance)), all(abundance >= 0),
  max(abs(colSums(abundance) - 43405)) < 1e-8
)

ranks <- c("Phylum", "Class", "Order", "Family", "Genus")
taxonomy <- as.data.frame(lapply(original[, ranks], trimws))
rownames(taxonomy) <- rownames(abundance)
rownames(samples) <- samples$sample_id
samples$is_baseline <- samples$day < 0
subjects <- c("A", "B", "C")
episodes <- data.frame(
  episode_id = paste0(subjects, "_ciprofloxacin"),
  subject_id = subjects,
  origin_event_id = paste0(subjects, "_course"),
  origin_boundary = "start"
)
events <- data.frame(
  event_id = episodes$origin_event_id,
  episode_id = episodes$episode_id,
  start_time = 0,
  end_time = 5
)

dethlefsen2008 <- TreeSummarizedExperiment::TreeSummarizedExperiment(
  assays = list(abundance = abundance),
  rowData = S4Vectors::DataFrame(taxonomy),
  colData = S4Vectors::DataFrame(samples)
)
S4Vectors::metadata(dethlefsen2008)$study <- list(
  citation = paste(
    "Dethlefsen L, Huse S, Sogin ML, Relman DA (2008).",
    "The Pervasive Effects of an Antibiotic on the Human Gut Microbiota,",
    "as Revealed by Deep 16S rRNA Sequencing. PLoS Biology 6(11): e280."
  ),
  doi = "10.1371/journal.pbio.0060280",
  source = source_url,
  source_sha256 = source_sha256,
  sheet = "V3 refOTUs",
  license = "Creative Commons Attribution; see DATA-LICENSE.md",
  preprocessing = paste(
    "Published V3 refOTU normalized abundances, each sample totals 43405;",
    "all 5670 refOTUs and 18 samples retained, no rounding or filtering;",
    "taxonomic whitespace trimmed. These are not raw read counts."
  ),
  calendar_source = "Original article Table 1, page 2385; sample days transcribed",
  exposure = paste(
    "Ciprofloxacin 500 mg twice daily for five days; [0, 5] is a duration-based",
    "operational interval, not a known last-dose timestamp."
  ),
  time_unit = "days",
  time_origin = "days relative to first ciprofloxacin administration",
  episodes = episodes,
  events = events
)
save(dethlefsen2008, file = "data/dethlefsen2008.rda", version = 3, compress = "xz")
