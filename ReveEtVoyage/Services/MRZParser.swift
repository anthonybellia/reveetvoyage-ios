import Foundation

/// Minimal MRZ parser supporting passport TD3 (2x44) and ID card TD1 (3x30).
/// Returns the fields most useful for pre-filling a passenger form.
struct MRZParser {

    struct Result {
        var documentType: String?     // "passeport" or "carte_identite"
        var documentNumber: String?
        var surname: String?
        var givenNames: String?
        var nationality: String?      // ISO 3-letter
        var dateOfBirth: Date?
        var sex: String?              // "M" or "F"
        var expirationDate: Date?
        var issuingCountry: String?   // ISO 3-letter
    }

    /// Try to parse arbitrary OCR text. Looks for MRZ blocks (lines of `<` & A-Z0-9).
    static func parse(rawText: String) -> Result? {
        let lines = rawText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces).uppercased().replacingOccurrences(of: " ", with: "") }
            .filter { !$0.isEmpty }

        // Look for MRZ candidate lines: only A-Z, 0-9, and <
        let mrzLines = lines.filter { line in
            let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789<")
            return line.unicodeScalars.allSatisfy { allowed.contains($0) }
                && (line.count == 30 || line.count == 36 || line.count == 44)
                && line.contains("<")
        }

        // Passport TD3 = 2 lines of 44
        if let td3 = mrzLines.firstIndex(where: { $0.count == 44 }),
           td3 + 1 < mrzLines.count,
           mrzLines[td3 + 1].count == 44 {
            return parseTD3(line1: mrzLines[td3], line2: mrzLines[td3 + 1])
        }

        // ID card TD1 = 3 lines of 30
        if let td1 = mrzLines.firstIndex(where: { $0.count == 30 }),
           td1 + 2 < mrzLines.count,
           mrzLines[td1 + 1].count == 30,
           mrzLines[td1 + 2].count == 30 {
            return parseTD1(lines: [mrzLines[td1], mrzLines[td1 + 1], mrzLines[td1 + 2]])
        }

        return nil
    }

    // MARK: - TD3 (Passport)

    private static func parseTD3(line1: String, line2: String) -> Result {
        var r = Result()
        r.documentType = "passeport"
        r.issuingCountry = String(line1.dropFirst(2).prefix(3)).replacingOccurrences(of: "<", with: "")

        let nameField = String(line1.dropFirst(5))
        let parts = nameField.components(separatedBy: "<<")
        if parts.count >= 2 {
            r.surname = parts[0].replacingOccurrences(of: "<", with: " ").trimmingCharacters(in: .whitespaces).capitalized
            r.givenNames = parts[1].replacingOccurrences(of: "<", with: " ").trimmingCharacters(in: .whitespaces).capitalized
        }

        r.documentNumber = String(line2.prefix(9)).replacingOccurrences(of: "<", with: "")
        r.nationality = String(line2.dropFirst(10).prefix(3)).replacingOccurrences(of: "<", with: "")
        r.dateOfBirth = parseMRZDate(String(line2.dropFirst(13).prefix(6)), assumingFuture: false)
        let sex = String(line2.dropFirst(20).prefix(1))
        r.sex = (sex == "M" || sex == "F") ? sex : nil
        r.expirationDate = parseMRZDate(String(line2.dropFirst(21).prefix(6)), assumingFuture: true)
        return r
    }

    // MARK: - TD1 (ID Card)

    private static func parseTD1(lines: [String]) -> Result {
        var r = Result()
        r.documentType = "carte_identite"
        r.issuingCountry = String(lines[0].dropFirst(2).prefix(3)).replacingOccurrences(of: "<", with: "")
        r.documentNumber = String(lines[0].dropFirst(5).prefix(9)).replacingOccurrences(of: "<", with: "")

        r.dateOfBirth = parseMRZDate(String(lines[1].prefix(6)), assumingFuture: false)
        let sex = String(lines[1].dropFirst(7).prefix(1))
        r.sex = (sex == "M" || sex == "F") ? sex : nil
        r.expirationDate = parseMRZDate(String(lines[1].dropFirst(8).prefix(6)), assumingFuture: true)
        r.nationality = String(lines[1].dropFirst(15).prefix(3)).replacingOccurrences(of: "<", with: "")

        let nameField = lines[2]
        let parts = nameField.components(separatedBy: "<<")
        if parts.count >= 2 {
            r.surname = parts[0].replacingOccurrences(of: "<", with: " ").trimmingCharacters(in: .whitespaces).capitalized
            r.givenNames = parts[1].replacingOccurrences(of: "<", with: " ").trimmingCharacters(in: .whitespaces).capitalized
        }
        return r
    }

    // YYMMDD with century inferred from `assumingFuture` (expiry vs DoB).
    private static func parseMRZDate(_ s: String, assumingFuture: Bool) -> Date? {
        guard s.count == 6, let _ = Int(s) else { return nil }
        let yy = Int(s.prefix(2))!
        let mm = Int(s.dropFirst(2).prefix(2))!
        let dd = Int(s.suffix(2))!

        let currentYear = Calendar.current.component(.year, from: Date())
        let currentTwo = currentYear % 100
        let century: Int
        if assumingFuture {
            century = (yy >= currentTwo) ? (currentYear - currentTwo) : (currentYear - currentTwo + 100)
        } else {
            century = (yy <= currentTwo) ? (currentYear - currentTwo) : (currentYear - currentTwo - 100)
        }
        var comps = DateComponents()
        comps.year = century + yy
        comps.month = mm
        comps.day = dd
        return Calendar(identifier: .gregorian).date(from: comps)
    }
}
