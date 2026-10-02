#!/usr/bin/env python3
"""Document de changement du testeur -> rapport + diff sur les generateurs de contenu.

Le co-auteur regle le jeu depuis l atelier du testeur (Reglages > mode testeur >
ATELIER) et nous envoie le DOCUMENT DE CHANGEMENT (JSON, format
"time_wizard_changements"). Les .tres sont GENERES : la seule source de verite
est tools/make_content.gd (et tools/make_passives.gd pour les passifs). Ce
script dit, changement par changement, ou et quoi modifier dans ces fichiers,
et propose le diff quand la modification est MECANIQUE ET SURE.

Usage (depuis la racine du depot) :
    python tools/apply_changes.py changements.json            # rapport seul
    python tools/apply_changes.py changements.json --patch x.diff
    python tools/apply_changes.py changements.json --ecrire   # modifie les .gd

Il ne lance jamais Godot et ne touche aucun .tres. Apres --ecrire (ou git apply) :
    Godot --headless --path . tools/make_content.tscn
    bash tools/run_tests.sh

Statuts du rapport :
    DIFF        la modification est proposee dans le diff
    DEJA FAIT   le code porte deja la valeur "apres"
    A VERIFIER  le code ne porte pas la valeur "avant" du document : le contenu
                a bouge depuis l export (ou la valeur est calculee) ; rien n est
                propose, a trancher a la main
    A LA MAIN   la modification n est pas mecanique (texte compose, table de
                progression, objectif partage...) : la ligne a regarder est donnee
"""

import argparse
import difflib
import glob
import json
import math
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FORMAT = "time_wizard_changements"
GENERATORS = ["tools/make_content.gd", "tools/make_passives.gd"]
ANIM_CATALOG = "scripts/game/anim_catalog.gd"

ENUMS = {
    "rarity": "GameEnums.Rarity",
    "targeting": "GameEnums.Targeting",
    "kind": "GameEnums.EnemyKind",
    "shape": "GameEnums.Shape",
    "move_pattern": "EnemyDef.MovePattern",
}
# Arguments positionnels des helpers de make_content.gd (indice 0 = id).
ENEMY_ARGS = {"display_name": 1, "kind": 2, "power": 3, "max_hp": 4, "base_speed": 5,
              "base_xp": 6, "shape": 7, "color": 8, "base_radius": 9}
CARD_ARGS = {"display_name": 1, "description": 2, "rarity": 3, "base_cast_time": 4,
             "targeting": 5, "tags": 6, "copies_in_starter": 8}
SPEC_ARGS = {"key": 0, "magnitude": 1, "duration": 2, "radius": 3, "params": 4}
SPEC_DEFAULTS = ["", "0.0", "0.0", "0.0", "{}"]
FLOAT_FIELDS = {"max_hp", "base_speed", "base_radius", "sprite_scale", "base_cast_time",
                "magnitude", "duration", "radius", "difficulty", "spawn_delay",
                "start_offset", "dodge_chance"}
# Nom de l element dans le document -> cle de la table _resist().
RESIST_KEYS = {"physique": "phys", "feu": "feu", "givre": "givre", "arcane": "arcane",
               "poison": "poison", "foudre": "foudre", "ralentissement": "lent"}
# EnemyDef.accentuate() : la table ecrite dans _resist() est JOUEE apres elle.
RESIST_EXPONENT = 1.75
WEAK_EXPONENT = 2.5
WEAK_CAP = 2.0


# ---------------------------------------------------------------------------
# Lecture du GDScript : appels, arguments, lignes "var.champ = valeur"
# ---------------------------------------------------------------------------

def scan_expr_end(text, i, stop_chars):
    """Fin d une expression a partir de i : premier caractere de stop_chars a
    profondeur 0, hors chaine et hors commentaire. Rend l indice du stop."""
    depth = 0
    n = len(text)
    while i < n:
        c = text[i]
        if c == '"':
            i += 1
            while i < n and text[i] != '"':
                i += 2 if text[i] == "\\" else 1
        elif c == "#":
            while i < n and text[i] != "\n":
                i += 1
            continue
        elif c in "([{":
            depth += 1
        elif c in ")]}":
            if depth == 0 and c in stop_chars:
                return i
            depth -= 1
        elif depth == 0 and c in stop_chars:
            # Une fin de ligne precedee d un antislash continue l expression.
            if c == "\n" and text[:i].rstrip(" \t").endswith("\\"):
                i += 1
                continue
            return i
        i += 1
    return n


