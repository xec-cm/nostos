# Implementation and documentation provenance

Assisted-by: OpenAI Codex.

Substantial parts of nostos's R implementation, tests, synthetic examples,
documentation and development tooling were produced with coding-agent assistance.
The maintainer defines scope and methodological decisions, reviews contributions,
and controls merges and publication. Agent assistance does not transfer the
maintainer's responsibility for reliability, attribution or ongoing support.

The public issue and pull-request history records the accepted design contracts,
implementation changes, independent technical reviews and maintainer merges:
https://github.com/xec-cm/nostos/pulls

The package uses public APIs from its declared R/Bioconductor dependencies.
The reference and deviation definitions, observation rule and historical-scope
contracts are documented in the vignette and accepted RFCs. Citations to methods
and related packages are references, not claims that those projects validated
nostos or authored its implementation.

The `recovery_examples` dataset is deterministic and synthetic. Its generation
source is maintained at:
https://github.com/xec-cm/nostos/blob/devel/data-raw/recovery_examples.R

The real `dethlefsen2008` dataset is separate; its help and installed
`DATA-LICENSE.md` retain source attribution and reuse terms.
The maintainer supplied and approved the NOSTOS watercolor logo on 2026-09-10
from the ChatGPT artwork task. The canonical PNG is preserved byte-for-byte;
browser icons are resized PNG derivatives. See `dev/branding/README.md` in the
repository for artwork provenance and reproducible icon generation.

The package declares the MIT license. Before any Bioconductor submission, the
maintainer should confirm the provenance record against the exact submitted
revision, disclose substantive AI assistance in the submission discussion and PR,
and resolve any third-party attribution questions identified during that review.
No publication, package DOI or funding attribution is invented here.
