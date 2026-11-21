import Foundation

/// The judge of every plan, whoever wrote it. Pure and deterministic, and it never throws:
/// bad input becomes violations with plain-English messages.
public enum Validator {
    /// How many measurements to list for the user to double-check before cutting.
    static let verifyCount = 3

    public static func validate(plan: Plan, inventory: Inventory, limits: SizeLimits?) -> ValidationResult {
        let parts = Dictionary(inventory.parts.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let packs = pack(plan, inventory: inventory)
        let sag = sagResults(plan, parts: parts)
        let violations = unknownParts(plan, inventory: inventory)
            + duplicateNames(plan)
            + damagedParts(plan, parts: parts)
            + cutsNotAllowed(plan, parts: parts)
            + fitViolations(plan, packs: packs, parts: parts)
            + sag.violations
            + sizeViolations(plan, limits: limits)
        return ValidationResult(
            passes: violations.isEmpty, placements: packs.flatMap(\.placements), planID: plan.id,
            reusePercent: reusePercent(plan, inventory: inventory), sag: sag.results,
            verify: verifyItems(packs), violations: violations)
    }

    // MARK: - 1 to 4: parts

    static func unknownParts(_ plan: Plan, inventory: Inventory) -> [Violation] {
        let ids = inventory.parts.map(\.id)
        return plan.newParts.filter { !ids.contains($0.sourcePartID) }.map { newPart in
            Violation(code: .unknownPart,
                      message: "\(newPart.name): there is no part \"\(newPart.sourcePartID)\". "
                        + "Use one of: \(ids.joined(separator: ", ")).",
                      newPart: newPart.name)
        }
    }

    static func duplicateNames(_ plan: Plan) -> [Violation] {
        var seen: Set<String> = []
        var reported: Set<String> = []
        var violations: [Violation] = []
        for newPart in plan.newParts {
            if seen.insert(newPart.name).inserted || !reported.insert(newPart.name).inserted { continue }
            violations.append(Violation(
                code: .partUsedTwice, message: "\(newPart.name): two new parts have this name. Give each part its own name.",
                newPart: newPart.name))
        }
        return violations
    }

    static func damagedParts(_ plan: Plan, parts: [String: Part]) -> [Violation] {
        var violations: [Violation] = []
        for newPart in plan.newParts {
            guard let part = parts[newPart.sourcePartID] else { continue }
            if part.damaged { // MUTANT:damaged
                violations.append(Violation(
                    code: .damagedPartUsed, message: "\(newPart.name): \(part.id) is damaged and can't be used.",
                    newPart: newPart.name))
            }
        }
        return violations
    }

    static func cutsNotAllowed(_ plan: Plan, parts: [String: Part]) -> [Violation] {
        plan.newParts.compactMap { newPart in
            guard let part = parts[newPart.sourcePartID], !isWhole(newPart, of: part) else { return nil }
            let size = "\(Format.mm(newPart.widthMm)) × \(Format.mm(newPart.heightMm)) mm"
            if part.material == .particleboardMDF {
                return Violation(
                    code: .cutNotAllowed,
                    message: "\(newPart.name): \(part.id) is particleboard/MDF, which crumbles when cut. "
                        + "Reuse it whole (\(dimensions(part))) instead of cutting \(size).",
                    newPart: newPart.name)
            }
            if plan.template == .noCut {
                return Violation(
                    code: .cutNotAllowed,
                    message: "\(newPart.name): the no_cut template reuses parts whole, but this cuts \(size) "
                        + "from \(part.id) (\(dimensions(part))).",
                    newPart: newPart.name)
            }
            return nil
        }
    }

    static func isWhole(_ newPart: NewPart, of part: Part) -> Bool {
        let cut = CutRequest(name: newPart.name, widthMm: newPart.widthMm, heightMm: newPart.heightMm)
        return Packer.reserved(for: cut, on: part).wholeRotated != nil
    }

    // MARK: - 5: fit

    /// Packs every known source part that has cuts, in inventory order.
    static func pack(_ plan: Plan, inventory: Inventory) -> [PackResult] {
        var packed: Set<String> = []
        return inventory.parts.compactMap { part in
            guard packed.insert(part.id).inserted else { return nil }
            let cuts = plan.newParts.filter { $0.sourcePartID == part.id }
                .map { CutRequest(name: $0.name, widthMm: $0.widthMm, heightMm: $0.heightMm) }
            return cuts.isEmpty ? nil : Packer.pack(source: part, cuts: cuts)
        }
    }

    static func fitViolations(_ plan: Plan, packs: [PackResult], parts: [String: Part]) -> [Violation] {
        let order = plan.newParts.map(\.name)
        let failures = packs.flatMap { pack in pack.failures.map { (failure: $0, source: pack.sourcePartID) } }
        return failures
            .sorted { (order.firstIndex(of: $0.failure.name) ?? 0) < (order.firstIndex(of: $1.failure.name) ?? 0) }
            .compactMap { item in
                guard let part = parts[item.source] else { return nil }
                return fitViolation(item.failure, part: part)
            }
    }

    static func fitViolation(_ failure: PackFailure, part: Part) -> Violation {
        let name = failure.name
        switch failure.reason {
        case .invalidSize:
            return Violation(code: .doesNotFit, message: "\(name): width and height must be more than 0 mm.", newPart: name)
        case .tooBig:
            let needed = failure.neededMm.map(Format.mm).joined(separator: " × ")
            return Violation(
                code: .doesNotFit,
                message: "\(name): needs \(needed) mm including the 8 mm cutting margin, but \(part.id) is \(dimensions(part)). "
                    + failure.hint,
                newPart: name)
        case .blockedByKeepOuts:
            return Violation(
                code: .hitsKeepOut, message: "\(name): hits the screw holes or damage on \(part.id). " + failure.hint,
                newPart: name)
        case .noRoomLeft:
            return Violation(
                code: .doesNotFit, message: "\(name): not enough room left on \(part.id) after its other cuts. " + failure.hint,
                newPart: name)
        }
    }

    // MARK: - 6: sag

    static func sagResults(_ plan: Plan, parts: [String: Part]) -> (results: [SagResult], violations: [Violation]) {
        var results: [SagResult] = []
        var violations: [Violation] = []
        for newPart in plan.newParts {
            guard let part = parts[newPart.sourcePartID] else { continue }
            do {
                guard let result = try Sag.check(newPart, source: part) else { continue }
                results.append(result)
                if !result.passes {
                    let load = Format.mm(Sag.designLoadKg(for: newPart.role) ?? 0)
                    violations.append(Violation(
                        code: .sags,
                        message: "\(newPart.name): bends \(Format.mm(result.deflectionMm)) mm under \(load) kg; "
                            + "at most \(Format.mm(result.limitMm)) mm is allowed. "
                            + "Use a shorter span, a deeper part or a stiffer part.",
                        newPart: newPart.name))
                }
            } catch {
                let message = (error as? SagError)?.message ?? "\(error)"
                violations.append(Violation(code: .sags, message: "\(newPart.name): can't check sag: \(message).",
                                            newPart: newPart.name))
            }
        }
        return (results, violations)
    }

    // MARK: - 7: size limits

    static func sizeViolations(_ plan: Plan, limits: SizeLimits?) -> [Violation] {
        guard let limits else { return [] }
        let checks = [
            SizeCheck(limit: limits.maxWidthMm, word: "wide", value: { $0.x }),
            SizeCheck(limit: limits.maxHeightMm, word: "tall", value: { $0.y }),
            SizeCheck(limit: limits.maxDepthMm, word: "deep", value: { $0.z }),
        ]
        let active = checks.filter { $0.limit != nil }
        guard !active.isEmpty else { return [] }
        guard let overall = plan.overallMm else {
            return [Violation(code: .tooLarge, message: "The plan has no overall size, so the size limit can't be checked.",
                              newPart: "overall")]
        }
        return active.compactMap { check in
            guard let limit = check.limit, check.value(overall) > limit else { return nil }
            return Violation(
                code: .tooLarge,
                message: "The build is \(Format.mm(check.value(overall))) mm \(check.word); the limit is \(Format.mm(limit)) mm.",
                newPart: "overall")
        }
    }

    // MARK: - Summary numbers

    /// Area of all new parts ÷ area of all inventory parts × 100, rounded to 0.1 and capped at 100.
    static func reusePercent(_ plan: Plan, inventory: Inventory) -> Double {
        func area(_ width: Double, _ height: Double) -> Double {
            let value = width * height
            return value.isFinite && value > 0 ? value : 0
        }
        let used = plan.newParts.reduce(0) { $0 + area($1.widthMm, $1.heightMm) }
        let total = inventory.parts.reduce(0) { $0 + area($1.widthMm, $1.heightMm) }
        guard total > 0 else { return 0 }
        return min(100, (used / total * 1000).rounded() / 10)
    }

    /// The smallest spare margins: the measurements the plan depends on most.
    /// Ties go by source ID, then width before height.
    static func verifyItems(_ packs: [PackResult]) -> [VerifyItem] {
        packs.filter { !$0.placements.isEmpty }
            .flatMap { pack in [
                VerifyItem(dimension: .width, marginMm: pack.spareWidthMm, sourcePartID: pack.sourcePartID),
                VerifyItem(dimension: .height, marginMm: pack.spareHeightMm, sourcePartID: pack.sourcePartID),
            ] }
            .sorted { lhs, rhs in
                if lhs.marginMm != rhs.marginMm { return lhs.marginMm < rhs.marginMm }
                if lhs.sourcePartID != rhs.sourcePartID { return lhs.sourcePartID < rhs.sourcePartID }
                return lhs.dimension == .width && rhs.dimension == .height
            }
            .prefix(verifyCount)
            .map { $0 }
    }

    static func dimensions(_ part: Part) -> String {
        "\(Format.mm(part.widthMm)) × \(Format.mm(part.heightMm)) mm"
    }
}

/// One size limit to compare with the build's overall size (x = width, y = height, z = depth).
struct SizeCheck {
    var limit: Double?
    var word: String
    var value: (Vector3) -> Double
}