def call_args(text, open_paren):
    """Arguments d un appel : liste de (debut, fin) des expressions, et l indice
    de la parenthese fermante."""
    args = []
    i = open_paren + 1
    while True:
        end = scan_expr_end(text, i, ",)")
        if text[i:end].strip():
            args.append((i, end))
        if end >= len(text) or text[end] == ")":
            return args, end
        i = end + 1


def strip_span(text, span):
    s, e = span
    while s < e and text[s] in " \t\r\n":
        s += 1
    while e > s and text[e - 1] in " \t\r\n,":
        e -= 1
    return s, e


def line_of(text, pos):
    return text.count("\n", 0, pos) + 1


def find_assignment(text, var, field, start, end):
    """Valeur de `var.field = ...` entre start et end : (debut, fin) ou None."""
    m = re.compile(r"^[ \t]*%s\.%s[ \t]*=[ \t]*" % (re.escape(var), re.escape(field)),
                   re.M).search(text, start, end)
    if not m:
        return None
    vs = m.end()
    ve = scan_expr_end(text, vs, "\n")
    return strip_span(text, (vs, ve))


def literal_value(code):
    """Valeur Python d un litteral GDScript simple (nombre, booleen, texte), sinon None."""
    code = code.strip()
    if re.fullmatch(r"-?\d+(\.\d*)?([eE]-?\d+)?", code):
        return float(code)
    if code in ("true", "false"):
        return code == "true"
    m = re.fullmatch(r'&?"((?:[^"\\]|\\.)*)"', code, re.S)
    if m:
        return m.group(1).replace('\\"', '"').replace("\\n", "\n").replace("\\\\", "\\")
    return None


def same(a, b):
    if isinstance(a, bool) or isinstance(b, bool):
        return a == b
    if isinstance(a, (int, float)) and isinstance(b, (int, float)):
        return abs(float(a) - float(b)) <= 1e-6
    return a == b


# ---------------------------------------------------------------------------
# Ecriture de valeurs en GDScript
# ---------------------------------------------------------------------------

def gd_float(x):
    x = float(x)
    if abs(x - round(x)) < 1e-9:
        return "%d.0" % int(round(x))
    return ("%.4f" % x).rstrip("0").rstrip(".")


def short_float(x):
    """Ecriture des tables de resistances : 0.9, 1.15, 1.0."""
    t = ("%.2f" % float(x)).rstrip("0")
    return t + "0" if t.endswith(".") else t


def gd_string(s):
    return '"' + str(s).replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def gd_color(html):
    h = html.lstrip("#")
    vals = [int(h[i:i + 2], 16) / 255.0 for i in range(0, len(h), 2)]
    parts = ["%.2f" % v for v in vals[:3]]
    if len(vals) > 3 and vals[3] < 0.999:
        parts.append("%.2f" % vals[3])
    return "Color(%s)" % ", ".join(parts)


def card_path(card_id):
    for p in glob.glob(os.path.join(ROOT, "resources", "cards", "*", card_id + ".tres")):
        rel = os.path.relpath(p, ROOT).replace("\\", "/")
        return "res://" + rel
    return None


def gd_value(field, value):
    """Valeur encodee du document -> expression GDScript, ou None si on ne sait pas."""
    leaf = field.split("/")[-1]
    if value is None:
        return "null"
    if leaf in ENUMS and isinstance(value, str):
        return "%s.%s" % (ENUMS[leaf], value.upper())
    if leaf == "tags" and isinstance(value, list):
        return "[%s]" % ", ".join("GameEnums.DamageTag.%s" % str(v).upper() for v in value)
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        if leaf in FLOAT_FIELDS or (isinstance(value, float) and abs(value - round(value)) > 1e-9):
            return gd_float(value)
        return str(int(round(value)))
    if isinstance(value, str):
        if re.fullmatch(r"#[0-9a-fA-F]{6,8}", value) and leaf in ("color", "tint"):
            return gd_color(value)
        if leaf in ("key", "anim_key", "fx_key", "sfx_key", "twin_group", "demoted_from",
                    "intro_story", "outro_story"):
            return "&" + gd_string(value)
        return gd_string(value)
    return None


