import Foundation

// MARK: - Main API Entry Point

/// The main interface for the Legal Citation Checker package
/// This class provides a simplified API for validating legal citations and processing documents
public class LegalCitationChecker: ObservableObject {
    
    // MARK: - Properties
    
    /// The citation validation service
    private let citationService = CitationService()
    
    /// The document parser service
    private let documentParser = DocumentParser.shared
    
    /// The CourtListener API client
    private let apiClient = CourtListenerAPI.shared
    
    /// Published property indicating if validation is in progress
    @Published public private(set) var isValidating = false
    
    /// Published property for the last validation result
    @Published public private(set) var lastValidationResult: CitationValidationResult?
    
    // MARK: - Shared Instance
    
    /// Shared instance of the Legal Citation Checker
    public static let shared = LegalCitationChecker()
    
    /// Private initializer to enforce singleton pattern
    private init() {}
    
    // MARK: - Configuration
    
    /// Sets the CourtListener API token for authentication
    /// - Parameter token: The API token from CourtListener
    public func setAPIToken(_ token: String) async {
        print("\n=== LegalCitationChecker.setAPIToken called ===")
        print("Received token length: \(token.count) characters")
        print("Setting token on API client...")
        await apiClient.setAPIToken(token)
        print("✅ Token setting complete")
    }
    
    /// Checks if the API is properly configured and accessible
    /// - Returns: True if the API is ready to use
    public func isAPIReady() async -> Bool {
        do {
            return try await apiClient.healthCheck()
        } catch {
            return false
        }
    }
    
    // MARK: - Citation Validation
    
    /// Validates legal citations in the provided text
    /// - Parameter text: The text containing potential legal citations
    /// - Returns: A validation result containing validated citations
    /// - Throws: CourtListenerAPIError if validation fails
    public func validateCitations(in text: String) async throws -> CitationValidationResult {
        await MainActor.run {
            isValidating = true
        }
        
        defer {
            Task { @MainActor in
                isValidating = false
            }
        }
        
        let result = try await citationService.validateText(text)
        
        await MainActor.run {
            lastValidationResult = result
        }
        
        return result
    }
    
    /// Validates a single citation
    /// - Parameter citation: The citation text to validate
    /// - Returns: A validated citation object
    /// - Throws: CourtListenerAPIError if validation fails
    public func validateSingleCitation(_ citation: String) async throws -> Citation {
        return try await citationService.validateSingleCitation(citation)
    }
    
    // MARK: - Document Processing
    
    /// Processes a document and extracts potential legal citations
    /// - Parameter url: The URL of the document to process
    /// - Returns: A string containing extracted citations
    /// - Throws: DocumentParserError if processing fails
    public func processDocument(at url: URL) async throws -> String {
        return try await documentParser.parseDocument(at: url)
    }
    
    /// Processes a document and validates any citations found
    /// - Parameter url: The URL of the document to process
    /// - Returns: A validation result containing extracted and validated citations
    /// - Throws: DocumentParserError or CourtListenerAPIError if processing fails
    public func processAndValidateDocument(at url: URL) async throws -> CitationValidationResult {
        let extractedText = try await documentParser.parseDocument(at: url)
        return try await validateCitations(in: extractedText)
    }
    
    // MARK: - Text Analysis
    
    /// Finds all potential citation ranges in the provided text
    /// - Parameter text: The text to analyze
    /// - Returns: An array of NSRange objects indicating citation locations
    public func findCitationRanges(in text: String) -> [NSRange] {
        return text.findCitationRanges()
    }
    
    /// Finds all potential case name ranges in the provided text
    /// - Parameter text: The text to analyze
    /// - Returns: An array of NSRange objects indicating case name locations
    public func findCaseNameRanges(in text: String) -> [NSRange] {
        return text.findCaseNameRanges()
    }
    
    /// Checks if the provided text contains any legal citations
    /// - Parameter text: The text to check
    /// - Returns: True if citations are found
    public func containsCitations(_ text: String) -> Bool {
        return text.containsCitations()
    }
    
    /// Extracts potential citations from text without validation
    /// - Parameter text: The text to analyze
    /// - Returns: An array of potential citation strings
    public func extractCitations(from text: String) -> [String] {
        return text.extractCitations()
    }
    
    // MARK: - Utility Methods
    
    /// Cleans legal text by removing common document artifacts
    /// - Parameter text: The text to clean
    /// - Returns: Cleaned text
    public func cleanLegalText(_ text: String) -> String {
        return text.cleanLegalText()
    }
    
