# Simple GitHub Markdown documentation pipeline

This repository builds one Markdown source into three outputs:

- a self-contained HTML file for downloads and GitHub Releases;
- a PDF file for downloads and GitHub Releases;
- a static HTML/CSS/assets tree for GitHub Pages.

## Source layout

```text
docs/
├── specification.md
└── assets/
    └── test-asset.svg
scripts/
└── build-docs.sh
templates/
├── mermaid-config.json
├── puppeteer-config.json
└── style.css
.github/workflows/
└── publish-docs.yml
```

The PDF build deliberately uses Pandoc's matching default LaTeX template. This avoids maintaining a custom template that can become incompatible with the Pandoc version installed on the GitHub runner.

## Build design

`scripts/build-docs.sh` creates two complete intermediate document trees:

- `build/html/` contains repository assets and Mermaid SVG files.
- `build/pdf/` contains repository assets and high-resolution Mermaid PNG files.

The HTML and PDF builds therefore never share an incompatible Mermaid image format:

- SVG stays sharp in browsers and is packaged with GitHub Pages.
- PNG avoids SVG text/`foreignObject` conversion failures in XeLaTeX PDFs.

The shell script also verifies that:

- every Mermaid block was replaced;
- HTML and PDF contain the same number of Mermaid diagrams;
- original repository assets are present in the Pages tree;
- every local HTML `src` and `href` resolves in the Pages tree;
- the downloadable HTML has no external or local resource dependency;
- all expected output files are non-empty.

There is no Python validator. All build validation runs in `scripts/build-docs.sh` on GitHub.

## Laptop requirements

For the normal workflow, your laptop only needs Git and your editor. Edit `docs/specification.md` and `docs/assets/`, then push or tag. GitHub installs and runs the complete document toolchain.

## Optional local build

Only if you want to reproduce the GitHub build locally, install Node.js 24, Mermaid CLI 12.0.0, Pandoc, XeLaTeX, `rsvg-convert`, and DejaVu fonts. Then run:

```bash
npm install --global @mermaid-js/mermaid-cli@12.0.0
DOC_VERSION=local bash scripts/build-docs.sh
```

Generated directories are `build/`, `dist/`, and `release/`. They should not be committed.

## GitHub Actions behavior

For a branch test, run **Publish documentation** manually from the Actions tab. The workflow builds and uploads the downloadable and Pages artifacts, but it does not deploy or create a release.

For a public version:

```bash
git tag v0.1.0
git push origin v0.1.0
```

A `v*` tag builds both formats, uploads the Actions artifacts, creates a GitHub Release, and deploys `dist/` to GitHub Pages.

In **Settings → Pages → Build and deployment → Source**, select **GitHub Actions**. Keep the `github-pages` environment protected so only the intended tag workflow can deploy.

## Outputs

Every manual or tag build produces:

- `release/specification-<version>.html`: one portable file with CSS and images embedded;
- `release/specification-<version>.pdf`: one portable PDF, using high-resolution PNG for Mermaid diagrams;
- `dist/`: the GitHub Pages site with `index.html`, `style.css`, repository assets, and generated Mermaid SVG files.

Only `v*` tag builds publish publicly: they create the GitHub Release and deploy GitHub Pages. A manual branch build validates and uploads artifacts but does not publish.