def accentuate(r):
    if r <= 0.0:
        return 0.0
    if r < 1.0:
        return round(r ** RESIST_EXPONENT, 2)
    if r > 1.0:
        return min(round(r ** WEAK_EXPONENT, 2), WEAK_CAP)
    return 1.0


def table_value_for(played):
    """La valeur a ECRIRE dans _resist() pour obtenir `played` apres accentuation."""
    if played <= 0.0:
        return 0.0
    if played < 1.0:
        guess = played ** (1.0 / RESIST_EXPONENT)
    elif played > 1.0:
        guess = min(played, WEAK_CAP) ** (1.0 / WEAK_EXPONENT)
    else:
        return 1.0
    # Au centieme pres, la valeur dont l accentuation retombe le plus pres.
    best = round(guess, 2)
    for d in range(-3, 4):
        c = round(guess + d * 0.01, 2)
        if abs(accentuate(c) - played) < abs(accentuate(best) - played):
            best = c
    return best


# ---------------------------------------------------------------------------
# Le rapport
# ---------------------------------------------------------------------------

class Workspace:
    def __init__(self):
        self.texts = {}
        self.edits = {}  # fichier -> [(debut, fin, nouveau)]

    def text(self, rel):
        if rel not in self.texts:
            with open(os.path.join(ROOT, rel), encoding="utf-8", newline="") as f:
                self.texts[rel] = f.read()
        return self.texts[rel]

    def edit(self, rel, start, end, new):
        for s, e, _ in self.edits.get(rel, []):
            if not (end <= s or start >= e):
                return False
        self.edits.setdefault(rel, []).append((start, end, new))
        return True

    def result(self, rel):
        t = self.text(rel)
        for s, e, new in sorted(self.edits.get(rel, []), key=lambda x: -x[0]):
            t = t[:s] + new + t[e:]
        return t

    def diff(self):
        out = []
        for rel in sorted(self.edits):
            a = self.text(rel).splitlines(keepends=True)
            b = self.result(rel).splitlines(keepends=True)
            out.extend(difflib.unified_diff(a, b, "a/" + rel, "b/" + rel))
        return "".join(out)


def find_def(ws, helper_names, ident):
    """(fichier, var, debut de l appel, parenthese ouvrante) du helper qui cree ident."""
    for rel in GENERATORS:
        if not os.path.exists(os.path.join(ROOT, rel)):
            continue
        t = ws.text(rel)
        for helper in helper_names:
            m = re.search(r'(?:var[ \t]+)?(\w+)[ \t]*:?=[ \t]*(%s)\([ \t\r\n]*"%s"'
                          % (helper, re.escape(ident)), t)
            if m:
                return rel, m.group(1), m.start(), m.end(2)
    return None


def block_end(text, var, start):
    m = re.compile(r"_save\(%s\b" % re.escape(var)).search(text, start)
    return m.start() if m else len(text)


def mentions(ws, ident):
    out = []
    for rel in GENERATORS:
        p = os.path.join(ROOT, rel)
        if not os.path.exists(p):
            continue
        t = ws.text(rel)
        for m in re.finditer(r'"%s"' % re.escape(ident), t):
            out.append("%s:%d" % (rel, line_of(t, m.start())))
    return out[:6]


def replace_or_check(ws, rel, span, change, new_code, compare_avant=True):
    """Remplace l expression `span` par new_code si elle porte bien `avant`."""
    t = ws.text(rel)
    old = t[span[0]:span[1]]
    lieu = "%s:%d" % (rel, line_of(t, span[0]))
    lu = literal_value(old)
    apres = change.get("apres")
    avant = change.get("avant")
    if lu is not None and not isinstance(apres, (list, dict)) and same(lu, apres):
        return "DEJA FAIT", lieu, "le code porte deja %s" % old
    if compare_avant and lu is not None and not isinstance(avant, (list, dict)) and not same(lu, avant):
        return "A VERIFIER", lieu, "le code dit %s, le document dit avant = %s" % (old, avant)
    if new_code is None:
        return "A LA MAIN", lieu, "ecrire %s (aujourd hui : %s)" % (apres, old)
    if lu is None and compare_avant and not isinstance(apres, list):
        return "A LA MAIN", lieu, "expression calculee (%s) : remplacer par %s" % (old.strip()[:60], new_code)
    ws.edit(rel, span[0], span[1], new_code)
    return "DIFF", lieu, "%s -> %s" % (old.strip()[:60], new_code[:60])


