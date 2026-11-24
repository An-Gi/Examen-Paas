#!/usr/bin/env bash
# Genera el reporte de commits para la Autoevaluación (documentación §6).
# Uso: bash scripts/git/reporte-commits.sh > docs/build/commits.md     (o: make commits)
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

echo "## Reporte de commits"
echo
echo "Generado el $(date +%F) desde la rama \`$(git rev-parse --abbrev-ref HEAD)\`."
echo
echo "### Commits por autor"
echo
echo '```'
git shortlog -sne HEAD
echo '```'
echo
echo "### Historial"
echo
echo '```'
git log --pretty=format:"%h %an %ad %s" --date=short
echo
echo '```'
