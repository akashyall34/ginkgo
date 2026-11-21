#!/usr/bin/env bash
# Regenerates the Swift models from schema/ginkgo.schema.json. Never edit the output by hand.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT=Packages/GinkgoCore/Sources/GinkgoCore/Models/GinkgoModels.swift
mkdir -p "$(dirname "$OUT")"
npx --yes quicktype@26.0.0 -s schema "schema/ginkgo.schema.json#/definitions/" \
  -l swift --struct-or-class struct --access-level public --protocol equatable -o "$OUT.tmp"
# Public types need explicit Sendable for Swift 6. Every generated type ends its header with "Codable, Equatable {".
sed 's/Codable, Equatable {/Codable, Equatable, Sendable {/' "$OUT.tmp" > "$OUT" && rm "$OUT.tmp"
grep -q "Sendable {" "$OUT" || { echo "Sendable patch failed"; exit 1; }
echo "Generated $OUT"
