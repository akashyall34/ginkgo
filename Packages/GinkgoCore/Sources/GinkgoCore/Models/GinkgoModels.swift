// This file was generated from JSON Schema using quicktype, do not modify it directly.
// To parse the JSON, add this file to your project and do:
//
//   let measurement = try Measurement(json)
//   let scan = try Scan(json)
//   let rect = try Rect(json)
//   let part = try Part(json)
//   let inventory = try Inventory(json)
//   let vector3 = try Vector3(json)
//   let newPart = try NewPart(json)
//   let hardwareItem = try HardwareItem(json)
//   let plan = try Plan(json)
//   let violation = try Violation(json)
//   let placement = try Placement(json)
//   let sagResult = try SagResult(json)
//   let verifyItem = try VerifyItem(json)
//   let validationResult = try ValidationResult(json)
//   let sizeLimits = try SizeLimits(json)
//   let draftPart = try DraftPart(json)
//   let planDraft = try PlanDraft(json)
//   let detectedPart = try DetectedPart(json)
//   let partsReading = try PartsReading(json)
//   let partFlag = try PartFlag(json)
//   let agentStep = try AgentStep(json)

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of JSONAny, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

import Foundation

/// One measured piece of furniture.
// MARK: - Scan
public struct Scan: Codable, Equatable, Sendable {
    public let depth: Measurement
    public let height: Measurement
    public let id: String
    public let method: Method
    public let width: Measurement

    public enum CodingKeys: String, CodingKey {
        case depth = "depth"
        case height = "height"
        case id = "id"
        case method = "method"
        case width = "width"
    }

    public init(depth: Measurement, height: Measurement, id: String, method: Method, width: Measurement) {
        self.depth = depth
        self.height = height
        self.id = id
        self.method = method
        self.width = width
    }
}

// MARK: Scan convenience initializers and mutators

