#!/usr/bin/env bash
# Harnais de test headless — Wizard Story
#
# Usage :
#   bash tools/run_tests.sh           # tous les etages
#   bash tools/run_tests.sh unit      # un seul etage
#
# Faits verifies empiriquement sur Godot 4.4.stable, qui dictent la conception :
#   - load() renvoie non-null sur un script en erreur de parse  -> can_instantiate()
#   - une SCRIPT ERROR runtime laisse le code de sortie a 0     -> on parse stderr
#   - une erreur dans SceneTree._init empeche quit() (hang)     -> timeout obligatoire
#   - les types class_name n'existent qu'apres un --import      -> import prealable

set -uo pipefail   # pas de -e : on veut executer tous les etages puis resumer

GODOT="${GODOT_BIN:-/c/Users/Lenovo/Desktop/New folder (6)/Godot_v4.4-stable_win64.exe/Godot_v4.4-stable_win64_console.exe}"
PROJ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$PROJ/.testout"
STAGE_TIMEOUT="${STAGE_TIMEOUT:-180}"

mkdir -p "$OUT"

if [[ -t 1 ]]; then
  R=$'\033[31m'; G=$'\033[32m'; Y=$'\033[33m'; B=$'\033[1m'; N=$'\033[0m'
else
  R=''; G=''; Y=''; B=''; N=''
fi

if [[ ! -x "$GODOT" ]] && [[ ! -f "$GODOT" ]]; then
  printf '%sGodot introuvable :%s %s\n' "$R" "$N" "$GODOT" >&2
  printf 'Definis GODOT_BIN pour pointer vers le binaire.\n' >&2
  exit 2
fi

