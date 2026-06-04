#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: ./compile.sh <tex-file>"
  echo "Example: ./compile.sh slide.tex"
  exit 1
fi

file="$1"

if [[ ! -f "$file" ]]; then
  echo "Error: file not found: $file" >&2
  exit 1
fi

latexmk -xelatex "$file"
latexmk -c "$file"

stem="${file%.*}"
if [[ "$stem" == "$file" ]]; then
  stem="$file"
fi

# Remove extra Beamer/LaTeX artifacts that latexmk -c can leave behind.
rm -f \
  "${stem}.nav" \
  "${stem}.snm" \
  "${stem}.toc" \
  "${stem}.out" \
  "${stem}.vrb" \
  "${stem}.xdv" \
  "${stem}.bcf" \
  "${stem}.run.xml" \
  "${stem}.blg" \
  "${stem}.bbl" \
  "${stem}.lof" \
  "${stem}.lot" \
  "${stem}.loa"
