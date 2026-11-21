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

import Foundation

/// One measured piece of furniture.
// MARK: - Scan
struct Scan: Codable {
    let depth: Measurement
    let height: Measurement
    let id: String
    let method: Method
    let width: Measurement

    enum CodingKeys: String, CodingKey {
        case depth = "depth"
        case height = "height"
        case id = "id"
        case method = "method"
        case width = "width"
    }
}

// MARK: Scan convenience initializers and mutators

extension Scan {
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

/// A measured length with its ± error.
// MARK: - Measurement
struct Measurement: Codable {
    let plusMinusMm: Double
    let valueMm: Double

    enum CodingKeys: String, CodingKey {
        case plusMinusMm = "plus_minus_mm"
        case valueMm = "value_mm"
    }
}

// MARK: Measurement convenience initializers and mutators

extension Measurement {
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

enum Method: String, Codable {
    case lidar = "lidar"
    case marker = "marker"
    case typed = "typed"
}

/// The confirmed parts. From here on this is the source of truth, not the model.
// MARK: - Inventory
struct Inventory: Codable {
    let parts: [Part]
    let scanID: String

    enum CodingKeys: String, CodingKey {
        case parts = "parts"
        case scanID = "scan_id"
    }
}

// MARK: Inventory convenience initializers and mutators

extension Inventory {
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

/// One salvaged part of the original piece, as confirmed by the user.
// MARK: - Part
struct Part: Codable {
    let damaged: Bool
    let heightMm: Double
    let id: String
    /// Screw holes and damage that no cut may include.
    let keepOuts: [Rect]
    let material: Material
    let thicknessMm: Double
    let type: TypeEnum
    let widthMm: Double