def insert_assignment(ws, rel, var, field, new_code, before):
    t = ws.text(rel)
    line_start = t.rfind("\n", 0, before) + 1
    indent = re.match(r"[ \t]*", t[line_start:]).group(0)
    ws.edit(rel, line_start, line_start, "%s%s.%s = %s\n" % (indent, var, field, new_code))
    return "DIFF", "%s:%d" % (rel, line_of(t, before)), "ajout de %s.%s = %s" % (var, field, new_code)


def handle_enemy(ws, ident, field, change):
    found = find_def(ws, ["_enemy"], ident)
    if not found:
        return "A LA MAIN", ", ".join(mentions(ws, ident)) or "?", "monstre non trouve dans les generateurs"
    rel, var, call_start, paren = found
    t = ws.text(rel)
    end = block_end(t, var, call_start)
    apres = change.get("apres")
    if field == "tint":
        return handle_tint(ws, ident, change)
    if field.startswith("resistances/"):
        elem = RESIST_KEYS.get(field.split("/")[1])
        m = re.compile(r"_resist\(%s,[ \t]*\{" % re.escape(var)).search(t, call_start, end)
        valeur = table_value_for(float(apres))
        note = "valeur jouee %s = %s ecrit dans la table (accentuation EnemyDef.accentuate)" % (apres, valeur)
        if abs(accentuate(valeur) - float(apres)) > 0.001:
            # L accentuation arrondit au centieme : toutes les valeurs jouees ne
            # sont pas atteignables, on dit laquelle le sera vraiment.
            note += " ; jouera %s (la plus proche atteignable)" % accentuate(valeur)
        if not m or elem is None:
            return "A LA MAIN", "%s:%d" % (rel, line_of(t, call_start)), "ajouter &\"%s\": %s a _resist(%s, ...) ; %s" % (elem, valeur, var, note)
        brace = m.end() - 1
        close = scan_expr_end(t, brace + 1, "}")
        km = re.compile(r'&"%s"[ \t]*:[ \t]*' % elem).search(t, brace, close)
        if km:
            vs = km.end()
            ve = scan_expr_end(t, vs, ",}")
            span = strip_span(t, (vs, ve))
            old = literal_value(t[span[0]:span[1]])
            if old is not None and change.get("avant") is not None and abs(accentuate(old) - float(change["avant"])) > 0.011:
                return "A VERIFIER", "%s:%d" % (rel, line_of(t, vs)), "la table dit %s (joue %s), le document dit avant = %s" % (old, accentuate(old), change["avant"])
            ws.edit(rel, span[0], span[1], short_float(valeur))
            return "DIFF", "%s:%d" % (rel, line_of(t, vs)), note
        ws.edit(rel, close, close, ', &"%s": %s' % (elem, short_float(valeur)))
        return "DIFF", "%s:%d" % (rel, line_of(t, brace)), "ajout de l element ; " + note
    if field in ENEMY_ARGS:
        args, _ = call_args(t, paren)
        k = ENEMY_ARGS[field]
        if k < len(args):
            span = strip_span(t, args[k])
            # Les enums des appels s ecrivent K.TANK / S.CIRCLE : on compare le nom.
            if field in ENUMS:
                old = t[span[0]:span[1]].split(".")[-1]
                if old.upper() == str(apres).upper():
                    return "DEJA FAIT", "%s:%d" % (rel, line_of(t, span[0])), ""
                ws.edit(rel, span[0], span[1], gd_value(field, apres))
                return "DIFF", "%s:%d" % (rel, line_of(t, span[0])), "%s -> %s" % (old, apres)
            return replace_or_check(ws, rel, span, change, gd_value(field, apres))
        if field == "base_radius":
            _, close = call_args(t, paren)
            ws.edit(rel, close, close, ", %s" % gd_float(apres))
            return "DIFF", "%s:%d" % (rel, line_of(t, close)), "rayon ajoute en dernier argument"
    return handle_assignment(ws, rel, var, field, change, call_start, end)


