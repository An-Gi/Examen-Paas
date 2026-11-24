#!/usr/bin/env python3
"""Suma y valida las horas de las bitácoras (docs/bitacoras/*.md).

Formato de cada fila:   | AAAA-MM-DD | actividad (una línea) | horas | fase |

Uso:
  python3 scripts/bitacora/sumar-horas.py docs/bitacoras             # resumen por estudiante y fase
  python3 scripts/bitacora/sumar-horas.py docs/bitacoras --markdown  # tablas listas para la §5

Termina con código 1 si alguna fila tiene horas inválidas o una actividad de más de una línea.
"""
import argparse
import re
import sys
from collections import defaultdict
from datetime import date
from pathlib import Path

FECHA = re.compile(r"^\d{4}-\d{2}-\d{2}$")
MAX_ACTIVIDAD = 120  # "no más de una línea"


def leer_bitacora(ruta: Path):
    """Devuelve (titulo, filas, errores); cada fila es (fecha, actividad, horas, fase)."""
    titulo, filas, errores = ruta.stem, [], []
    for n, linea in enumerate(ruta.read_text(encoding="utf-8").splitlines(), 1):
        if linea.startswith("# "):
            titulo = linea[2:].strip()
            continue
        if not linea.lstrip().startswith("|"):
            continue
        celdas = [c.strip() for c in linea.strip().strip("|").split("|")]
        if len(celdas) < 4 or not FECHA.match(celdas[0]):
            continue  # encabezado, separador o fila de ejemplo
        fecha, actividad, horas_txt, fase = celdas[:4]
        try:
            date.fromisoformat(fecha)
        except ValueError:
            errores.append(f"{ruta}:{n}: fecha inválida {fecha!r}")
            continue
        try:
            horas = float(horas_txt.replace(",", "."))
            if not 0 < horas <= 16:
                raise ValueError
        except ValueError:
            errores.append(f"{ruta}:{n}: horas inválidas {horas_txt!r}")
            continue
        if len(actividad) > MAX_ACTIVIDAD:
            errores.append(f"{ruta}:{n}: actividad de más de {MAX_ACTIVIDAD} caracteres")
        filas.append((fecha, actividad, horas, fase or "?"))
    return titulo, sorted(filas), errores


def fmt(h: float) -> str:
    return f"{h:g}"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("carpeta", type=Path)
    parser.add_argument("--markdown", action="store_true", help="tablas para docs/documentacion.md §5")
    args = parser.parse_args()

    archivos = sorted(args.carpeta.glob("*.md"))
    if not archivos:
        print(f"No hay bitácoras en {args.carpeta}", file=sys.stderr)
        return 1

    todos_errores, total_general = [], 0.0
    for archivo in archivos:
        titulo, filas, errores = leer_bitacora(archivo)
        todos_errores += errores
        total = sum(f[2] for f in filas)
        total_general += total

        if args.markdown:
            print(f"## {titulo.replace('Bitácora — ', '')}\n")
            print("| Fecha | Actividad | Horas |\n|---|---|---:|")
            for fecha, actividad, horas, _ in filas:
                print(f"| {fecha} | {actividad} | {fmt(horas)} |")
            print(f"| **Total** | | **{fmt(total)}** |\n")
        else:
            por_fase = defaultdict(float)
            for *_, horas, fase in filas:
                por_fase[fase] += horas
            detalle = "  ".join(f"{k}={fmt(v)}" for k, v in sorted(por_fase.items())) or "sin registros"
            print(f"{titulo}\n  filas={len(filas)}  total={fmt(total)} h\n  {detalle}")

    if not args.markdown:
        print(f"\nTotal del grupo: {fmt(total_general)} h")
    for e in todos_errores:
        print(f"ERROR {e}", file=sys.stderr)
    return 1 if todos_errores else 0


if __name__ == "__main__":
    sys.exit(main())
