# GitHub documentation pipeline starter

Test package containing:

- `docs/specification.md` — Markdown source
- `docs/assets/test-asset.svg` — example relative asset
- `templates/style.css` — HTML styling
- `templates/pdf-template.tex` — Pandoc/XeLaTeX PDF template
- `.github/workflows/publish-docs.yml` — tag-triggered GitHub Actions workflow

## First test

1. Copy these files to the root of a GitHub repository.
2. In **Settings → Pages → Build and deployment → Source**, select **GitHub Actions**.
3. Commit and push the files.
4. For an initial manual check, run **Publish documentation** from the Actions tab (`workflow_dispatch`).
5. For a real release, create and push a tag such as `v0.1.0`.

Example:

```bash
git add .
git commit -m "Add documentation publishing pipeline"
git push

git tag v0.1.0
git push origin v0.1.0
```

A tag run builds HTML/PDF, uploads a GitHub Actions artifact, publishes the HTML through GitHub Pages, and attaches HTML/PDF to the GitHub Release.