def handle_assignment(ws, rel, var, field, change, start, end):
    t = ws.text(rel)
    apres = change.get("apres")
    code = gd_value(field, apres)
    if isinstance(apres, list) or isinstance(apres, dict):
        code = None
    if field in ("split_into", "summon_def", "rebirth_def"):
        code = "null" if not apres else 'load("res://resources/enemies/%s.tres")' % apres
    span = find_assignment(t, var, field, start, end)
    if span:
        return replace_or_check(ws, rel, span, change, code, compare_avant=field not in ("split_into", "summon_def", "rebirth_def"))
    if code is None:
        return "A LA MAIN", "%s:%d" % (rel, line_of(t, start)), "ecrire %s.%s = %s" % (var, field, apres)
    return insert_assignment(ws, rel, var, field, code, end)


def handle_tint(ws, ident, change):
    t = ws.text(ANIM_CATALOG)
    code = gd_color(change.get("apres"))
    m = re.compile(r'"%s"[ \t]*:[ \t]*' % re.escape(ident)).search(t, t.find("const MODULATE"))
    if m:
        ve = scan_expr_end(t, m.end(), ",}")
        span = strip_span(t, (m.end(), ve))
        ws.edit(ANIM_CATALOG, span[0], span[1], code)
        return "DIFF", "%s:%d" % (ANIM_CATALOG, line_of(t, m.start())), "teinte du sprite -> %s" % code
    start = t.find("const MODULATE")
    brace = t.find("{", start)
    nl = t.find("\n", brace) + 1
    ws.edit(ANIM_CATALOG, nl, nl, '\t"%s": %s,\n' % (ident, code))
    return "DIFF", "%s:%d" % (ANIM_CATALOG, line_of(t, start)), "teinte ajoutee a AnimCatalog.MODULATE : %s" % code


def handle_card(ws, ident, field, change):
    found = find_def(ws, ["_card", "_passive"], ident)
    if not found:
        return "A LA MAIN", ", ".join(mentions(ws, ident)) or "?", "carte non trouvee dans les generateurs"
    rel, var, call_start, paren = found
    t = ws.text(rel)
    end = block_end(t, var, call_start)
    apres = change.get("apres")
    passive = t[call_start:paren].rstrip().endswith("_passive")
    if field.startswith("effects/"):
        parts = field.split("/")
        idx = int(parts[1])
        sub = parts[2]
        if passive:
            return "A LA MAIN", "%s:%d" % (rel, line_of(t, call_start)), "passif : effet unique (cle, magnitude) dans _passive(...) ; ecrire %s = %s" % (sub, apres)
        args, _ = call_args(t, paren)
        if len(args) <= 7:
            return "A LA MAIN", "%s:%d" % (rel, line_of(t, call_start)), "liste d effets introuvable"
        s, e = strip_span(t, args[7])
        specs = [m.start() for m in re.finditer(r"_spec\(", t[s:e])]
        if idx >= len(specs):
            return "A LA MAIN", "%s:%d" % (rel, line_of(t, s)), "effet %d introuvable" % (idx + 1)
        sp = s + specs[idx] + len("_spec")
        sargs, sclose = call_args(t, sp)
        if sub == "params":
            k = parts[3]
            if len(sargs) < 5:
                return "A LA MAIN", "%s:%d" % (rel, line_of(t, sp)), "parametre %s absent de l appel" % k
            ps, pe = strip_span(t, sargs[4])
            km = re.compile(r'&?"%s"[ \t]*:[ \t]*' % re.escape(k)).search(t, ps, pe)
            if not km:
                return "A LA MAIN", "%s:%d" % (rel, line_of(t, ps)), "parametre %s introuvable" % k
            ve = scan_expr_end(t, km.end(), ",}")
            span = strip_span(t, (km.end(), ve))
            old = t[span[0]:span[1]]
            new = gd_float(apres) if "." in old else str(int(round(float(apres))))
            return replace_or_check(ws, rel, span, change, new)
        k = SPEC_ARGS.get(sub)
        if k is None:
            return "A LA MAIN", "%s:%d" % (rel, line_of(t, sp)), "champ d effet %s" % sub
        new = gd_value(sub, apres) if sub != "key" else gd_string(apres)
        if k < len(sargs):
            return replace_or_check(ws, rel, strip_span(t, sargs[k]), change, new)
        # Argument par defaut : on complete jusqu a lui.
        manquants = [SPEC_DEFAULTS[j] for j in range(len(sargs), k)] + [new]
        ws.edit(rel, sclose, sclose, ", " + ", ".join(manquants))
        return "DIFF", "%s:%d" % (rel, line_of(t, sp)), "argument %s ajoute : %s" % (sub, new)
    if field in CARD_ARGS and not passive:
        args, _ = call_args(t, paren)
        k = CARD_ARGS[field]
        if k < len(args):
            span = strip_span(t, args[k])
            if field in ENUMS:
                old = t[span[0]:span[1]].split(".")[-1]
                if old.upper() == str(apres).upper():
                    return "DEJA FAIT", "%s:%d" % (rel, line_of(t, span[0])), ""
                ws.edit(rel, span[0], span[1], gd_value(field, apres))
                note = "%s -> %s" % (old, apres)
                if field == "rarity":
                    note += " ; le _save() ecrit encore dans resources/cards/%s/ : deplacer le " \
                            "fichier si le dossier doit suivre la rarete" % old.lower()
                return "DIFF", "%s:%d" % (rel, line_of(t, span[0])), note
            if field == "tags":
                ws.edit(rel, span[0], span[1], gd_value(field, apres))
                return "DIFF", "%s:%d" % (rel, line_of(t, span[0])), "tags -> %s" % apres
            if field == "description":
                # Un texte compose sur plusieurs lignes ("..." + "...") est
                # remplace d un bloc par le texte complet.
                ws.edit(rel, span[0], span[1], gd_string(apres))
                return "DIFF", "%s:%d" % (rel, line_of(t, span[0])), "description remplacee"
            return replace_or_check(ws, rel, span, change, gd_value(field, apres))
    return handle_assignment(ws, rel, var, field, change, call_start, end)


