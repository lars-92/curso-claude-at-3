#!/usr/bin/env bash
# Valida docs/api/openapi.yml con Redocly y genera docs/api/index.html.
# Uso: bash .claude/skills/update-openapi-docs/scripts/generar_docs.sh [spec] [salida_html]
set -euo pipefail

raiz="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$raiz"

spec="${1:-docs/api/openapi.yml}"
salida="${2:-docs/api/index.html}"

if [[ ! -f "$spec" ]]; then
  echo "Error: no existe $spec" >&2
  exit 1
fi

echo "==> Validando $spec"
if ! npx --no-install redocly lint "$spec"; then
  echo "Error: $spec no es válido; no se genera el HTML." >&2
  exit 1
fi

echo "==> Generando $salida"
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
npx --no-install redocly build-docs "$spec" --output "$tmp"
mv "$tmp" "$salida"

echo "OK: documentación generada en $salida"
