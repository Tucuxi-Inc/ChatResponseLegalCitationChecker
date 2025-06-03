import Foundation

// MARK: - String Extensions for Citation Processing

extension String {
    
    /// Finds all potential legal citations in the string and returns their ranges
    /// - Returns: An array of NSRange objects representing citation locations
    public func findCitationRanges() -> [NSRange] {
        var ranges: [NSRange] = []
        
        // Federal reporter patterns
        let patterns = [
            #"\d+\s+F\.\s*3d\s+\d+"#,           // F.3d
            #"\d+\s+F\.\s*2d\s+\d+"#,           // F.2d  
            #"\d+\s+F\.\s+\d+"#,                // F.
            #"\d+\s+F\.\s*Supp\.\s*\d*\s+\d+"#, // F. Supp.
            #"\d+\s+U\.S\.\s+\d+"#,             // U.S.
            #"\d+\s+S\.\s*Ct\.\s+\d+"#,         // S. Ct.
            #"\d{4}\s+WL\s+\d+"#                // Westlaw
        ]
        
        for pattern in patterns {
            ranges.append(contentsOf: self.ranges(of: pattern, options: .regularExpression))
        }
        
        return ranges.sorted { $0.location < $1.location }
    }
    
    /// Finds all potential case names in the string and returns their ranges
    /// - Returns: An array of NSRange objects representing case name locations
    public func findCaseNameRanges() -> [NSRange] {
        let pattern = #"[A-Za-z\.\s]+(?:\s+(?:v\.|vs\.|versus)\s+[A-Za-z\.\s]+)"#
        return self.ranges(of: pattern, options: .regularExpression)
    }
    
    /// Extracts all potential citations from the string
    /// - Returns: An array of citation strings found in the text
    public func extractCitations() -> [String] {
        let ranges = findCitationRanges()
        return ranges.compactMap { range in
            guard let swiftRange = Range(range, in: self) else { return nil }
            return String(self[swiftRange])
        }
    }
    
    /// Extracts all potential case names from the string
    /// - Returns: An array of case name strings found in the text
    public func extractCaseNames() -> [String] {
        let ranges = findCaseNameRanges()
        return ranges.compactMap { range in
            guard let swiftRange = Range(range, in: self) else { return nil }
            return String(self[swiftRange])
        }
    }
    
    /// Checks if the string contains any legal citations
    /// - Returns: True if citations are found, false otherwise
    public func containsCitations() -> Bool {
        return !findCitationRanges().isEmpty
    }
    
    /// Checks if the string contains any case names
    /// - Returns: True if case names are found, false otherwise
    public func containsCaseNames() -> Bool {
        return !findCaseNameRanges().isEmpty
    }
    
    /// Helper method to find ranges of a regex pattern in the string
    /// - Parameters:
    ///   - pattern: The regex pattern to search for
    ///   - options: NSString.CompareOptions to use in the search
    /// - Returns: An array of NSRange objects where the pattern was found
    private func ranges(of pattern: String, options: NSString.CompareOptions) -> [NSRange] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }
        
        let matches = regex.matches(in: self, range: NSRange(self.startIndex..., in: self))
        return matches.map { $0.range }
    }
    
    /// Highlights citations in the string by wrapping them with markdown-style formatting
    /// - Parameter validationResults: Optional array of citation validation results for color coding
    /// - Returns: A string with citations highlighted
    public func highlightCitations(with validationResults: [Citation]? = nil) -> String {
        var highlightedText = self
        let citationRanges = findCitationRanges().reversed() // Reverse to maintain indices
        
        for range in citationRanges {
            guard let swiftRange = Range(range, in: highlightedText) else { continue }
            let citationText = String(highlightedText[swiftRange])
            
            // Find validation result for this citation if available
            let status = validationResults?.first { citation in
                citation.originalText.contains(citationText) ||
                citation.normalizedCitation?.contains(citationText) == true
            }?.citationStatus
            
            let highlightedCitation: String
            switch status {
            case .valid:
                highlightedCitation = "**\(citationText)**"  // Bold for valid
            case .invalid:
                highlightedCitation = "*\(citationText)*"    // Italic for invalid
            case .error:
                highlightedCitation = "~~\(citationText)~~"  // Strikethrough for error
            default:
                highlightedCitation = "`\(citationText)`"    // Code style for pending
            }
            
            highlightedText.replaceSubrange(swiftRange, with: highlightedCitation)
        }
        
        return highlightedText
    }
    
    /// Cleans the string by removing common legal document artifacts
    /// - Returns: A cleaned version of the string
    public func cleanLegalText() -> String {
        var cleanedText = self
        
        // Remove common document headers and footers
        let artifactsToRemove = [
            "FILED",
            "Page \\d+",
            "Case No\\.",
            "ORDER",
            "IT IS ORDERED",
            "UNITED STATES DISTRICT COURT",
            "DISTRICT COURT",
            "SUPERIOR COURT",
            "SUPREME COURT"
        ]
        
        for artifact in artifactsToRemove {
            cleanedText = cleanedText.replacingOccurrences(
                of: artifact,
                with: "",
                options: .regularExpression
            )
        }
        
        // Clean up extra whitespace
        cleanedText = cleanedText.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )
        
        return cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - NSRange Utilities

extension String {
    /// Converts an NSRange to a Swift Range for this string
    /// - Parameter nsRange: The NSRange to convert
    /// - Returns: A Swift Range if the conversion is successful
    public func range(from nsRange: NSRange) -> Range<String.Index>? {
        return Range(nsRange, in: self)
    }
    
    /// Converts a Swift Range to an NSRange for this string
    /// - Parameter range: The Swift Range to convert
    /// - Returns: An NSRange representing the same location in the string
    public func nsRange(from range: Range<String.Index>) -> NSRange {
        return NSRange(range, in: self)
    }
} 