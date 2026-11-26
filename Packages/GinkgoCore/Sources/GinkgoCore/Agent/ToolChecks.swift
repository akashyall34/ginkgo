import Foundation

/// One checked item: its JSON for the model and its words for the trace.
struct CheckRow {
    var json: JSON
    var summary: String
    var passes: Bool
}

struct FitRequest {
    var name: String
    var source: String
    var width: Double
    var height: Double
}

// MARK: - check_fit

extension ToolExecutor {
    func checkFit(_ args: JSON, index: Int, reason: String) throws(ToolInputError) -> ToolOutcome {
        var requests: [FitRequest] = []
        for (number, item) in try args.list("placements").enumerated() {
            let context = "placements[\(number)]"
            let name = try item.string("new_part", in: context)
            let source = try item.string("source_part_id", in: context)
            let width = try item.number("width_mm", in: context)
            let height = try item.number("height_mm", in: context)
            requests.append(FitRequest(name: name, source: source, width: width, height: height))
        }
        let rows = fitRows(requests)
        let allFit = rows.allSatisfy(\.passes)
        let response: JSON = ["all_fit": .bool(allFit), "results": .array(rows.map(\.json))]
        return ToolOutcome(
            result: ToolResult(name: Tool.checkFit.rawValue, response: response),
            step: AgentStep(index: index, reason: reason, status: allFit ? .pass : .fail,
                            summary: rows.map(\.summary).joined(separator: "; "), tool: .checkFit),
            accepted: nil)
    }

    /// Packs each source part once with all its requested cuts, then reports every request in the order asked.
    func fitRows(_ requests: [FitRequest]) -> [CheckRow] {
        let parts = partsByID
        var packs: [String: PackResult] = [:]
        for source in Set(requests.map(\.source)) {
            guard let part = parts[source] else { continue }
            let cuts = requests.enumerated().filter { $0.element.source == source }
                .map { CutRequest(name: "#\($0.offset)", widthMm: $0.element.width, heightMm: $0.element.height) }
            packs[source] = Packer.pack(source: part, cuts: cuts)
        }
        return requests.enumerated().map { number, request in
            guard let part = parts[request.source], let pack = packs[request.source] else {
                return blocked(request, by: "unknown_part", words: "no such part", hint: "Use one of: \(validIDs).")
            }
            return fitRow(request, number: number, part: part, pack: pack)
        }
    }

    func fitRow(_ request: FitRequest, number: Int, part: Part, pack: PackResult) -> CheckRow {
        let cut = CutRequest(name: request.name, widthMm: request.width, heightMm: request.height)
        let whole = Packer.reserved(for: cut, on: part).wholeRotated != nil
        if part.damaged {
            return blocked(request, by: "damaged", words: "part is damaged", hint: "\(part.id) is damaged; use another part.")
        }
        if !part.material.canBeCut && !whole {
            let material = part.material.displayName
            let hint = "\(part.id) is \(material), which \(part.material.whyNotCut); reuse it whole or use another part."
            return blocked(request, by: part.material.rawValue, words: "\(material) can't be cut", hint: hint)
        }
        if let placement = pack.placements.first(where: { $0.newPart == "#\(number)" }) {
            let spare = min(pack.spareWidthMm, pack.spareHeightMm)
            return CheckRow(
                json: ["new_part": .string(request.name), "source_part_id": .string(part.id), "fits": true,
                       "spare_mm": [Self.rounded(pack.spareWidthMm), Self.rounded(pack.spareHeightMm)],
                       "rotated": .bool(placement.rotated)],
                summary: "\(request.name) from \(part.id): fits, \(Format.mm(spare)) mm to spare", passes: true)
        }
        // Every cut the Packer is given ends up placed or failed, so the fallback below never runs.
        let failure = pack.failures.first { $0.name == "#\(number)" } ?? Packer.invalidFailure(cut, source: part)
        let words: String
        switch failure.reason {
        case .invalidSize: words = "size must be more than 0 mm"
        case .tooBig: words = "\(Format.mm(failure.shortByMm)) mm short"
        case .blockedByKeepOuts: words = "blocked by screw holes or damage"
        case .noRoomLeft: words = "no room left after the other cuts"
        }
        return blocked(request, by: failure.reason.rawValue, words: words, hint: failure.hint, extra: [
            "needed_mm": .array(failure.neededMm.map(Self.rounded)), "available_mm": .array(failure.availableMm.map(Self.rounded)),
            "short_by_mm": Self.rounded(failure.shortByMm),
        ])
    }

    func blocked(_ request: FitRequest, by reason: String, words: String, hint: String,
                 extra: [String: JSON] = [:]) -> CheckRow {
        var json: [String: JSON] = ["new_part": .string(request.name), "source_part_id": .string(request.source),
                                    "fits": false, "blocked_by": .string(reason), "hint": .string(hint)]
        for (key, value) in extra { json[key] = value }
        return CheckRow(json: .object(json), summary: "\(request.name) from \(request.source): \(words)", passes: false)
    }
}

// MARK: - check_sag

extension ToolExecutor {
    func checkSag(_ args: JSON, index: Int, reason: String) throws(ToolInputError) -> ToolOutcome {
        let parts = partsByID
        var rows: [CheckRow] = []
        for (number, item) in try args.list("items").enumerated() {
            rows.append(try sagRow(item, context: "items[\(number)]", parts: parts))
        }
        let allPass = rows.allSatisfy(\.passes)
        let response: JSON = ["all_pass": .bool(allPass), "results": .array(rows.map(\.json))]
        return ToolOutcome(
            result: ToolResult(name: Tool.checkSag.rawValue, response: response),
            step: AgentStep(index: index, reason: reason, status: allPass ? .pass : .fail,
                            summary: rows.map(\.summary).joined(separator: "; "), tool: .checkSag),
            accepted: nil)
    }

    func sagRow(_ item: JSON, context: String, parts: [String: Part]) throws(ToolInputError) -> CheckRow {
        let name = try item.string("new_part", in: context)
        let source = try item.string("source_part_id", in: context)
        let roleText = try item.string("role", in: context)
        guard let role = Role(rawValue: roleText), let load = Sag.designLoadKg(for: role) else {
            throw ToolInputError("\(context).role must be seat or shelf")
        }
        let span = try item.number("span_mm", in: context)
        let depth = try item.number("depth_mm", in: context)
        guard let part = parts[source] else {
            let error = "no part \"\(source)\". Use one of: \(validIDs)."
            return CheckRow(json: ["new_part": .string(name), "passes": false, "error": .string(error)],
                            summary: "\(name): no such part \"\(source)\"", passes: false)
        }
        do {
            let result = try Sag.check(name: name, loadKg: load, spanMm: span, depthMm: depth, source: part)
            // Two decimals: sag values are small, and 0.1 mm rounding can make a failure look equal to its limit.
            let bend = String(format: "%.2f of %.2f mm allowed", result.deflectionMm, result.limitMm)
            return CheckRow(
                json: ["new_part": .string(name), "deflection_mm": Self.rounded(result.deflectionMm),
                       "limit_mm": Self.rounded(result.limitMm), "passes": .bool(result.passes)],
                summary: "\(name): bends \(bend)" + (result.passes ? "" : ", too much"), passes: result.passes)
        } catch {
            return CheckRow(json: ["new_part": .string(name), "passes": false, "error": .string(error.message)],
                            summary: "\(name): \(error.message)", passes: false)
        }
    }
}
