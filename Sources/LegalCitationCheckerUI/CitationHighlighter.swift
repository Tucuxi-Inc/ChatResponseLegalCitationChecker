import SwiftUI
import LegalCitationChecker

/// A SwiftUI view that displays text with highlighted legal citations
public struct CitationHighlighter: View {
    // MARK: - Properties
    
    /// The text to display and highlight
    public let text: String
    
    /// The validation results for highlighting
    public let validationResults: [Citation]
    
    /// Whether to show validation tooltips on hover
    public let showTooltips: Bool
    
    /// The font to use for the text
    public let font: Font
    
    // MARK: - State
    
    @State private var hoveredCitation: Citation?
    
    // MARK: - Initialization
    
    /// Creates a citation highlighter view
    /// - Parameters:
    ///   - text: The text to display and highlight
    ///   - validationResults: The validation results for color coding
    ///   - showTooltips: Whether to show tooltips on hover
    ///   - font: The font to use for the text
    public init(
        text: String,
        validationResults: [Citation] = [],
        showTooltips: Bool = true,
        font: Font = .body
    ) {
        self.text = text
        self.validationResults = validationResults
        self.showTooltips = showTooltips
        self.font = font
    }
    
    // MARK: - Body
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main text with highlighting
            textWithHighlights
            
            // Tooltip if citation is hovered
            if showTooltips, let hoveredCitation = hoveredCitation {
                CitationTooltip(citation: hoveredCitation)
                    .transition(.opacity)
            }
        }
    }
    
    // MARK: - Private Views
    
    private var textWithHighlights: some View {
        Text(createAttributedString())
            .font(font)
            .textSelection(.enabled)
    }
    
    // MARK: - Private Methods
    
    private func createAttributedString() -> AttributedString {
        var attributedString = AttributedString(text)
        
        // Find all citation ranges in the text
        let citationRanges = text.findCitationRanges()
        
        for range in citationRanges.reversed() { // Reverse to maintain indices
            guard let swiftRange = text.range(from: range) else { continue }
            let citationText = String(text[swiftRange])
            
            // Find matching validation result
            let matchingCitation = validationResults.first { citation in
                citation.originalText.contains(citationText) ||
                citation.normalizedCitation?.contains(citationText) == true ||
                citationText.contains(citation.originalText)
            }
            
            // Apply highlighting based on validation status
            if let citation = matchingCitation {
                let color = citation.citationStatus.color
                let attributedRange = attributedString.range(from: swiftRange)
                
                if let attrRange = attributedRange {
                    attributedString[attrRange].backgroundColor = color.opacity(0.3)
                    attributedString[attrRange].foregroundColor = color
                    attributedString[attrRange].font = font.weight(.medium)
                    
                    // Note: Cursor interaction would be added here for tooltips in a full implementation
                }
            } else {
                // Default highlighting for unvalidated citations
                let attributedRange = attributedString.range(from: swiftRange)
                if let attrRange = attributedRange {
                    attributedString[attrRange].backgroundColor = Color.gray.opacity(0.2)
                    attributedString[attrRange].font = font.weight(.medium)
                }
            }
        }
        
        return attributedString
    }
}

// MARK: - Citation Tooltip

struct CitationTooltip: View {
    let citation: Citation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Citation text
            Text(citation.originalText)
                .font(.headline)
                .lineLimit(2)
            
            // Status badges
            HStack {
                ValidationBadge(status: citation.citationStatus, size: .small)
                if let _ = citation.caseName {
                    ValidationBadge(status: citation.caseNameStatus, title: "Case Name", size: .small)
                }
            }
            
            // Case name if available
            if let caseName = citation.caseName {
                Text(caseName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Normalized citation if available
            if let normalizedCitation = citation.normalizedCitation {
                Text("Normalized: \(normalizedCitation)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Court listener link if available
            if let courtListenerUrl = citation.courtListenerUrl,
               let url = URL(string: courtListenerUrl) {
                Link("View on CourtListener", destination: url)
                    .font(.caption)
            }
            
            // Notes if available
            if let notes = citation.notes {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .shadow(radius: 4)
        .frame(maxWidth: 300)
    }
}

// MARK: - Extensions

extension AttributedString {
    /// Converts a Swift Range to an AttributedString Range
    func range(from swiftRange: Range<String.Index>) -> Range<AttributedString.Index>? {
        let startIndex = self.index(self.startIndex, offsetByCharacters: swiftRange.lowerBound.utf16Offset(in: String(self.characters)))
        let endIndex = self.index(self.startIndex, offsetByCharacters: swiftRange.upperBound.utf16Offset(in: String(self.characters)))
        
        guard startIndex <= endIndex && endIndex <= self.endIndex else {
            return nil
        }
        
        return startIndex..<endIndex
    }
}

extension String.Index {
    func utf16Offset(in string: String) -> Int {
        return string.utf16.distance(from: string.startIndex, to: self)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Citation Highlighter") {
    let sampleText = """
    In Brown v. Board of Education, 347 U.S. 483 (1954), the Supreme Court held that racial segregation in public schools was unconstitutional. This landmark decision overturned Plessy v. Ferguson, 163 U.S. 537 (1896), which had established the "separate but equal" doctrine.
    
    The case was further clarified in Green v. County School Board, 391 U.S. 430 (1968), which required school districts to take affirmative steps to eliminate segregation.
    """
    
    let sampleCitations = [
        Citation(
            originalText: "Brown v. Board of Education, 347 U.S. 483 (1954)",
            normalizedCitation: "347 U.S. 483",
            caseName: "Brown v. Board of Education",
            citationStatus: .valid,
            caseNameStatus: .valid,
            courtListenerUrl: "https://www.courtlistener.com/opinion/103/brown-v-board-of-education/"
        ),
        Citation(
            originalText: "Plessy v. Ferguson, 163 U.S. 537 (1896)",
            normalizedCitation: "163 U.S. 537",
            caseName: "Plessy v. Ferguson",
            citationStatus: .valid,
            caseNameStatus: .valid
        ),
        Citation(
            originalText: "Green v. County School Board, 391 U.S. 430 (1968)",
            normalizedCitation: "391 U.S. 430",
            caseName: "Green v. County School Board",
            citationStatus: .invalid,
            caseNameStatus: .valid,
            notes: "Citation format not found in database"
        )
    ]
    
    ScrollView {
        CitationHighlighter(
            text: sampleText,
            validationResults: sampleCitations,
            showTooltips: true,
            font: .body
        )
        .padding()
    }
}
#endif 