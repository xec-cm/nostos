# Attribution for dethlefsen2008

Copyright 2008 Dethlefsen et al. The `dethlefsen2008` data are adapted from:

Dethlefsen L, Huse S, Sogin ML, Relman DA (2008). The Pervasive Effects of an
Antibiotic on the Human Gut Microbiota, as Revealed by Deep 16S rRNA Sequencing.
PLoS Biology 6(11): e280. https://doi.org/10.1371/journal.pbio.0060280

Source: Dataset S3 (`sd003`), worksheet `V3 refOTUs`, and Table 1.
The original article's copyright notice grants reuse under the Creative Commons
Attribution License, with author and source credit. Its notice does not state a
license version; this package does not retroactively assign the current PLOS
license version to that notice. See the original article and the publisher's
reuse policy: https://journals.plos.org/plosbiology/s/licenses-and-copyright
No separate restrictive notice appears on Dataset S3.

Modifications: all 5,670 refOTUs and 18 sample abundance columns are converted to
a TSE without rounding; taxonomy whitespace is trimmed; sample dates from Table
1, subject/episode IDs and a five-day operational exposure interval are attached.
The source `Total`, dominant-tag sequence, tag ID and distance annotations are
not included. No abundance feature or sample is selected according to outcomes.
The matrix is normalized abundance, not integer raw sequencing counts.

Dataset reuse requires this source attribution. The package's MIT software
license does not replace the source data's attribution terms. Synthetic
`recovery_examples` and package code remain under the package license.
