import Foundation

/// How sure a part's numbers are. A guessed material or an estimated thickness is never trusted for strength:
/// the validator rates guessed wood as the weakest wood product, and a load-bearing panel's thickness must be
/// measured (scanned or by tape) before its plan can be verified.
public extension Part {
    /// The original fields, with the sources left unstated, which means estimated thickness and guessed material.
    init(damaged: Bool, heightMm: Double, id: String, keepOuts: [Rect], material: Material, thicknessMm: Double,
         type: TypeEnum, widthMm: Double) {
        self.init(damaged: damaged, grain: nil, heightMm: heightMm, id: id, keepOuts: keepOuts, material: material,
                  materialSource: nil, thicknessMm: thicknessMm, thicknessSource: nil, type: type, widthMm: widthMm)
    }

    /// With the sources stated, and the grain unknown (rated as across the grain for solid wood).
    init(damaged: Bool, heightMm: Double, id: String, keepOuts: [Rect], material: Material,
         materialSource: MaterialSource?, thicknessMm: Double, thicknessSource: ThicknessSource?, type: TypeEnum,
         widthMm: Double) {
        self.init(damaged: damaged, grain: nil, heightMm: heightMm, id: id, keepOuts: keepOuts, material: material,
                  materialSource: materialSource, thicknessMm: thicknessMm, thicknessSource: thicknessSource, type: type,
                  widthMm: widthMm)
    }

    var thicknessIsMeasured: Bool { thicknessSource == .scanned || thicknessSource == .tape }
    var materialIsConfirmed: Bool { materialSource == .confirmed }

    /// The part as the sag check should see it: a guessed wood product is rated as the weakest one,
    /// particleboard/MDF, until the person confirms what it really is. Plastic and cardboard stay as they are
    /// (never load-bearing either way).
    var ratedForStrength: Part {
        guard !materialIsConfirmed, material == .solidWood || material == .plywood else { return self }
        return with(material: .particleboardMDF)
    }
}