    /// Highlights citations in text based on validation results
    /// - Parameters:
    ///   - text: The text to highlight
    ///   - validationResults: Optional validation results for color coding
    /// - Returns: Text with highlighted citations
    public func highlightCitations(in text: String, with validationResults: [Citation]? = nil) -> String {
        return text.highlightCitations(with: validationResults)
    }
    
    // MARK: - Debug Methods
    
    /// Debug method to test the complete API flow with detailed logging
    /// This helps diagnose API token and connectivity issues
    public func debugAPIFlow(with sampleText: String = "Brown v. Board of Education, 347 U.S. 483 (1954)") async {
        print("\n🔍 === DEBUG: API Flow Test ===")
        print("Sample text: \(sampleText)")
        
        // Step 1: Check if token is set
        print("\n1️⃣ Checking API token status...")
        let hasToken = await apiClient.hasValidToken()
        print("Has valid token: \(hasToken)")
        
        if !hasToken {
            print("❌ No API token set. Please set token first with setAPIToken()")
            return
        }
        
        // Step 2: Test API connectivity
        print("\n2️⃣ Testing API connectivity...")
        do {
            let isReady = try await apiClient.healthCheck()
            print("✅ API health check passed: \(isReady)")
        } catch {
            print("❌ API health check failed: \(error)")
            return
        }
        
        // Step 3: Test citation validation
        print("\n3️⃣ Testing citation validation...")
        do {
            let result = try await validateCitations(in: sampleText)
            print("✅ Validation completed successfully")
            print("Citations found: \(result.citations.count)")
            print("Processing time: \(String(format: "%.2f", result.processingTime))s")
            print("Errors: \(result.errors.count)")
            
            for (index, citation) in result.citations.enumerated() {
                print("\nCitation \(index + 1):")
                print("  Text: \(citation.originalText)")
                print("  Status: \(citation.citationStatus)")
                print("  Case: \(citation.caseName ?? "N/A")")
            }
        } catch {
            print("❌ Validation failed: \(error)")
        }
        
        print("\n🔍 === DEBUG: API Flow Test Complete ===")
    }
    
    /// Simple debug method to just test API token setting
    public func debugTokenSetting(token: String) async {
        print("\n🔍 === DEBUG: Token Setting Test ===")
        print("Setting token...")
        await setAPIToken(token)
        
        print("Checking token after setting...")
        let hasToken = await apiClient.hasValidToken()
        print("Has valid token after setting: \(hasToken)")
        print("🔍 === DEBUG: Token Setting Test Complete ===")
    }
}

// MARK: - Convenience Extensions

extension LegalCitationChecker {
    
    /// Validates citations and returns a simple summary
    /// - Parameter text: The text containing potential citations
    /// - Returns: A summary of validation results
    public func getValidationSummary(for text: String) async throws -> CitationValidationSummary {
        let result = try await validateCitations(in: text)
        
        let validCount = result.citations.filter { $0.citationStatus == .valid }.count
        let invalidCount = result.citations.filter { $0.citationStatus == .invalid }.count
        let errorCount = result.citations.filter { $0.citationStatus == .error }.count
        let pendingCount = result.citations.filter { $0.citationStatus == .pending }.count
        
        return CitationValidationSummary(
            totalCitations: result.citations.count,
            validCitations: validCount,
            invalidCitations: invalidCount,
            errorCitations: errorCount,
            pendingCitations: pendingCount,
            processingTime: result.processingTime,
            hasErrors: !result.errors.isEmpty
        )
    }
}

// MARK: - Supporting Types

/// A summary of citation validation results
public struct CitationValidationSummary: Codable, Sendable {
    public let totalCitations: Int
    public let validCitations: Int
    public let invalidCitations: Int
    public let errorCitations: Int
    public let pendingCitations: Int
    public let processingTime: TimeInterval
    public let hasErrors: Bool
    
    public var validationRate: Double {
        guard totalCitations > 0 else { return 0.0 }
        return Double(validCitations) / Double(totalCitations)
    }
    
    public var description: String {
        return """
        Citation Validation Summary:
        - Total: \(totalCitations)
        - Valid: \(validCitations)
        - Invalid: \(invalidCitations)
        - Errors: \(errorCitations)
        - Pending: \(pendingCitations)
        - Success Rate: \(String(format: "%.1f", validationRate * 100))%
        - Processing Time: \(String(format: "%.2f", processingTime))s
        """
    }
} 