ALL_STAGES=(ci_load compile audit unit smoke visual)
if [[ $# -gt 0 ]]; then STAGES=("$@"); else STAGES=("${ALL_STAGES[@]}"); fi

declare -A RESULT TIMES
FAILED=0

# Motifs d'erreur reels. Le second filtre retire le bruit de nettoyage de fin de
# process, qui n'indique aucun defaut du jeu.
ERR_RE='SCRIPT ERROR|Parse Error|ERROR:|Failed to load|Cannot open|CRASH'
NOISE_RE='ObjectDB instances leaked|resources still in use|Unreferenced static string|Thread object is being destroyed|RID allocations of type|Pages in use exist at exit'
# Bruit propre a la passe --import : plomberie de l'editeur, sans rapport avec le jeu.
IMPORT_NOISE_RE='progress dialog|!tasks.has\(p_task\)|Make sure resources have been imported'

strip_ansi() { sed -r 's/\x1B\[[0-9;]*[mK]//g'; }

real_errors() { strip_ansi < "$1" | grep -E "$ERR_RE" | grep -vE "$NOISE_RE" || true; }
import_errors() { real_errors "$1" | grep -vE "$IMPORT_NOISE_RE" || true; }

# Import prealable : sans lui, les types class_name n'existent pas et tous les
# etages echouent sur un poste neuf pour une raison etrangere au code.
prepare() {
  printf '%s==> %-8s%s ' "$B" "import" "$N"
  local start end dur
  start=$(date +%s%3N)
  timeout "$STAGE_TIMEOUT" "$GODOT" --headless --path "$PROJ" --import \
      >"$OUT/import.out" 2>"$OUT/import.err"
  end=$(date +%s%3N); dur=$(( end - start ))
  local errs; errs="$(import_errors "$OUT/import.err")"
  if [[ -n "$errs" ]]; then
    printf '%sFAIL%s (%sms)\n' "$R" "$N" "$dur"
    echo "$errs" | head -20 | sed 's/^/     /'
    FAILED=1
    return 1
  fi
  printf '%sOK%s (%sms)\n' "$G" "$N" "$dur"
  return 0
}

run_stage() {
  local s="$1" start end dur code errs
  printf '%s==> %-8s%s ' "$B" "$s" "$N"
  start=$(date +%s%3N)

  # Les etages tournent comme SCENE PRINCIPALE, jamais via --script : verifie sur
  # 4.4.stable, --script n'enregistre pas les singletons d'autoload, et tout script
  # nommant GameConfig/SpeedGauge/RunState echoue alors a la COMPILATION.
  local scene
  if [[ "$s" == "smoke" || "$s" == "visual" ]]; then
    scene="res://tests/smoke/SmokeHarness.tscn"
  else
    scene="res://tests/stages/${s}.tscn"
  fi
  if [[ "$s" == "visual" ]]; then
    # Fenetre REELLE : le seul etage qui execute le code de sprites et d effets
    # (inerte en headless). Il ecrit des captures dans .testout/shot_*.png.
    rm -f "$OUT"/shot_*.png
    timeout "$STAGE_TIMEOUT" "$GODOT" --path "$PROJ" --resolution 540x960 "$scene" >"$OUT/$s.out" 2>"$OUT/$s.err"
  else
    timeout "$STAGE_TIMEOUT" "$GODOT" --headless --path "$PROJ" "$scene" >"$OUT/$s.out" 2>"$OUT/$s.err"
  fi
  code=$?
  end=$(date +%s%3N); dur=$(( end - start )); TIMES[$s]=$dur

  if [[ $code -eq 124 ]]; then
    RESULT[$s]='TIMEOUT'; FAILED=1
    printf '%sTIMEOUT%s (%sms) — blocage probable dans _init\n' "$R" "$N" "$dur"
    return
  fi

  errs="$(real_errors "$OUT/$s.err")"
  if [[ -n "$errs" ]]; then
    RESULT[$s]='ERREURS'; FAILED=1
    printf '%sFAIL%s (%sms) — erreurs moteur\n' "$R" "$N" "$dur"
    echo "$errs" | head -15 | sed 's/^/     /'
    return
  fi

  if [[ $code -ne 0 ]]; then
    RESULT[$s]='FAIL'; FAILED=1
    printf '%sFAIL%s (%sms) code=%d\n' "$R" "$N" "$dur" "$code"
    tail -20 "$OUT/$s.out" | sed 's/^/     /'
    return
  fi

  if [[ "$s" == "smoke" || "$s" == "visual" ]] && ! grep -q 'SMOKE_OK' "$OUT/$s.out"; then
    RESULT[$s]='INCOMPLET'; FAILED=1
    printf '%sFAIL%s (%sms) — marqueur SMOKE_OK absent\n' "$R" "$N" "$dur"
    tail -20 "$OUT/$s.out" | sed 's/^/     /'
    return
  fi

  RESULT[$s]='PASS'
  printf '%sPASS%s (%sms)\n' "$G" "$N" "$dur"
}

printf '%sHarnais Wizard Story%s — %s\n\n' "$B" "$N" "$PROJ"

prepare || { printf '\n%sIMPORT ROUGE%s\n' "$R" "$N"; exit 1; }

for s in "${STAGES[@]}"; do
  if [[ ! " ${ALL_STAGES[*]} " == *" $s "* ]]; then
    printf '%sEtage inconnu :%s %s (connus : %s)\n' "$R" "$N" "$s" "${ALL_STAGES[*]}" >&2
    exit 2
  fi
  run_stage "$s"
done

printf '\n%s---- RESUME ----%s\n' "$B" "$N"
for s in "${STAGES[@]}"; do
  c="$G"; [[ "${RESULT[$s]:-}" == 'PASS' ]] || c="$R"
  printf '  %-8s %s%-9s%s %6sms\n' "$s" "$c" "${RESULT[$s]:-?}" "$N" "${TIMES[$s]:-0}"
done

if [[ $FAILED -eq 0 ]]; then
  printf '\n%sTOUT EST VERT%s\n' "$G" "$N"
  exit 0
fi
printf '\n%sBUILD ROUGE%s\n' "$R" "$N"
exit 1