    enum CodingKeys: String, CodingKey {
        case damaged = "damaged"
        case heightMm = "height_mm"
        case id = "id"
        case keepOuts = "keep_outs"
        case material = "material"
        case thicknessMm = "thickness_mm"
        case type = "type"
        case widthMm = "width_mm"
    }
}

// MARK: Part convenience initializers and mutators

extension Part {
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
        heightMm: Double? = nil,
        id: String? = nil,
        keepOuts: [Rect]? = nil,
        material: Material? = nil,
        thicknessMm: Double? = nil,
        type: TypeEnum? = nil,
        widthMm: Double? = nil
    ) -> Part {
        return Part(
            damaged: damaged ?? self.damaged,
            heightMm: heightMm ?? self.heightMm,
            id: id ?? self.id,
            keepOuts: keepOuts ?? self.keepOuts,
            material: material ?? self.material,
            thicknessMm: thicknessMm ?? self.thicknessMm,
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

/// A rectangle on a part's face, from the part's bottom-left corner.
// MARK: - Rect
struct Rect: Codable {
    let heightMm: Double
    let widthMm: Double
    let xMm: Double
    let yMm: Double

    enum CodingKeys: String, CodingKey {
        case heightMm = "height_mm"
        case widthMm = "width_mm"
        case xMm = "x_mm"
        case yMm = "y_mm"
    }
}

// MARK: Rect convenience initializers and mutators

extension Rect {
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

enum Material: String, Codable {
    case particleboardMDF = "particleboard_mdf"
    case plywood = "plywood"
    case solidWood = "solid_wood"
}

enum TypeEnum: String, Codable {
    case back = "back"
    case drawerBox = "drawer_box"
    case drawerFront = "drawer_front"
    case leg = "leg"
    case shelf = "shelf"
    case side = "side"
    case top = "top"
}

/// A proposed build, from Ginkgo's planner or the chatbot baseline.
// MARK: - Plan
struct Plan: Codable {
    let hardware: [HardwareItem]
    let id: String
    let newParts: [NewPart]
    let scanID: String
    let source: Source
    let steps: [String]
    let template: Template

    enum CodingKeys: String, CodingKey {
        case hardware = "hardware"
        case id = "id"
        case newParts = "new_parts"
        case scanID = "scan_id"
        case source = "source"
        case steps = "steps"
        case template = "template"
    }
}

// MARK: Plan convenience initializers and mutators

extension Plan {
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
        scanID: String? = nil,
        source: Source? = nil,
        steps: [String]? = nil,
        template: Template? = nil
    ) -> Plan {
        return Plan(
            hardware: hardware ?? self.hardware,
            id: id ?? self.id,
            newParts: newParts ?? self.newParts,
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

// MARK: - HardwareItem
struct HardwareItem: Codable {
    let item: String
    let quantity: Int

    enum CodingKeys: String, CodingKey {
        case item = "item"
        case quantity = "quantity"
    }
}

// MARK: HardwareItem convenience initializers and mutators

extension HardwareItem {
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

/// A piece of the new build, cut from one source part.
// MARK: - NewPart
struct NewPart: Codable {
    let heightMm: Double
    let name: String
    let positionMm: Vector3
    /// Shelves and seats carry load and get the sag check.
    let role: Role
    let rotationDeg: Vector3
    let sourcePartID: String
    /// Unsupported span for shelves and seats.
    let spanMm: Double?
    let widthMm: Double

    enum CodingKeys: String, CodingKey {
        case heightMm = "height_mm"
        case name = "name"
        case positionMm = "position_mm"
        case role = "role"
        case rotationDeg = "rotation_deg"
        case sourcePartID = "source_part_id"
        case spanMm = "span_mm"
        case widthMm = "width_mm"
    }
}

// MARK: NewPart convenience initializers and mutators

extension NewPart {
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

// MARK: - Vector3
struct Vector3: Codable {
    let x: Double
    let y: Double
    let z: Double

    enum CodingKeys: String, CodingKey {
        case x = "x"
        case y = "y"
        case z = "z"
    }
}

// MARK: Vector3 convenience initializers and mutators

extension Vector3 {
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
enum Role: String, Codable {
    case back = "back"
    case other = "other"
    case seat = "seat"
    case shelf = "shelf"
    case side = "side"
    case support = "support"
}

enum Source: String, Codable {
    case chatbot = "chatbot"
    case ginkgo = "ginkgo"
}

enum Template: String, Codable {
    case bench = "bench"
    case bookshelf = "bookshelf"
    case noCut = "no_cut"
}

// MARK: - ValidationResult
struct ValidationResult: Codable {
    let passes: Bool
    let placements: [Placement]
    let planID: String
    let reusePercent: Double
    let sag: [SagResult]
    let verify: [VerifyItem]
    let violations: [Violation]

    enum CodingKeys: String, CodingKey {
        case passes = "passes"
        case placements = "placements"
        case planID = "plan_id"
        case reusePercent = "reuse_percent"
        case sag = "sag"
        case verify = "verify"
        case violations = "violations"
    }
}

// MARK: ValidationResult convenience initializers and mutators

extension ValidationResult {
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

/// Where a new part is cut from its source part: the cutting diagram.
// MARK: - Placement
struct Placement: Codable {
    let heightMm: Double
    let newPart: String
    let rotated: Bool
    let sourcePartID: String
    let widthMm: Double
    let xMm: Double
    let yMm: Double

    enum CodingKeys: String, CodingKey {
        case heightMm = "height_mm"
        case newPart = "new_part"
        case rotated = "rotated"
        case sourcePartID = "source_part_id"
        case widthMm = "width_mm"
        case xMm = "x_mm"
        case yMm = "y_mm"
    }
}

// MARK: Placement convenience initializers and mutators

extension Placement {
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

// MARK: - SagResult
struct SagResult: Codable {
    let deflectionMm: Double
    let limitMm: Double
    let newPart: String
    let passes: Bool
    let spanMm: Double

    enum CodingKeys: String, CodingKey {
        case deflectionMm = "deflection_mm"
        case limitMm = "limit_mm"
        case newPart = "new_part"
        case passes = "passes"
        case spanMm = "span_mm"
    }
}

// MARK: SagResult convenience initializers and mutators

extension SagResult {
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

/// A measurement the plan depends on most: the smallest safety margins.
// MARK: - VerifyItem
struct VerifyItem: Codable {
    let dimension: Dimension
    let marginMm: Double
    let sourcePartID: String

    enum CodingKeys: String, CodingKey {
        case dimension = "dimension"
        case marginMm = "margin_mm"
        case sourcePartID = "source_part_id"
    }
}

// MARK: VerifyItem convenience initializers and mutators

extension VerifyItem {
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

enum Dimension: String, Codable {
    case height = "height"
    case width = "width"
}

// MARK: - Violation
struct Violation: Codable {
    let code: Code
    let message: String
    let newPart: String

    enum CodingKeys: String, CodingKey {
        case code = "code"
        case message = "message"
        case newPart = "new_part"
    }
}

// MARK: Violation convenience initializers and mutators

extension Violation {
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

enum Code: String, Codable {
    case cutNotAllowed = "cut_not_allowed"
    case damagedPartUsed = "damaged_part_used"
    case doesNotFit = "does_not_fit"
    case hitsKeepOut = "hits_keep_out"
    case partUsedTwice = "part_used_twice"
    case sags = "sags"
    case tooLarge = "too_large"
    case unknownPart = "unknown_part"
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
