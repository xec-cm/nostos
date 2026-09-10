# Nostos name and artwork transition

Issue #53 adopts `nostos` as the installable package name at version **0.99.0**.
It does not publish a release or submit the package to Bioconductor. The
maintainer-approved original PNG, rather than a vector redraw, is the canonical
logo and the source of all browser icons.

## Package and saved-object compatibility

Use `library(nostos)`, `nostos::setup_recovery()` and
`data("recovery_examples", package = "nostos")`. Public function names and
scientific behavior are unchanged. This is a package rename, not an alias package:
old scripts must change `library(recoverome)` and `recoverome::` calls.

Saved TSEs and result snapshots retain these exact contracts:

- `metadata(tse)$recoverome`, `recoverome_view` and `recoverome_sensitivity`.
- `rec_<analysis>_` sample columns and all schema versions.
- `recoverome_*` error/warning classes and diagnostic components.
- Fingerprint format tags, hashing payloads and historical provenance.

No data are migrated, references refitted or outcomes rewritten at load time.
Existing provenance stores the package version, not a package-name field; old
`0.99.0` values remain unchanged. New records obtain the version from `nostos`.

The 5 KiB fixture `tests/testthat/fixtures/recoverome-0.99.0.rds` was generated
with the pre-rename implementation at `7485c28`. It contains synthetic full and
filtered TSEs, both trees, unrelated content, intermediate analysis stages,
expected reports/tables and a saved sensitivity snapshot. Its SHA-256 is
`e6ce51d5ccebc599438a4d5e5134f41327316743956ffbe13b6d5d69dce921bf`.
The rename tests check old results and input bytes, continuation from old stages,
and rendering of the saved sensitivity snapshot. Independent numerical tests
remain in the normal suite; compatibility evidence does not replace them.

To reproduce the fixture, use `save-legacy-fixture.R` with a separate checkout of
`7485c28` and an output file. This is the one intentional executable script that
loads `recoverome`; do not regenerate historical evidence with `nostos`.

```sh
Rscript --vanilla dev/branding/save-legacy-fixture.R /path/to/7485c28 legacy.rds
```

Accepted RFCs, measurement CSVs/session information, qualification protocol and
dated release/readiness reports keep their original names, revisions and hashes.
They describe the historical `recoverome` implementation. Current runners use
`nostos`; rerunning them is a new assessment, not a rewrite of that evidence.

## Repository and Pages coordination

This PR renames the installed package. The existing repository is still
`xec-cm/recoverome`, the existing site is
`https://xec-cm.github.io/recoverome/`, and the Project remains
`recoverome Development`. README installation, badges, DESCRIPTION URLs and
`_pkgdown.yml` deliberately point to these actual destinations until the
maintainer coordinates the remote transition. The issue and PR stay in that
same repository; do not create a replacement repository or Project.

For the coordinated remote rename, after the maintainer merges this PR:

1. Rename the existing GitHub repository to `nostos`, preserving its issues,
   PRs, rules and history. Update local `origin` URLs; do not rename or reset
   another active checkout automatically.
2. Update current installation/badge/source links, DESCRIPTION URLs and
   `_pkgdown.yml` to `xec-cm/nostos` and `https://xec-cm.github.io/nostos/` in
   the accompanying transition change; regenerate package help and README.
   Preserve immutable historical references and compatibility identifiers.
3. Rebuild/redeploy Pages and verify the new root, articles, reference pages,
   search and PNG icons. Do not assume the former Pages URL redirects with
   the repository. Retain or publish an explicit old-site redirect if needed.
4. Update the existing Project's name and repository-specific auto-add filter,
   plus current developer documentation; keep its project ID and issue cards.
5. Add `nostos` to the maintainer's Bioconductor Watched Tags, retain the
   already-confirmed mailing-list subscription and rerun BiocCheck before
   submission. Account changes remain with the maintainer.

The availability assessment in #53 is dated 2026-09-10. It found no observed
R-package collision, but does not reserve the name or establish acceptance.
Remote naming, Pages publication and a submission are distinct operations.

## Artwork provenance and regeneration

The maintainer supplied the original watercolor hexagon with the NOSTOS wordmark,
stacked stones, orbit and coastal landscape from the ChatGPT artwork conversation
on 2026-09-10. The original was approved instead of the simplified SVG rendition.
`man/figures/logo.png` is an unchanged copy of that **625 x 675** PNG:

`ed9f2e24b65f7601cffa334b9dae94851341bd14d7c92447942fc8ddd56a173b`

No new artist attribution or external logo-license claim is invented. The
package's provenance file records AI assistance and the maintainer's supplied
artwork; the maintainer retains responsibility for redistribution decisions.
Do not regenerate the watercolor through an image model or replace it with a
vector approximation during routine documentation work.

`build-icons.cjs` uses the optional authoring tool `sharp` (0.35.4 for this build)
to resize the original with its aspect ratio intact and pad it onto a white
square. It creates 16, 32 and 96 pixel browser PNGs and a 180 pixel touch PNG in
`pkgdown/assets/`. The full illustration becomes a small recognizable hexagon
at favicon scale; the wordmark is not expected to be readable at 16 pixels.
No SVG or ICO is selected as a favicon.

```sh
# Install sharp in a development environment if it is not already available.
node dev/branding/build-icons.cjs
```

The icons are committed, so package installation, checks and website builds need
no Node dependency or icon-generation service. `pkgdown/templates/in-header.html`
adds PNG-only icon links with pkgdown's page-relative root, including articles and
reference pages. Standard pkgdown logo placement uses `man/figures/logo.png` on
those pages; README.Rmd includes the same canonical file. All authoring material
under `dev/` and `pkgdown/` is excluded from the source package.

Build the site with `Rscript --vanilla dev/build-site.R`. The wrapper temporarily
sets pkgdown's CI flag to suppress its interactive online favicon generator;
it restores the previous environment when it finishes. CI uses the same wrapper.
Direct interactive `pkgdown::build_site()` can generate additional SVG/ICO icons
under `pkgdown/favicon/`; remove that generated directory before using the
PNG-only build wrapper. Do not commit those alternate assets.

## Website theme

The maintainer selected Bootswatch **Minty** after comparing three rendered
NOSTOS homepages on 2026-09-10. `_pkgdown.yml` applies it across the whole site.
The mint navbar uses dark text, and links use the darker green `#355e4e`
(`#244438` on hover) for legibility on white while retaining the chosen palette.
The old Get started and package-reference paths redirect within the current
site; these redirects do not rename or redirect the remote Pages site itself.