def level_block(ws, ident):
    for rel in GENERATORS:
        p = os.path.join(ROOT, rel)
        if not os.path.exists(p):
            continue
        t = ws.text(rel)
        m = re.search(r'^[ \t]*(\w+)\.id[ \t]*=[ \t]*&"%s"' % re.escape(ident), t, re.M)
        if m:
            var = m.group(1)
            nxt = re.compile(r'^[ \t]*\w+\.id[ \t]*=[ \t]*&"lvl_|^func ', re.M).search(t, m.end())
            return rel, var, t.rfind("\n", 0, m.start()) + 1, nxt.start() if nxt else len(t)
    return None


def handle_level(ws, ident, field, change):
    found = level_block(ws, ident)
    if not found:
        return "A LA MAIN", "?", "niveau non trouve dans les generateurs"
    rel, var, start, end = found
    t = ws.text(rel)
    apres = change.get("apres")
    if field in ("objectives", "objective_rewards", "levelup_cards"):
        m = re.search(r'&"%s":' % re.escape(ident), t[t.find("func _progression_de"):])
        ligne = line_of(t, t.find("func _progression_de") + m.start()) if m else 0
        return "A LA MAIN", "%s:%d" % (rel, ligne), "table _progression_de : %s = %s" % (field, apres)
    if field == "exploration_deck":
        span = find_assignment(t, var, field, start, end)
        groupes = []
        for cid in apres:
            if groupes and groupes[-1][0] == cid:
                groupes[-1][1] += 1
            elif any(g[0] == cid for g in groupes):
                next(g for g in groupes if g[0] == cid)[1] += 1
            else:
                groupes.append([cid, 1])
        # Le style du fichier : `C + "common/x.tres"` quand le bloc l emploie.
        style_c = span is not None and 'C + "' in t[span[0]:span[1]]
        lignes = []
        for cid, n in groupes:
            p = card_path(cid)
            if p is None:
                return "A LA MAIN", "%s:%d" % (rel, line_of(t, start)), "carte %s sans .tres" % cid
            if style_c:
                lignes.append('\t\t[C + "%s", %d],' % (p.replace("res://resources/cards/", ""), n))
            else:
                lignes.append('\t\t["%s", %d],' % (p, n))
        code = "_deck([\n%s\n\t])" % "\n".join(lignes)
        if span is None:
            return insert_assignment(ws, rel, var, field, code, end)
        ws.edit(rel, span[0], span[1], code)
        return "DIFF", "%s:%d" % (rel, line_of(t, span[0])), "deck reecrit (%d cartes)" % len(apres)
    if field == "enemy_pool":
        span = find_assignment(t, var, field, start, end)
        code = "[\n%s\n\t]" % "\n".join('\t\tload("res://resources/enemies/%s.tres"),' % e for e in apres)
        if span is None:
            return insert_assignment(ws, rel, var, field, code, end)
        ws.edit(rel, span[0], span[1], code)
        return "DIFF", "%s:%d" % (rel, line_of(t, span[0])), "pool reecrit (%d monstres)" % len(apres)
    if field == "next_levels":
        span = find_assignment(t, var, field, start, end)
        code = "[%s]" % ", ".join('&"%s"' % x for x in apres)
        if span is None:
            return insert_assignment(ws, rel, var, field, code, end)
        ws.edit(rel, span[0], span[1], code)
        return "DIFF", "%s:%d" % (rel, line_of(t, span[0])), "niveaux suivants -> %s" % code
    if field == "waves/#":
        span = find_assignment(t, var, "waves", start, end)
        return "A LA MAIN", "%s:%d" % (rel, line_of(t, span[0]) if span else start), \
            "nombre de vagues %s -> %s : dupliquer / retirer un bloc WaveDef et la liste %s.waves" % (change.get("avant"), apres, var)
    if field.startswith("waves/"):
        return handle_wave(ws, rel, var, start, end, int(field.split("/")[1]), change)
    return handle_assignment(ws, rel, var, field, change, start, end)


