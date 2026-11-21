#!/usr/bin/env bash
# Regenerates the Swift models from schema/ginkgo.schema.json. Never edit the output by hand.
set -euo pipefail
cd "$(dirname "$0")/.."
quicktype -s schema "schema/ginkgo.schema.json#/definitions/" \
  -l swift --struct-or-class struct --access-level internal \
  -o Ginkgo/Models/GinkgoModels.swift
echo "Generated Ginkgo/Models/GinkgoModels.swift"
