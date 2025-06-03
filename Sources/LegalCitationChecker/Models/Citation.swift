import Foundation

/// Represents the status of a citation validation
public enum CitationStatus: String, Codable, Sendable {
    case pending
    case valid
    case invalid
    case error
}

/// Represents the status of a case name validation
public enum CaseNameStatus: String, Codable, Sendable {
    case pending
    case valid
    case invalid
    case error
}

/// The main data model for storing citation information
public struct Citation: Identifiable, Codable, Hashable, Sendable {
    /// Unique identifier for the citation
    public let id: UUID
    /// The original citation text as entered by the user
    public let originalText: String
    /// The standardized version of the citation (e.g., "347 U.S. 483")
    public var normalizedCitation: String?
    /// The name of the case (e.g., "Brown v. Board of Education")
    public var caseName: String?
    /// Whether the citation was found to be valid in CourtListener
    public var citationStatus: CitationStatus
    /// Whether the case name was found to be valid in CourtListener
    public var caseNameStatus: CaseNameStatus
    /// The unique identifier for the case in CourtListener's database
    public var clusterId: String?
    /// The full URL to view the case on CourtListener's website
    public var courtListenerUrl: String?
    /// When the citation was added to the app
    public let timestamp: Date
    /// The full text of the court's opinion
    public var opinionText: String?
    /// Additional notes about the citation (e.g., multiple matches found)
    public var notes: String?
    
    /// Creates a new Citation with the given text
    public init(
        id: UUID = UUID(),
        originalText: String,
        normalizedCitation: String? = nil,
        caseName: String? = nil,
        citationStatus: CitationStatus = .pending,
        caseNameStatus: CaseNameStatus = .pending,
        clusterId: String? = nil,
        courtListenerUrl: String? = nil,
        timestamp: Date = Date(),
        opinionText: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.originalText = originalText
        self.normalizedCitation = normalizedCitation
        self.caseName = caseName
        self.citationStatus = citationStatus
        self.caseNameStatus = caseNameStatus
        self.clusterId = clusterId
        self.courtListenerUrl = courtListenerUrl
        self.timestamp = timestamp
        self.opinionText = opinionText
        self.notes = notes
    }
    
    /// Creates an updated copy of the citation with new values
    public func updated(
        normalizedCitation: String? = nil,
        caseName: String? = nil,
        citationStatus: CitationStatus? = nil,
        caseNameStatus: CaseNameStatus? = nil,
        clusterId: String? = nil,
        courtListenerUrl: String? = nil,
        opinionText: String? = nil,
        notes: String? = nil
    ) -> Citation {
        Citation(
            id: self.id,
            originalText: self.originalText,
            normalizedCitation: normalizedCitation ?? self.normalizedCitation,
            caseName: caseName ?? self.caseName,
            citationStatus: citationStatus ?? self.citationStatus,
            caseNameStatus: caseNameStatus ?? self.caseNameStatus,
            clusterId: clusterId ?? self.clusterId,
            courtListenerUrl: courtListenerUrl ?? self.courtListenerUrl,
            timestamp: self.timestamp,
            opinionText: opinionText ?? self.opinionText,
            notes: notes ?? self.notes
        )
    }
}

// MARK: - Validation Results

// Represents the result of validating citations in a text
public struct CitationValidationResult: Codable, Sendable, Hashable, Equatable {
    public let citations: [Citation]
    public let processingTime: TimeInterval
    public let errors: [String]
    
    public init(citations: [Citation], processingTime: TimeInterval, errors: [String] = []) {
        self.citations = citations
        self.processingTime = processingTime
        self.errors = errors
    }
}

// Represents a citation with its location in the original text for highlighting
public struct CitationLocation: Codable, Sendable {
    public let citation: Citation
    public let range: NSRange
    
    public init(citation: Citation, range: NSRange) {
        self.citation = citation
        self.range = range
    }
} 