def handle_wave(ws, rel, var, start, end, idx, change):
    t = ws.text(rel)
    span = find_assignment(t, var, "waves", start, end)
    if span is None:
        return "A LA MAIN", "%s:%d" % (rel, line_of(t, start)), "liste des vagues introuvable"
    noms = [n.strip() for n in t[span[0] + 1:span[1] - 1].split(",") if n.strip()]
    apres = change.get("apres") or {}
    if idx >= len(noms):
        return "A LA MAIN", "%s:%d" % (rel, line_of(t, span[0])), \
            "vague %d AJOUTEE : creer un bloc WaveDef (%s) et l ajouter a %s.waves" % (idx + 1, wave_text(apres), var)
    w = noms[idx]
    m = re.compile(r"var[ \t]+%s[ \t]*:?=[ \t]*WaveDef\.new\(\)" % re.escape(w)).search(t)
    if not m:
        return "A LA MAIN", "%s:%d" % (rel, line_of(t, span[0])), "bloc de la vague %s introuvable" % w
    ws_end = block_end(t, w, m.end())
    notes = []
    statut = "DIFF"
    avant = change.get("avant") or {}
    for champ in ("duration", "difficulty", "is_boss", "is_miniboss"):
        if champ not in apres or same(apres.get(champ), avant.get(champ, apres.get(champ))):
            continue
        sub_change = {"avant": avant.get(champ), "apres": apres[champ]}
        s, lieu, n = handle_assignment(ws, rel, w, champ, sub_change, m.start(), ws_end)
        notes.append("%s %s" % (champ, n))
        if s != "DIFF":
            statut = s if statut == "DIFF" else statut
    if apres.get("entries") != avant.get("entries"):
        es = find_assignment(t, w, "entries", m.start(), ws_end)
        if es is None:
            return "A LA MAIN", "%s:%d" % (rel, line_of(t, m.start())), "entrees de %s introuvables" % w
        prefixe = 'E + "%s.tres"' if 'E + "' in t[es[0]:es[1]] else '"res://resources/enemies/%s.tres"'
        lignes = []
        for e in apres.get("entries", []):
            a = [prefixe % e["enemy"], str(int(e["count"])), gd_float(e["spawn_delay"])]
            if float(e.get("start_offset", 0.0)) > 0.0:
                a.append(gd_float(e["start_offset"]))
            lignes.append("\t\t_entry(%s)," % ", ".join(a))
        ws.edit(rel, es[0], es[1], "[\n%s\n\t]" % "\n".join(lignes))
        notes.append("entrees reecrites : %s" % wave_text(apres))
    if not notes:
        return "DEJA FAIT", "%s:%d" % (rel, line_of(t, m.start())), ""
    return statut, "%s:%d" % (rel, line_of(t, m.start())), "vague %s (%s) : %s" % (idx + 1, w, " ; ".join(notes))


def wave_text(w):
    if not isinstance(w, dict):
        return "(aucune)"
    return ", ".join("%s x%s" % (e.get("enemy"), e.get("count")) for e in w.get("entries", [])) + \
        " (difficulte %s, %s s)" % (w.get("difficulty"), w.get("duration"))


