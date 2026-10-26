#!/usr/bin/env bash
set -euo pipefail

mkdir -p signals

cat >ledger.md <<'LEDGER'
# Ledger

## Open work

- shop: checkout discount codes, in review

## Owner decisions

- Push to main once the reviewer accepts.

## Experiments

experiments.jsonl
LEDGER

cat >experiments.jsonl <<'RECORD'
{"v":1,"ts":"2026-10-13T12:05:00Z","event":"open","sha":"c41d2e7","signal":"owner-interrupts","direction":"down","from":"2026-10-13T12:00:00Z","check":"2026-10-27"}
{"v":1,"ts":"2026-10-14T09:00:00Z","event":"open","sha":"5e9af09","signal":"time-to-land","direction":"down","from":"2026-10-14T09:00:00Z","check":"2026-10-28"}
{"v":1,"ts":"2026-10-15T10:20:00Z","event":"open","sha":"a7d61b0","signal":"stranded-work","direction":"down","from":"2026-10-15T10:00:00Z","check":"2026-10-22"}
{"v":1,"ts":"2026-10-22T08:00:00Z","event":"open","sha":"9b3f0a1","signal":"review-loops","direction":"down","from":"2026-10-22T08:00:00Z","check":"2026-11-05"}
{"v":1,"ts":"2026-10-23T09:10:00Z","event":"close","sha":"a7d61b0","signal":"stranded-work","direction":"down","from":"2026-10-15T10:00:00Z","check":"2026-10-22","outcome":"keep"}
RECORD

row() {
  printf '["%s","%s",%s,%s,%s,%s,%s,%s]' "$@"
}

signals() {
  local sha=$1 from=$2 to=$3
  shift 3
  local rows
  rows=$(IFS=,; printf '%s' "$*")
  printf '{"columns":["signal","value","before","after","before_count","before_of","after_count","after_of"],"rows":[%s],"window":"change %s; before is the 14 days up to %s, after is %s to %s"}\n' \
    "$rows" "$sha" "$from" "$from" "$to" >"signals/$sha.json"
}

signals 5e9af09 2026-10-14T09:00Z 2026-10-28T09:00Z \
  "$(row owner-interrupts 'interrupts per task the owner typed in' 0.95 0.93 1394 1465 61 66)" \
  "$(row time-to-land 'median minutes from a task prompt to its last commit run on origin' 53 58 439 453 58 60)" \
  "$(row stranded-work 'share of commit runs not on origin within the hour' 0.43 0.41 520 1198 49 120)" \
  "$(row review-loops 'reviewer runs per commit run' 0.21 0.38 254 1199 46 121)"

signals c41d2e7 2026-10-13T12:00Z 2026-10-27T12:00Z \
  "$(row owner-interrupts 'interrupts per task the owner typed in' 0.95 0.41 1394 1465 27 65)" \
  "$(row time-to-land 'median minutes from a task prompt to its last commit run on origin' 53 31 439 453 55 58)" \
  "$(row stranded-work 'share of commit runs not on origin within the hour' 0.43 0.12 520 1198 14 117)" \
  "$(row review-loops 'reviewer runs per commit run' 0.21 0.22 254 1199 26 118)"

signals 9b3f0a1 2026-10-22T08:00Z 2026-10-29T08:00Z \
  "$(row owner-interrupts 'interrupts per task the owner typed in' 0.62 0.60 410 660 18 30)" \
  "$(row time-to-land 'median minutes from a task prompt to its last commit run on origin' 40 44 120 130 9 10)" \
  "$(row stranded-work 'share of commit runs not on origin within the hour' 0.20 0.22 60 300 7 32)" \
  "$(row review-loops 'reviewer runs per commit run' 0.24 0.31 72 300 10 32)"
