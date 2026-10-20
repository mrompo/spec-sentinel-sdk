#!/usr/bin/env bash
# synthesis.sh <dir> — Veredicto determinista del panel (docs/05-semantica.md §Tribunal).
# Entrada en <dir>: findings-{auditor,adversary,pragmatist}.json (ronda review) y
# votes-{auditor,adversary,pragmatist}.json (ronda counter-review:
#   {"lens":"…","votes":[{"id":"A1","agree":true,"severity":"major","note":"…"}]}).
# Validado-cruzado: lo sostienen ≥2 lentes (la suya + ≥1 voto agree:true de otra).
# Severidad efectiva de un validado: la menor entre la de su lente y la más alta que le dan
# las lentes que lo apoyan (un blocker necesita dos lentes que lo vean blocker).
# Regla:
#   HOLD        ← algún blocker validado-cruzado
#   CONDITIONAL ← algún major validado-cruzado, o algún blocker sin validar (pide disposición)
#   SHIP        ← en otro caso
set -euo pipefail
D="${1:?uso: synthesis.sh <dir>}"
jq -s '
  {"blocker":0,"major":1,"minor":2,"nit":3} as $rank
  | ["blocker","major","minor","nit"] as $name
  | (map(select(has("findings"))) | map(.lens as $l | .findings[] | . + {lens: $l})) as $f
  | (map(select(has("votes"))) | map(.lens as $l | .votes[] | . + {voter: $l})) as $v
  | [ $f[] | . as $x
      | [ $v[] | select(.id == $x.id and .voter != $x.lens) ] as $mine
      | [ $mine[] | select(.agree == true) ] as $yes
      | ($yes | length) as $ny
      | (if $ny > 0
           then ([ $yes[] | $rank[.severity // $x.severity] ] | min) as $best
                | ([ $rank[$x.severity], $best ] | max)
           else $rank[$x.severity] end) as $eff
      | $x + {support: (1 + $ny), against: ([ $mine[] | select(.agree == false) ] | length),
              validated: ($ny >= 1), effective: $name[$eff]} ]
  | . as $all
  | {
      verdict: (
        if any($all[]; .validated and .effective == "blocker") then "HOLD"
        elif any($all[]; (.validated and .effective == "major") or ((.validated | not) and .severity == "blocker")) then "CONDITIONAL"
        else "SHIP" end),
      counts: ($all | group_by(.effective) | map({(.[0].effective): {total: length, validated: (map(select(.validated)) | length)}}) | add),
      findings: ($all | sort_by($rank[.effective], (.validated | not), .id)
                 | map({id, lens, severity, effective, validated, support, against, file, line, title}))
    }
' "$D"/findings-*.json "$D"/votes-*.json