public extension Scan {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(Scan.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        depth: Measurement? = nil,
        height: Measurement? = nil,
        id: String? = nil,
        method: Method? = nil,
        width: Measurement? = nil
    ) -> Scan {
        return Scan(
            depth: depth ?? self.depth,
            height: height ?? self.height,
            id: id ?? self.id,
            method: method ?? self.method,
            width: width ?? self.width
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of JSONAny, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

/// A measured length with its ± error.
// MARK: - Measurement
public struct Measurement: Codable, Equatable, Sendable {
    public let plusMinusMm: Double
    public let valueMm: Double

    public enum CodingKeys: String, CodingKey {
        case plusMinusMm = "plus_minus_mm"
        case valueMm = "value_mm"
    }

    public init(plusMinusMm: Double, valueMm: Double) {
        self.plusMinusMm = plusMinusMm
        self.valueMm = valueMm
    }
}

// MARK: Measurement convenience initializers and mutators

public extension Measurement {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(Measurement.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        plusMinusMm: Double? = nil,
        valueMm: Double? = nil
    ) -> Measurement {
        return Measurement(
            plusMinusMm: plusMinusMm ?? self.plusMinusMm,
            valueMm: valueMm ?? self.valueMm
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

public enum Method: String, Codable, Equatable, Sendable {
    case lidar = "lidar"
    case marker = "marker"
    case typed = "typed"
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of JSONAny, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

/// The confirmed parts. From here on this is the source of truth, not the model.
// MARK: - Inventory
public struct Inventory: Codable, Equatable, Sendable {
    public let parts: [Part]
    public let scanID: String

    public enum CodingKeys: String, CodingKey {
        case parts = "parts"
        case scanID = "scan_id"
    }

    public init(parts: [Part], scanID: String) {
        self.parts = parts
        self.scanID = scanID
    }
}

// MARK: Inventory convenience initializers and mutators

public extension Inventory {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(Inventory.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        parts: [Part]? = nil,
        scanID: String? = nil
    ) -> Inventory {
        return Inventory(
            parts: parts ?? self.parts,
            scanID: scanID ?? self.scanID
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of JSONAny, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

/// One salvaged part of the original piece, as confirmed by the user.
// MARK: - Part
public struct Part: Codable, Equatable, Sendable {
    public let damaged: Bool
    /// Which way a solid-wood panel's grain (its wood lines) runs. Missing means unknown: rated
    /// as across the grain.
    public let grain: Grain?
    public let heightMm: Double
    public let id: String
    /// Screw holes and damage that no cut may include.
    public let keepOuts: [Rect]
    public let material: Material
    /// Whether the person confirmed the material. Missing means guessed: a guessed wood product
    /// is rated as the weakest one.
    public let materialSource: MaterialSource?
    public let thicknessMm: Double
    /// How the thickness was found. Missing means estimated: only a scanned or tape thickness
    /// can verify a load-bearing part.
    public let thicknessSource: ThicknessSource?
    public let type: TypeEnum
    public let widthMm: Double

    public enum CodingKeys: String, CodingKey {
        case damaged = "damaged"
        case grain = "grain"
        case heightMm = "height_mm"
        case id = "id"
        case keepOuts = "keep_outs"
        case material = "material"
        case materialSource = "material_source"
        case thicknessMm = "thickness_mm"
        case thicknessSource = "thickness_source"
        case type = "type"
        case widthMm = "width_mm"
    }

    public init(damaged: Bool, grain: Grain?, heightMm: Double, id: String, keepOuts: [Rect], material: Material, materialSource: MaterialSource?, thicknessMm: Double, thicknessSource: ThicknessSource?, type: TypeEnum, widthMm: Double) {
        self.damaged = damaged
        self.grain = grain
        self.heightMm = heightMm
        self.id = id
        self.keepOuts = keepOuts
        self.material = material
        self.materialSource = materialSource
        self.thicknessMm = thicknessMm
        self.thicknessSource = thicknessSource
        self.type = type
        self.widthMm = widthMm
    }
}

// MARK: Part convenience initializers and mutators

public extension Part {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(Part.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        damaged: Bool? = nil,
        grain: Grain?? = nil,
        heightMm: Double? = nil,
        id: String? = nil,
        keepOuts: [Rect]? = nil,
        material: Material? = nil,
        materialSource: MaterialSource?? = nil,
        thicknessMm: Double? = nil,
        thicknessSource: ThicknessSource?? = nil,
        type: TypeEnum? = nil,
        widthMm: Double? = nil
    ) -> Part {
        return Part(
            damaged: damaged ?? self.damaged,
            grain: grain ?? self.grain,
            heightMm: heightMm ?? self.heightMm,
            id: id ?? self.id,
            keepOuts: keepOuts ?? self.keepOuts,
            material: material ?? self.material,
            materialSource: materialSource ?? self.materialSource,
            thicknessMm: thicknessMm ?? self.thicknessMm,
            thicknessSource: thicknessSource ?? self.thicknessSource,
            type: type ?? self.type,
            widthMm: widthMm ?? self.widthMm
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

/// Which way a solid-wood panel's grain (its wood lines) runs. Missing means unknown: rated
/// as across the grain.
public enum Grain: String, Codable, Equatable, Sendable {
    case alongHeight = "along_height"
    case alongWidth = "along_width"
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of JSONAny, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

/// A rectangle on a part's face, from the part's bottom-left corner.
// MARK: - Rect
public struct Rect: Codable, Equatable, Sendable {
    public let heightMm: Double
    public let widthMm: Double
    public let xMm: Double
    public let yMm: Double

    public enum CodingKeys: String, CodingKey {
        case heightMm = "height_mm"
        case widthMm = "width_mm"
        case xMm = "x_mm"
        case yMm = "y_mm"
    }

    public init(heightMm: Double, widthMm: Double, xMm: Double, yMm: Double) {
        self.heightMm = heightMm
        self.widthMm = widthMm
        self.xMm = xMm
        self.yMm = yMm
    }
}

// MARK: Rect convenience initializers and mutators

public extension Rect {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(Rect.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        heightMm: Double? = nil,
        widthMm: Double? = nil,
        xMm: Double? = nil,
        yMm: Double? = nil
    ) -> Rect {
        return Rect(
            heightMm: heightMm ?? self.heightMm,
            widthMm: widthMm ?? self.widthMm,
            xMm: xMm ?? self.xMm,
            yMm: yMm ?? self.yMm
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

/// Gemini's guess from the photo; the user confirms it.
public enum Material: String, Codable, Equatable, Sendable {
    case cardboard = "cardboard"
    case particleboardMDF = "particleboard_mdf"
    case plastic = "plastic"
    case plywood = "plywood"
    case solidWood = "solid_wood"
}

/// Whether the person confirmed the material. Missing means guessed: a guessed wood product
/// is rated as the weakest one.
public enum MaterialSource: String, Codable, Equatable, Sendable {
    case confirmed = "confirmed"
    case guessed = "guessed"
}

/// How the thickness was found. Missing means estimated: only a scanned or tape thickness
/// can verify a load-bearing part.
public enum ThicknessSource: String, Codable, Equatable, Sendable {
    case estimated = "estimated"
    case scanned = "scanned"
    case tape = "tape"
}

public enum TypeEnum: String, Codable, Equatable, Sendable {
    case back = "back"
    case drawerBox = "drawer_box"
    case drawerFront = "drawer_front"
    case leg = "leg"
    case rail = "rail"
    case shelf = "shelf"
    case side = "side"
    case top = "top"
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of JSONAny, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

/// A proposed build, from Ginkgo's planner or the chatbot baseline.
// MARK: - Plan
public struct Plan: Codable, Equatable, Sendable {
    public let hardware: [HardwareItem]
    public let id: String
    public let newParts: [NewPart]
    /// Overall size of the assembled build, computed by code (Layout).
    public let overallMm: Vector3?
    public let scanID: String
    public let source: Source
    public let steps: [String]
    public let template: Template

    public enum CodingKeys: String, CodingKey {
        case hardware = "hardware"
        case id = "id"
        case newParts = "new_parts"
        case overallMm = "overall_mm"
        case scanID = "scan_id"
        case source = "source"
        case steps = "steps"
        case template = "template"
    }

    public init(hardware: [HardwareItem], id: String, newParts: [NewPart], overallMm: Vector3?, scanID: String, source: Source, steps: [String], template: Template) {
        self.hardware = hardware
        self.id = id
        self.newParts = newParts
        self.overallMm = overallMm
        self.scanID = scanID
        self.source = source
        self.steps = steps
        self.template = template
    }
}

// MARK: Plan convenience initializers and mutators

public extension Plan {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(Plan.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        hardware: [HardwareItem]? = nil,
        id: String? = nil,
        newParts: [NewPart]? = nil,
        overallMm: Vector3?? = nil,
        scanID: String? = nil,
        source: Source? = nil,
        steps: [String]? = nil,
        template: Template? = nil
    ) -> Plan {
        return Plan(
            hardware: hardware ?? self.hardware,
            id: id ?? self.id,
            newParts: newParts ?? self.newParts,
            overallMm: overallMm ?? self.overallMm,
            scanID: scanID ?? self.scanID,
            source: source ?? self.source,
            steps: steps ?? self.steps,
            template: template ?? self.template
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of JSONAny, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - HardwareItem
public struct HardwareItem: Codable, Equatable, Sendable {
    public let item: String
    public let quantity: Int

    public enum CodingKeys: String, CodingKey {
        case item = "item"
        case quantity = "quantity"
    }

    public init(item: String, quantity: Int) {
        self.item = item
        self.quantity = quantity
    }
}

// MARK: HardwareItem convenience initializers and mutators

public extension HardwareItem {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(HardwareItem.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        item: String? = nil,
        quantity: Int? = nil
    ) -> HardwareItem {
        return HardwareItem(
            item: item ?? self.item,
            quantity: quantity ?? self.quantity
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of JSONAny, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

/// A piece of the new build, cut from one source part.
// MARK: - NewPart
public struct NewPart: Codable, Equatable, Sendable {
    public let heightMm: Double
    public let name: String
    public let positionMm: Vector3
    /// Shelves and seats carry load and get the sag check.
    public let role: Role
    public let rotationDeg: Vector3
    public let sourcePartID: String
    /// Unsupported span for shelves and seats.
    public let spanMm: Double?
    public let widthMm: Double

    public enum CodingKeys: String, CodingKey {
        case heightMm = "height_mm"
        case name = "name"
        case positionMm = "position_mm"
        case role = "role"
        case rotationDeg = "rotation_deg"
        case sourcePartID = "source_part_id"
        case spanMm = "span_mm"
        case widthMm = "width_mm"
    }

    public init(heightMm: Double, name: String, positionMm: Vector3, role: Role, rotationDeg: Vector3, sourcePartID: String, spanMm: Double?, widthMm: Double) {
        self.heightMm = heightMm
        self.name = name
        self.positionMm = positionMm
        self.role = role
        self.rotationDeg = rotationDeg
        self.sourcePartID = sourcePartID
        self.spanMm = spanMm
        self.widthMm = widthMm
    }
}

// MARK: NewPart convenience initializers and mutators

public extension NewPart {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(NewPart.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        heightMm: Double? = nil,
        name: String? = nil,
        positionMm: Vector3? = nil,
        role: Role? = nil,
        rotationDeg: Vector3? = nil,
        sourcePartID: String? = nil,
        spanMm: Double?? = nil,
        widthMm: Double? = nil
    ) -> NewPart {
        return NewPart(
            heightMm: heightMm ?? self.heightMm,
            name: name ?? self.name,
            positionMm: positionMm ?? self.positionMm,
            role: role ?? self.role,
            rotationDeg: rotationDeg ?? self.rotationDeg,
            sourcePartID: sourcePartID ?? self.sourcePartID,
            spanMm: spanMm ?? self.spanMm,
            widthMm: widthMm ?? self.widthMm
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of JSONAny, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

/// Overall size of the assembled build, computed by code (Layout).
// MARK: - Vector3
public struct Vector3: Codable, Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let z: Double

    public enum CodingKeys: String, CodingKey {
        case x = "x"
        case y = "y"
        case z = "z"
    }

    public init(x: Double, y: Double, z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }
}

// MARK: Vector3 convenience initializers and mutators

public extension Vector3 {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(Vector3.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        x: Double? = nil,
        y: Double? = nil,
        z: Double? = nil
    ) -> Vector3 {
        return Vector3(
            x: x ?? self.x,
            y: y ?? self.y,
            z: z ?? self.z
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

/// Shelves and seats carry load and get the sag check.
public enum Role: String, Codable, Equatable, Sendable {
    case back = "back"
    case other = "other"
    case seat = "seat"
    case shelf = "shelf"
    case side = "side"
    case support = "support"
}

public enum Source: String, Codable, Equatable, Sendable {
    case chatbot = "chatbot"
    case ginkgo = "ginkgo"
}

public enum Template: String, Codable, Equatable, Sendable {
    case bench = "bench"
    case bookshelf = "bookshelf"
    case noCut = "no_cut"
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of JSONAny, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - ValidationResult
public struct ValidationResult: Codable, Equatable, Sendable {
    public let passes: Bool
    public let placements: [Placement]
    public let planID: String
    public let reusePercent: Double
    public let sag: [SagResult]
    public let verify: [VerifyItem]
    public let violations: [Violation]

    public enum CodingKeys: String, CodingKey {
        case passes = "passes"
        case placements = "placements"
        case planID = "plan_id"
        case reusePercent = "reuse_percent"
        case sag = "sag"
        case verify = "verify"
        case violations = "violations"
    }

    public init(passes: Bool, placements: [Placement], planID: String, reusePercent: Double, sag: [SagResult], verify: [VerifyItem], violations: [Violation]) {
        self.passes = passes
        self.placements = placements
        self.planID = planID
        self.reusePercent = reusePercent
        self.sag = sag
        self.verify = verify
        self.violations = violations
    }
}

// MARK: ValidationResult convenience initializers and mutators

public extension ValidationResult {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(ValidationResult.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        passes: Bool? = nil,
        placements: [Placement]? = nil,
        planID: String? = nil,
        reusePercent: Double? = nil,
        sag: [SagResult]? = nil,
        verify: [VerifyItem]? = nil,
        violations: [Violation]? = nil
    ) -> ValidationResult {
        return ValidationResult(
            passes: passes ?? self.passes,
            placements: placements ?? self.placements,
            planID: planID ?? self.planID,
            reusePercent: reusePercent ?? self.reusePercent,
            sag: sag ?? self.sag,
            verify: verify ?? self.verify,
            violations: violations ?? self.violations
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of JSONAny, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

/// Where a new part is cut from its source part: the cutting diagram.
// MARK: - Placement
public struct Placement: Codable, Equatable, Sendable {
    public let heightMm: Double
    public let newPart: String
    public let rotated: Bool
    public let sourcePartID: String
    public let widthMm: Double
    public let xMm: Double
    public let yMm: Double

    public enum CodingKeys: String, CodingKey {
        case heightMm = "height_mm"
        case newPart = "new_part"
        case rotated = "rotated"
        case sourcePartID = "source_part_id"
        case widthMm = "width_mm"
        case xMm = "x_mm"
        case yMm = "y_mm"
    }

    public init(heightMm: Double, newPart: String, rotated: Bool, sourcePartID: String, widthMm: Double, xMm: Double, yMm: Double) {
        self.heightMm = heightMm
        self.newPart = newPart
        self.rotated = rotated
        self.sourcePartID = sourcePartID
        self.widthMm = widthMm
        self.xMm = xMm
        self.yMm = yMm
    }
}

// MARK: Placement convenience initializers and mutators

public extension Placement {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(Placement.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        heightMm: Double? = nil,
        newPart: String? = nil,
        rotated: Bool? = nil,
        sourcePartID: String? = nil,
        widthMm: Double? = nil,
        xMm: Double? = nil,
        yMm: Double? = nil
    ) -> Placement {
        return Placement(
            heightMm: heightMm ?? self.heightMm,
            newPart: newPart ?? self.newPart,
            rotated: rotated ?? self.rotated,
            sourcePartID: sourcePartID ?? self.sourcePartID,
            widthMm: widthMm ?? self.widthMm,
            xMm: xMm ?? self.xMm,
            yMm: yMm ?? self.yMm
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of JSONAny, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - SagResult
public struct SagResult: Codable, Equatable, Sendable {
    public let deflectionMm: Double
    public let limitMm: Double
    public let newPart: String
    public let passes: Bool
    public let spanMm: Double

    public enum CodingKeys: String, CodingKey {
        case deflectionMm = "deflection_mm"
        case limitMm = "limit_mm"
        case newPart = "new_part"
        case passes = "passes"
        case spanMm = "span_mm"
    }

    public init(deflectionMm: Double, limitMm: Double, newPart: String, passes: Bool, spanMm: Double) {
        self.deflectionMm = deflectionMm
        self.limitMm = limitMm
        self.newPart = newPart
        self.passes = passes
        self.spanMm = spanMm
    }
}

// MARK: SagResult convenience initializers and mutators

public extension SagResult {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(SagResult.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        deflectionMm: Double? = nil,
        limitMm: Double? = nil,
        newPart: String? = nil,
        passes: Bool? = nil,
        spanMm: Double? = nil
    ) -> SagResult {
        return SagResult(
            deflectionMm: deflectionMm ?? self.deflectionMm,
            limitMm: limitMm ?? self.limitMm,
            newPart: newPart ?? self.newPart,
            passes: passes ?? self.passes,
            spanMm: spanMm ?? self.spanMm
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of JSONAny, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

/// A measurement the plan depends on most: the smallest safety margins.
// MARK: - VerifyItem
public struct VerifyItem: Codable, Equatable, Sendable {
    public let dimension: Dimension
    public let marginMm: Double
    public let sourcePartID: String

    public enum CodingKeys: String, CodingKey {
        case dimension = "dimension"
        case marginMm = "margin_mm"
        case sourcePartID = "source_part_id"
    }

    public init(dimension: Dimension, marginMm: Double, sourcePartID: String) {
        self.dimension = dimension
        self.marginMm = marginMm
        self.sourcePartID = sourcePartID
    }
}

// MARK: VerifyItem convenience initializers and mutators

public extension VerifyItem {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(VerifyItem.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        dimension: Dimension? = nil,
        marginMm: Double? = nil,
        sourcePartID: String? = nil
    ) -> VerifyItem {
        return VerifyItem(
            dimension: dimension ?? self.dimension,
            marginMm: marginMm ?? self.marginMm,
            sourcePartID: sourcePartID ?? self.sourcePartID
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

public enum Dimension: String, Codable, Equatable, Sendable {
    case height = "height"
    case thickness = "thickness"
    case width = "width"
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of JSONAny, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - Violation
public struct Violation: Codable, Equatable, Sendable {
    public let code: Code
    public let message: String
    public let newPart: String

    public enum CodingKeys: String, CodingKey {
        case code = "code"
        case message = "message"
        case newPart = "new_part"
    }

    public init(code: Code, message: String, newPart: String) {
        self.code = code
        self.message = message
        self.newPart = newPart
    }
}

// MARK: Violation convenience initializers and mutators

public extension Violation {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(Violation.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        code: Code? = nil,
        message: String? = nil,
        newPart: String? = nil
    ) -> Violation {
        return Violation(
            code: code ?? self.code,
            message: message ?? self.message,
            newPart: newPart ?? self.newPart
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

public enum Code: String, Codable, Equatable, Sendable {
    case cutNotAllowed = "cut_not_allowed"
    case damagedPartUsed = "damaged_part_used"
    case doesNotFit = "does_not_fit"
    case emptyPlan = "empty_plan"
    case hitsKeepOut = "hits_keep_out"
    case partUsedTwice = "part_used_twice"
    case sags = "sags"
    case tooLarge = "too_large"
    case unknownPart = "unknown_part"
    case unstable = "unstable"
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of JSONAny, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

/// The user's maximum size for the new build. Every limit is optional.
// MARK: - SizeLimits
public struct SizeLimits: Codable, Equatable, Sendable {
    public let maxDepthMm: Double?
    public let maxHeightMm: Double?
    public let maxWidthMm: Double?

    public enum CodingKeys: String, CodingKey {
        case maxDepthMm = "max_depth_mm"
        case maxHeightMm = "max_height_mm"
        case maxWidthMm = "max_width_mm"
    }

    public init(maxDepthMm: Double?, maxHeightMm: Double?, maxWidthMm: Double?) {
        self.maxDepthMm = maxDepthMm
        self.maxHeightMm = maxHeightMm
        self.maxWidthMm = maxWidthMm
    }
}

// MARK: SizeLimits convenience initializers and mutators

public extension SizeLimits {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(SizeLimits.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        maxDepthMm: Double?? = nil,
        maxHeightMm: Double?? = nil,
        maxWidthMm: Double?? = nil
    ) -> SizeLimits {
        return SizeLimits(
            maxDepthMm: maxDepthMm ?? self.maxDepthMm,
            maxHeightMm: maxHeightMm ?? self.maxHeightMm,
            maxWidthMm: maxWidthMm ?? self.maxWidthMm
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of JSONAny, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

/// The plan the AI submits. Code lays it out and validates it before anyone sees it.
// MARK: - PlanDraft
public struct PlanDraft: Codable, Equatable, Sendable {
    public let hardware: [HardwareItem]
    public let newParts: [DraftPart]
    public let steps: [String]
    public let template: Template

    public enum CodingKeys: String, CodingKey {
        case hardware = "hardware"
        case newParts = "new_parts"
        case steps = "steps"
        case template = "template"
    }

    public init(hardware: [HardwareItem], newParts: [DraftPart], steps: [String], template: Template) {
        self.hardware = hardware
        self.newParts = newParts
        self.steps = steps
        self.template = template
    }
}

// MARK: PlanDraft convenience initializers and mutators

public extension PlanDraft {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(PlanDraft.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        hardware: [HardwareItem]? = nil,
        newParts: [DraftPart]? = nil,
        steps: [String]? = nil,
        template: Template? = nil
    ) -> PlanDraft {
        return PlanDraft(
            hardware: hardware ?? self.hardware,
            newParts: newParts ?? self.newParts,
            steps: steps ?? self.steps,
            template: template ?? self.template
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of JSONAny, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

/// A new part as the AI proposes it. Code adds the position and rotation (Layout).
// MARK: - DraftPart
public struct DraftPart: Codable, Equatable, Sendable {
    public let heightMm: Double
    public let name: String
    /// Shelves and seats carry load and get the sag check.
    public let role: Role
    public let sourcePartID: String
    /// Unsupported span for shelves and seats.
    public let spanMm: Double?
    public let widthMm: Double

    public enum CodingKeys: String, CodingKey {
        case heightMm = "height_mm"
        case name = "name"
        case role = "role"
        case sourcePartID = "source_part_id"
        case spanMm = "span_mm"
        case widthMm = "width_mm"
    }

    public init(heightMm: Double, name: String, role: Role, sourcePartID: String, spanMm: Double?, widthMm: Double) {
        self.heightMm = heightMm
        self.name = name
        self.role = role
        self.sourcePartID = sourcePartID
        self.spanMm = spanMm
        self.widthMm = widthMm
    }
}

// MARK: DraftPart convenience initializers and mutators

public extension DraftPart {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(DraftPart.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        heightMm: Double? = nil,
        name: String? = nil,
        role: Role? = nil,
        sourcePartID: String? = nil,
        spanMm: Double?? = nil,
        widthMm: Double? = nil
    ) -> DraftPart {
        return DraftPart(
            heightMm: heightMm ?? self.heightMm,
            name: name ?? self.name,
            role: role ?? self.role,
            sourcePartID: sourcePartID ?? self.sourcePartID,
            spanMm: spanMm ?? self.spanMm,
            widthMm: widthMm ?? self.widthMm
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of JSONAny, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

/// What Gemini read from one photo of the furniture.
// MARK: - PartsReading
public struct PartsReading: Codable, Equatable, Sendable {
    /// [ymin, xmin, ymax, xmax] of the whole piece on the 0-1000 image scale.
    public let furnitureBox2D: [Double]
    public let parts: [DetectedPart]

    public enum CodingKeys: String, CodingKey {
        case furnitureBox2D = "furniture_box_2d"
        case parts = "parts"
    }

    public init(furnitureBox2D: [Double], parts: [DetectedPart]) {
        self.furnitureBox2D = furnitureBox2D
        self.parts = parts
    }
}

// MARK: PartsReading convenience initializers and mutators

public extension PartsReading {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(PartsReading.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        furnitureBox2D: [Double]? = nil,
        parts: [DetectedPart]? = nil
    ) -> PartsReading {
        return PartsReading(
            furnitureBox2D: furnitureBox2D ?? self.furnitureBox2D,
            parts: parts ?? self.parts
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of JSONAny, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

/// One part Gemini found in the photo. Code turns its box into millimetres; Gemini's own
/// size guess is only a cross-check.
// MARK: - DetectedPart
public struct DetectedPart: Codable, Equatable, Sendable {
    /// [ymin, xmin, ymax, xmax] on Gemini's 0-1000 image scale. Missing when the part is hidden
    /// in the photo.
    public let box2D: [Double]?
    /// Not a flat, straight board, like a curved leg.
    public let curved: Bool?
    public let damaged: Bool
    public let estimatedHeightMm: Double
    public let estimatedWidthMm: Double
    /// Gemini's guess from the photo; the user confirms it.
    public let material: Material?
    public let note: String?
    public let type: TypeEnum
    /// Covered in fabric or foam, like a padded seat.
    public let upholstered: Bool?

    public enum CodingKeys: String, CodingKey {
        case box2D = "box_2d"
        case curved = "curved"
        case damaged = "damaged"
        case estimatedHeightMm = "estimated_height_mm"
        case estimatedWidthMm = "estimated_width_mm"
        case material = "material"
        case note = "note"
        case type = "type"
        case upholstered = "upholstered"
    }

    public init(box2D: [Double]?, curved: Bool?, damaged: Bool, estimatedHeightMm: Double, estimatedWidthMm: Double, material: Material?, note: String?, type: TypeEnum, upholstered: Bool?) {
        self.box2D = box2D
        self.curved = curved
        self.damaged = damaged
        self.estimatedHeightMm = estimatedHeightMm
        self.estimatedWidthMm = estimatedWidthMm
        self.material = material
        self.note = note
        self.type = type
        self.upholstered = upholstered
    }
}

// MARK: DetectedPart convenience initializers and mutators

public extension DetectedPart {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(DetectedPart.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        box2D: [Double]?? = nil,
        curved: Bool?? = nil,
        damaged: Bool? = nil,
        estimatedHeightMm: Double? = nil,
        estimatedWidthMm: Double? = nil,
        material: Material?? = nil,
        note: String?? = nil,
        type: TypeEnum? = nil,
        upholstered: Bool?? = nil
    ) -> DetectedPart {
        return DetectedPart(
            box2D: box2D ?? self.box2D,
            curved: curved ?? self.curved,
            damaged: damaged ?? self.damaged,
            estimatedHeightMm: estimatedHeightMm ?? self.estimatedHeightMm,
            estimatedWidthMm: estimatedWidthMm ?? self.estimatedWidthMm,
            material: material ?? self.material,
            note: note ?? self.note,
            type: type ?? self.type,
            upholstered: upholstered ?? self.upholstered
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of JSONAny, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

/// Something the user should check on the Confirm screen before the parts are trusted.
// MARK: - PartFlag
public struct PartFlag: Codable, Equatable, Sendable {
    public let message: String
    public let partID: String

    public enum CodingKeys: String, CodingKey {
        case message = "message"
        case partID = "part_id"
    }

    public init(message: String, partID: String) {
        self.message = message
        self.partID = partID
    }
}

// MARK: PartFlag convenience initializers and mutators

public extension PartFlag {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(PartFlag.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        message: String? = nil,
        partID: String? = nil
    ) -> PartFlag {
        return PartFlag(
            message: message ?? self.message,
            partID: partID ?? self.partID
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of JSONAny, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

/// One row of the on-screen agent trace.
// MARK: - AgentStep
public struct AgentStep: Codable, Equatable, Sendable {
    public let index: Int
    /// The AI's own words: why it made this call.
    public let reason: String
    public let status: Status
    /// Written by our code, for example "seat from top: fits, 52 mm to spare".
    public let summary: String
    public let tool: Tool

    public enum CodingKeys: String, CodingKey {
        case index = "index"
        case reason = "reason"
        case status = "status"
        case summary = "summary"
        case tool = "tool"
    }

    public init(index: Int, reason: String, status: Status, summary: String, tool: Tool) {
        self.index = index
        self.reason = reason
        self.status = status
        self.summary = summary
        self.tool = tool
    }
}

// MARK: AgentStep convenience initializers and mutators

public extension AgentStep {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(AgentStep.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        index: Int? = nil,
        reason: String? = nil,
        status: Status? = nil,
        summary: String? = nil,
        tool: Tool? = nil
    ) -> AgentStep {
        return AgentStep(
            index: index ?? self.index,
            reason: reason ?? self.reason,
            status: status ?? self.status,
            summary: summary ?? self.summary,
            tool: tool ?? self.tool
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

public enum Status: String, Codable, Equatable, Sendable {
    case accepted = "accepted"
    case error = "error"
    case fail = "fail"
    case info = "info"
    case pass = "pass"
}

public enum Tool: String, Codable, Equatable, Sendable {
    case checkFit = "check_fit"
    case checkSag = "check_sag"
    case fallback = "fallback"
    case note = "note"
    case submitPlan = "submit_plan"
}

// MARK: - Helper functions for creating encoders and decoders

func newJSONDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    if #available(iOS 10.0, OSX 10.12, tvOS 10.0, watchOS 3.0, *) {
        decoder.dateDecodingStrategy = .iso8601
    }
    return decoder
}

func newJSONEncoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    if #available(iOS 10.0, OSX 10.12, tvOS 10.0, watchOS 3.0, *) {
        encoder.dateEncodingStrategy = .iso8601
    }
    return encoder
}
