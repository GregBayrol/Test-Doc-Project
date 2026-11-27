#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

SOURCE="${SOURCE:-docs/specification.md}"
DOC_VERSION_RAW="${DOC_VERSION:-local}"
DOC_VERSION="$(printf '%s' "$DOC_VERSION_RAW" | sed 's#[^A-Za-z0-9._-]#-#g')"
DOCUMENT_NAME="${DOCUMENT_NAME:-specification}"
MMDC="${MMDC:-mmdc}"
PANDOC="${PANDOC:-pandoc}"
PDF_ENGINE="${PDF_ENGINE:-xelatex}"
PUPPETEER_CONFIG="${PUPPETEER_CONFIG:-$REPO_ROOT/templates/puppeteer-config.json}"
MERMAID_CONFIG="${MERMAID_CONFIG:-$REPO_ROOT/templates/mermaid-config.json}"

if [[ "$SOURCE" = /* ]]; then
  SOURCE_FILE="$SOURCE"
else
  SOURCE_FILE="$REPO_ROOT/$SOURCE"
fi
SOURCE_ASSETS_DIR="$(dirname "$SOURCE_FILE")/assets"

BUILD_DIR="$REPO_ROOT/build"
HTML_BUILD_DIR="$BUILD_DIR/html"
PDF_BUILD_DIR="$BUILD_DIR/pdf"
DIST_DIR="$REPO_ROOT/dist"
RELEASE_DIR="$REPO_ROOT/release"
HTML_MARKDOWN="$HTML_BUILD_DIR/$DOCUMENT_NAME.md"
PDF_MARKDOWN="$PDF_BUILD_DIR/$DOCUMENT_NAME.md"
PORTABLE_HTML="$RELEASE_DIR/$DOCUMENT_NAME-$DOC_VERSION.html"
PDF_FILE="$RELEASE_DIR/$DOCUMENT_NAME-$DOC_VERSION.pdf"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'ERROR: required command not found: %s\n' "$1" >&2
    exit 1
  fi
}

require_file() {
  if [[ ! -f "$1" ]]; then
    printf 'ERROR: required file not found: %s\n' "$1" >&2
    exit 1
  fi
}

require_command "$MMDC"
require_command "$PANDOC"
require_command "$PDF_ENGINE"
require_file "$SOURCE_FILE"
require_file templates/style.css
require_file "$PUPPETEER_CONFIG"
require_file "$MERMAID_CONFIG"

validate_html_references() {
  local html_file="$1"
  local root_dir="$2"
  local require_embedded="$3"
  local entry attribute ref clean_ref

  while IFS= read -r entry; do
    attribute="${entry%%=*}"
    ref="${entry#*=\"}"
    ref="${ref%\"}"
    [[ -z "$ref" ]] && continue

    case "$ref" in
      \#*|mailto:*|tel:*|data:*|javascript:* )
        continue
        ;;
      http://*|https://*|//* )
        if [[ "$require_embedded" == "yes" && "$attribute" == "src" ]]; then
          printf 'ERROR: standalone HTML still references an external resource: %s\n' "$ref" >&2
          return 1
        fi
        continue
        ;;
    esac

    clean_ref="${ref%%#*}"
    clean_ref="${clean_ref%%\?*}"
    [[ -z "$clean_ref" ]] && continue

    if [[ "$require_embedded" == "yes" ]]; then
      printf 'ERROR: standalone HTML still references a local file: %s\n' "$ref" >&2
      return 1
    fi

    if [[ "$clean_ref" = /* || ! -s "$root_dir/$clean_ref" ]]; then
      printf 'ERROR: HTML reference is missing from the Pages output: %s\n' "$ref" >&2
      return 1
    fi
  done < <(
    grep -Eo '(src|href)="[^"]+"' "$html_file" \
      || true
  )
}

rm -rf "$BUILD_DIR" "$DIST_DIR" "$RELEASE_DIR"
mkdir -p \
  "$HTML_BUILD_DIR/assets/generated" \
  "$PDF_BUILD_DIR/assets/generated" \
  "$DIST_DIR" \
  "$RELEASE_DIR"

if [[ -d "$SOURCE_ASSETS_DIR" ]]; then
  cp -R "$SOURCE_ASSETS_DIR"/. "$HTML_BUILD_DIR/assets/"
  cp -R "$SOURCE_ASSETS_DIR"/. "$PDF_BUILD_DIR/assets/"
fi

MERMAID_BLOCKS="$(
  grep -Ec '^[[:space:]]*(```|~~~)[[:space:]]*mermaid([[:space:]]|$)' "$SOURCE_FILE" \
    || true
)"

printf 'Rendering Mermaid diagrams for HTML (SVG)...\n'
(
  cd "$HTML_BUILD_DIR"
  "$MMDC" \
    --quiet \
    --puppeteerConfigFile "$PUPPETEER_CONFIG" \
    --configFile "$MERMAID_CONFIG" \
    --input "$SOURCE_FILE" \
    --output "$DOCUMENT_NAME.md" \
    --outputFormat svg \
    --artefacts assets/generated
)

printf 'Rendering Mermaid diagrams for PDF (high-resolution PNG)...\n'
(
  cd "$PDF_BUILD_DIR"
  "$MMDC" \
    --quiet \
    --puppeteerConfigFile "$PUPPETEER_CONFIG" \
    --configFile "$MERMAID_CONFIG" \
    --input "$SOURCE_FILE" \
    --output "$DOCUMENT_NAME.md" \
    --outputFormat png \
    --scale 2 \
    --artefacts assets/generated
)

if grep -Eq '^[[:space:]]*(```|~~~)[[:space:]]*mermaid([[:space:]]|$)' "$HTML_MARKDOWN" "$PDF_MARKDOWN"; then
  printf 'ERROR: at least one Mermaid block was not rendered.\n' >&2
  exit 1
fi

HTML_DIAGRAMS="$(find "$HTML_BUILD_DIR/assets/generated" -type f -name '*.svg' | wc -l | tr -d ' ')"
PDF_DIAGRAMS="$(find "$PDF_BUILD_DIR/assets/generated" -type f -name '*.png' | wc -l | tr -d ' ')"
if [[ "$HTML_DIAGRAMS" != "$MERMAID_BLOCKS" || "$PDF_DIAGRAMS" != "$MERMAID_BLOCKS" ]]; then
  printf 'ERROR: expected %s Mermaid diagram(s), found %s SVG and %s PNG.\n' \
    "$MERMAID_BLOCKS" "$HTML_DIAGRAMS" "$PDF_DIAGRAMS" >&2
  exit 1
fi

printf 'Building GitHub Pages site...\n'
cp -R "$HTML_BUILD_DIR/assets" "$DIST_DIR/assets"
cp templates/style.css "$DIST_DIR/style.css"
"$PANDOC" "$HTML_MARKDOWN" \
  --from=markdown \
  --standalone \
  --mathjax \
  --css=style.css \
  --resource-path="$HTML_BUILD_DIR" \
  --output="$DIST_DIR/index.html"

printf 'Building standalone HTML release...\n'
"$PANDOC" "$HTML_MARKDOWN" \
  --from=markdown \
  --standalone \
  --embed-resources \
  --mathml \
  --css=templates/style.css \
  --resource-path="$HTML_BUILD_DIR:$REPO_ROOT" \
  --output="$PORTABLE_HTML"

printf 'Building PDF release with %s...\n' "$PDF_ENGINE"
"$PANDOC" "$PDF_MARKDOWN" \
  --from=markdown \
  --pdf-engine="$PDF_ENGINE" \
  --resource-path="$PDF_BUILD_DIR" \
  --variable=geometry:margin=22mm \
  --variable=colorlinks=true \
  --variable=mainfont:"DejaVu Sans" \
  --output="$PDF_FILE"

for output in "$DIST_DIR/index.html" "$PORTABLE_HTML" "$PDF_FILE"; do
  if [[ ! -s "$output" ]]; then
    printf 'ERROR: output is missing or empty: %s\n' "$output" >&2
    exit 1
  fi
done

if [[ -d "$SOURCE_ASSETS_DIR" ]]; then
  while IFS= read -r -d '' asset; do
    relative_asset="${asset#"$SOURCE_ASSETS_DIR"/}"
    if [[ ! -s "$DIST_DIR/assets/$relative_asset" ]]; then
      printf 'ERROR: repository asset is missing from Pages: %s\n' "$relative_asset" >&2
      exit 1
    fi
  done < <(find "$SOURCE_ASSETS_DIR" -type f -print0)
fi

validate_html_references "$DIST_DIR/index.html" "$DIST_DIR" no
validate_html_references "$PORTABLE_HTML" "$RELEASE_DIR" yes

printf 'Build complete: %s Mermaid diagram(s).\n' "$HTML_DIAGRAMS"
printf '  Pages:  %s\n' "$DIST_DIR"
printf '  HTML:   %s\n' "$PORTABLE_HTML"
printf '  PDF:    %s\n' "$PDF_FILE"