def handle_objective(ws, ident, field, change):
    return "A LA MAIN", "tools/make_content.gd, table _progression_de", \
        "objectif PARTAGE (DEC-023, id deduit des parametres) : changer %s = %s dans chaque _objectif(...) qui le produit ; l id changera" % (field, change.get("apres"))


def handle(ws, change):
    cible = str(change.get("cible", ""))
    champ = str(change.get("champ", ""))
    if ":" not in cible:
        return "A LA MAIN", "?", "cible illisible"
    genre, ident = cible.split(":", 1)
    try:
        if genre == "enemy":
            return handle_enemy(ws, ident, champ, change)
        if genre == "card":
            return handle_card(ws, ident, champ, change)
        if genre == "level":
            return handle_level(ws, ident, champ, change)
        if genre == "objective":
            return handle_objective(ws, ident, champ, change)
    except (ValueError, KeyError, TypeError, IndexError) as exc:
        return "A LA MAIN", "?", "lecture impossible (%s)" % exc
    return "A LA MAIN", "?", "genre de cible inconnu"


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("document", help="document de changement (JSON) ; - pour l entree standard")
    ap.add_argument("--patch", help="ecrit le diff propose dans ce fichier (git apply)")
    ap.add_argument("--ecrire", action="store_true", help="applique le diff aux generateurs")
    args = ap.parse_args(argv)
    # La console Windows n est pas toujours en UTF-8 : un tiret long du code
    # cite dans le diff ne doit pas faire planter le rapport.
    try:
        sys.stdout.reconfigure(errors="replace")
    except AttributeError:
        pass
    raw = sys.stdin.read() if args.document == "-" else open(args.document, encoding="utf-8").read()
    try:
        doc = json.loads(raw)
    except json.JSONDecodeError as exc:
        print("Document illisible : %s" % exc)
        return 2
    if doc.get("format") != FORMAT:
        print("Ce n est pas un document de changement Time Wizard (format = %r)." % doc.get("format"))
        return 2
    jeu = doc.get("jeu", {})
    print("DOCUMENT DE CHANGEMENT du %s - %s" % (doc.get("date", "?"), doc.get("resume", "")))
    print("  exporte depuis : %s %s, commit %s" % (jeu.get("nom", "?"), jeu.get("version", ""), jeu.get("commit", "?")))
    print("  mode testeur au moment de l export : %s" % ("oui" if doc.get("mode_testeur") else "NON (reglages non joues)"))
    print()
    ws = Workspace()
    compte = {}
    for i, ch in enumerate(doc.get("changements", []), 1):
        statut, lieu, note = handle(ws, ch)
        compte[statut] = compte.get(statut, 0) + 1
        print("%2d. [%s] %s" % (i, statut, ch.get("texte") or "%s / %s" % (ch.get("cible"), ch.get("champ"))))
        print("      %s / %s : %s -> %s" % (ch.get("cible"), ch.get("champ"),
                                            json.dumps(ch.get("avant"), ensure_ascii=False)[:120],
                                            json.dumps(ch.get("apres"), ensure_ascii=False)[:120]))
        print("      ou : %s%s" % (lieu, ("  - " + note) if note else ""))
    for r in doc.get("ignores", []):
        print("  ignore par le jeu : %s / %s : %s" % (r.get("cible"), r.get("champ"), r.get("raison")))
    print()
    print("Bilan : " + ", ".join("%d %s" % (n, s) for s, n in sorted(compte.items())))
    diff = ws.diff()
    if args.patch:
        with open(args.patch, "w", encoding="utf-8", newline="") as f:
            f.write(diff)
        print("Diff ecrit : %s (git apply %s)" % (args.patch, args.patch))
    if args.ecrire:
        for rel in ws.edits:
            with open(os.path.join(ROOT, rel), "w", encoding="utf-8", newline="") as f:
                f.write(ws.result(rel))
        print("Generateurs modifies : %s" % ", ".join(sorted(ws.edits)))
        print("Ensuite : Godot --headless --path . tools/make_content.tscn ; bash tools/run_tests.sh")
    elif diff and not args.patch:
        print()
        print("--- DIFF PROPOSE (rien n est ecrit ; --patch FICHIER ou --ecrire) ---")
        print(diff)
    return 0


if __name__ == "__main__":
    sys.exit(main())
