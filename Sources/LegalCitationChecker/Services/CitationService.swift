import Foundation

// Error types for CitationService operations
public enum CitationServiceError: Error, LocalizedError {
    case noAPIToken
    case apiError(String)
    case networkError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .noAPIToken:
            return "No API token set for CourtListener"
        case .apiError(let message):
            return "API error: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// A service that handles the validation of legal citations
// This service coordinates between the UI and the CourtListener API,
// managing the validation process and returning results
public class CitationService: ObservableObject {
    // The API client used to communicate with CourtListener
    private let api = CourtListenerAPI.shared
    
    // Published property for validation results
    @Published public private(set) var isValidating = false
    
    // Creates a new CitationService
    public init() {}
    
    // Validates a piece of text containing legal citations
    // This method implements the exact flow:
    // 1. Send complete response text to CourtListener citation lookup API
    // 2. For valid citations (status 200), highlight in green
    // 3. For invalid citations (400/404), parse case names and search using search API
    // 4. If case name found, highlight in yellow with link
    // 5. If case name not found, highlight in red
    public func validateText(_ text: String) async throws -> CitationValidationResult {
        let startTime = Date()
        print("\n=== Starting Citation Validation with Complete Response Text ===")
        print("Input text length: \(text.count) characters")
        print("\nInput text:")
        print("----------------------------------------")
        print(text)
        print("----------------------------------------")
        
        await MainActor.run {
            isValidating = true
        }
        
        defer {
            Task { @MainActor in
                isValidating = false
            }
        }
        
        var citations: [Citation] = []
        var errors: [String] = []
        
        do {
            // Step 1: Send complete response text to CourtListener citation lookup API
            print("\nSending complete response text to CourtListener citation lookup API...")
            
            // Check if API token is set
            if !(await api.hasValidToken()) {
                print("❌ No API token set - cannot make API call")
                throw CitationServiceError.noAPIToken
            }
            
            print("✅ API token is set, proceeding with API call")
            let responses = try await api.lookupCitationsInText(text)
            
            print("\nRaw API Response:")
            print("----------------------------------------")
            print("Number of responses: \(responses.count)")
            for (index, response) in responses.enumerated() {
                print("\nResponse \(index + 1):")
                print("Citation: \(response.citation)")
                print("Status: \(response.status)")
                print("Error Message: \(response.errorMessage)")
                print("Normalized Citations: \(response.normalizedCitations)")
                print("Clusters: \(response.clusters.count)")
                for (clusterIndex, cluster) in response.clusters.enumerated() {
                    print("  Cluster \(clusterIndex + 1):")
                    print("    ID: \(cluster.id)")
                    print("    Case Name: \(cluster.caseName)")
                    print("    URL: \(cluster.absoluteUrl)")
                }
            }
            print("----------------------------------------")
            
            if responses.isEmpty {
                print("\nNo citations found in text")
                // Try to extract case names for debugging
                let caseNames = extractAllCaseNames(from: text)
                if !caseNames.isEmpty {
                    print("\nPotential case names found in text:")
                    for caseName in caseNames {
                        print("- \(caseName)")
                    }
                }
                // Return empty result - no citations to validate
                return CitationValidationResult(
                    citations: [],
                    processingTime: Date().timeIntervalSince(startTime),
                    errors: []
                )
            }
            
            // Process each citation response from the API
            for response in responses {
                print("\n--- Processing citation: \(response.citation) ---")
                print("Status: \(response.status), Clusters: \(response.clusters.count)")
                
                var citation = Citation(
                    originalText: response.citation,
                    normalizedCitation: response.normalizedCitations.first
                )
                
                if response.status == 200 && !response.clusters.isEmpty {
                    // Step 2: Citation is valid - highlight in green
                    print("✅ Citation is valid: \(response.citation)")
                    let cluster = response.clusters.first!
                    
                    citation = citation.updated(
                        normalizedCitation: response.normalizedCitations.first ?? response.citation,
                        caseName: cluster.caseName,
                        citationStatus: .valid,
                        caseNameStatus: .valid,
                        clusterId: cluster.stringId,
                        courtListenerUrl: "https://www.courtlistener.com\(cluster.absoluteUrl)",
                        notes: createValidCitationNotes(response: response)
                    )
                } else if response.status == 400 || response.status == 404 {
                    // Step 3: Citation is invalid (400/404) - try case name search
                    print("❌ Citation invalid (status \(response.status)): \(response.citation)")
                    citation = citation.updated(citationStatus: .invalid)
                    
                    // First, try to extract case name from the original text context around this citation
                    var extractedCaseName: String? = nil
                    
                    // Look for the citation in the original text and extract surrounding case name
                    if let caseNameFromContext = extractCaseNameFromContext(citation: response.citation, originalText: text) {
                        print("🔍 Extracted case name from context: \(caseNameFromContext)")
                        extractedCaseName = caseNameFromContext
                    } else if let caseNameFromCitation = extractCaseNameFromCitation(response.citation) {
                        print("🔍 Extracted case name from citation: \(caseNameFromCitation)")
                        extractedCaseName = caseNameFromCitation
                    }
                    
                    if let caseName = extractedCaseName {
                        citation = citation.updated(caseName: caseName)
                        
                        print("🔍 Citation updated with extracted case name:")
                        print("  Case Name: \(citation.caseName ?? "nil")")
                        print("  Citation Status: \(citation.citationStatus)")
                        print("  Case Name Status: \(citation.caseNameStatus)")
                        
                        // Step 4: Search for case name using search API
                        do {
                            print("\nSearching for case name: \(caseName)")
                            let searchResults = try await api.searchCaseName(caseName)
                            print("Search results count: \(searchResults.count)")
                            
                            if !searchResults.isEmpty {
                                // Case name found - highlight in yellow with link
                                print("🟡 Case name found in search: \(caseName)")
                                let firstResult = searchResults.first!
                                
                                print("🔍 Search result details:")
                                print("  Case Name: \(firstResult.caseName)")
                                print("  Cluster ID: \(firstResult.clusterId)")
                                print("  Absolute URL: \(firstResult.absoluteUrl)")
                                print("  Court: \(firstResult.court)")
                                print("  Date Filed: \(firstResult.dateFiled)")
                                
                                let updatedCitation = citation.updated(
                                    caseNameStatus: .partiallyValid,
                                    clusterId: String(firstResult.clusterId),
                                    courtListenerUrl: "https://www.courtlistener.com\(firstResult.absoluteUrl)",
                                    notes: createCaseNameFoundNotes(caseName: caseName, searchResults: searchResults)
                                )
                                
                                print("🔍 Citation after update:")
                                print("  Original Text: \(updatedCitation.originalText)")
                                print("  Case Name: \(updatedCitation.caseName ?? "nil")")
                                print("  Citation Status: \(updatedCitation.citationStatus)")
                                print("  Case Name Status: \(updatedCitation.caseNameStatus)")
                                print("  Cluster ID: \(updatedCitation.clusterId ?? "nil")")
                                print("  Court Listener URL: \(updatedCitation.courtListenerUrl ?? "nil")")
                                
                                citation = updatedCitation
                            } else {
                                // Step 5: Case name not found - highlight in red
                                print("🔴 Case name not found: \(caseName)")
                                citation = citation.updated(
                                    caseNameStatus: .invalid,
                                    notes: createCaseNameNotFoundNotes(caseName: caseName)
                                )
                            }
                        } catch {
                            print("⚠️ Error searching case name: \(error)")
                            citation = citation.updated(
                                caseNameStatus: .invalid,
                                notes: "Error searching case name: \(error.localizedDescription)"
                            )
                        }
                    } else {
                        // Could not extract case name from either context or citation
                        print("❌ Could not extract case name from context or citation: \(response.citation)")
                        citation = citation.updated(
                            caseNameStatus: .invalid,
                            notes: createInvalidCitationNotes(response: response)
                        )
                    }
                } else {
                    // Other error status
                    print("⚠️ Unexpected status \(response.status) for citation: \(response.citation)")
                    citation = citation.updated(
                        citationStatus: .invalid,
                        caseNameStatus: .invalid,
                        notes: createInvalidCitationNotes(response: response)
                    )
                }
                
                print("🔍 Citation before adding to results:")
                print("  Original Text: \(citation.originalText)")
                print("  Normalized: \(citation.normalizedCitation ?? "N/A")")
                print("  Case Name: \(citation.caseName ?? "N/A")")
                print("  Citation Status: \(citation.citationStatus)")
                print("  Case Name Status: \(citation.caseNameStatus)")
                print("  URL: \(citation.courtListenerUrl ?? "N/A")")
                if let notes = citation.notes {
                    print("  Notes: \(notes)")
                }
                
                citations.append(citation)
            }
        } catch {
            print("⚠️ Error during citation validation: \(error)")
            errors.append("Citation validation error: \(error.localizedDescription)")
            
            // Create an error citation entry
            let citation = Citation(
                originalText: text.prefix(100) + (text.count > 100 ? "..." : ""),
                citationStatus: .error,
                caseNameStatus: .error,
                notes: "Error occurred during citation validation: \(error.localizedDescription)"
            )
            citations.append(citation)
        }
        
        let processingTime = Date().timeIntervalSince(startTime)
        print("\n=== Citation Validation Complete ===")
        print("Processed \(citations.count) citations in \(String(format: "%.2f", processingTime))s")
        
        return CitationValidationResult(
            citations: citations,
            processingTime: processingTime,
            errors: errors
        )
    }
    
    // Extracts case name from the original text context around a citation
    // This method looks for case names near where the citation appears in the text
    private func extractCaseNameFromContext(citation: String, originalText: String) -> String? {
        // Find the location of the citation in the original text
        guard let citationRange = originalText.range(of: citation) else {
            print("🔍 Citation '\(citation)' not found in original text")
            return nil
        }
        
        // Look in a window around the citation for case names
        let windowSize = 200 // characters before and after the citation
        let startIndex = max(originalText.startIndex, 
                           originalText.index(citationRange.lowerBound, offsetBy: -windowSize, limitedBy: originalText.startIndex) ?? originalText.startIndex)
        let endIndex = min(originalText.endIndex,
                         originalText.index(citationRange.upperBound, offsetBy: windowSize, limitedBy: originalText.endIndex) ?? originalText.endIndex)
        
        let contextWindow = String(originalText[startIndex..<endIndex])
        print("🔍 Context window: \(contextWindow)")
        
        // Pattern to match case names with "v." or "vs." or "versus"
        let caseNamePattern = #"([A-Za-z\.\s&,']+(?:\s+(?:v\.|vs\.|versus)\s+[A-Za-z\.\s&,']+))"#
        
        if let regex = try? NSRegularExpression(pattern: caseNamePattern) {
            let matches = regex.matches(in: contextWindow, range: NSRange(contextWindow.startIndex..., in: contextWindow))
            
            // Find the case name closest to the citation
            var closestCaseName: String? = nil
            var closestDistance = Int.max
            
            for match in matches {
                if let range = Range(match.range(at: 1), in: contextWindow) {
                    let caseName = String(contextWindow[range])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                    
                    // Clean up common artifacts
                    let cleanedCaseName = caseName
                        .replacingOccurrences(of: " ,", with: ",")
                        .replacingOccurrences(of: "  ", with: " ")
                        .replacingOccurrences(of: " :", with: "")
                        .replacingOccurrences(of: "\\([^)]*\\)", with: "", options: .regularExpression) // Remove parenthetical content like years
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // Skip if it's too short or contains numbers (likely not a case name)
                    if cleanedCaseName.count < 5 || cleanedCaseName.contains(where: { $0.isNumber }) {
                        continue
                    }
                    
                    // Calculate distance from the case name to the citation
                    let caseNameEndIndex = range.upperBound
                    let caseNameEndOffset = contextWindow.distance(from: contextWindow.startIndex, to: caseNameEndIndex)
                    let citationStartOffset = contextWindow.distance(from: contextWindow.startIndex, 
                                                                   to: contextWindow.range(of: citation)?.lowerBound ?? contextWindow.endIndex)
                    let distance = abs(citationStartOffset - caseNameEndOffset)
                    
                    if distance < closestDistance {
                        closestDistance = distance
                        closestCaseName = cleanedCaseName
                    }
                }
            }
            
            if let caseName = closestCaseName, !caseName.isEmpty {
                print("🔍 Found closest case name: '\(caseName)' at distance \(closestDistance)")
                return caseName
            }
        }
        
        return nil
    }
    
    // Extracts case name from a citation string
    // Looks for patterns like "Case Name v. Other Name" before the citation
    private func extractCaseNameFromCitation(_ citationText: String) -> String? {
        // Pattern to match case names with "v." or "vs." or "versus"
        let caseNamePattern = #"([A-Za-z\.\s&]+(?:\s+(?:v\.|vs\.|versus)\s+[A-Za-z\.\s&]+))"#
        
        if let regex = try? NSRegularExpression(pattern: caseNamePattern),
           let match = regex.firstMatch(in: citationText, range: NSRange(citationText.startIndex..., in: citationText)) {
            
            if let range = Range(match.range(at: 1), in: citationText) {
                let caseName = String(citationText[range])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                
                // Clean up common artifacts
                let cleanedCaseName = caseName
                    .replacingOccurrences(of: " ,", with: ",")
                    .replacingOccurrences(of: "  ", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                return cleanedCaseName.isEmpty ? nil : cleanedCaseName
            }
        }
        
        return nil
    }
    
    // Creates notes for when case name is found but citation is invalid
    private func createCaseNameFoundNotes(caseName: String, searchResults: [CaseResult]) -> String {
        var notes: [String] = []
        
        notes.append("🟡 Citation format invalid, but case found by name")
        notes.append("📝 Case: \(caseName)")
        
        if let firstResult = searchResults.first {
            notes.append("🔗 Found: \(firstResult.caseName)")
            notes.append("🏛️ Court: \(firstResult.court)")
            notes.append("📅 Date: \(firstResult.dateFiled)")
            
            if !firstResult.citation.isEmpty {
                notes.append("📖 Proper citation: \(firstResult.citation.joined(separator: ", "))")
            }
        }
        
        if searchResults.count > 1 {
            notes.append("\n📚 Additional matches found:")
            for result in searchResults.dropFirst().prefix(3) {
                notes.append("• \(result.caseName) (\(result.court))")
            }
        }
        
        return notes.joined(separator: "\n")
    }
    
    // Creates notes for when case name is not found
    private func createCaseNameNotFoundNotes(caseName: String) -> String {
        var notes: [String] = []
        
        notes.append("🔴 Citation and case name not found")
        notes.append("📝 Searched for: \(caseName)")
        notes.append("\n💡 This may be:")
        notes.append("• A hallucinated or fictional case")
        notes.append("• From a jurisdiction not in CourtListener")
        notes.append("• A very recent case not yet indexed")
        notes.append("• Incorrectly spelled or formatted")
        
        return notes.joined(separator: "\n")
    }
    
    // Validates a single citation string
    public func validateSingleCitation(_ citationText: String) async throws -> Citation {
        let result = try await validateText(citationText)
        return result.citations.first ?? Citation(originalText: citationText, citationStatus: .error, caseNameStatus: .error)
    }
    
    // Creates notes for valid citations with additional information
    private func createValidCitationNotes(response: CitationResponse) -> String? {
        var notes: [String] = []
        
        // Add normalized citation info if different from original
        if let normalized = response.normalizedCitations.first,
           normalized != response.citation {
            notes.append("📝 Normalized: \(normalized)")
        }
        
        // Add cluster information
        if let cluster = response.clusters.first {
            notes.append("✅ Case: \(cluster.caseName)")
            notes.append("🔗 CourtListener ID: \(cluster.id)")
        }
        
        // Add information about multiple clusters if present
        if response.clusters.count > 1 {
            notes.append("\n📚 Additional matches found:")
            for cluster in response.clusters.dropFirst().prefix(3) {
                notes.append("• \(cluster.caseName)")
            }
        }
        
        return notes.isEmpty ? nil : notes.joined(separator: "\n")
    }
    
    // Creates notes for invalid citations with error information
    private func createInvalidCitationNotes(response: CitationResponse) -> String {
        var notes: [String] = []
        
        notes.append("❌ Citation not found in CourtListener database")
        
        if !response.errorMessage.isEmpty {
            notes.append("⚠️ Error: \(response.errorMessage)")
        }
        
        // Add normalized citation info if available
        if let normalized = response.normalizedCitations.first,
           normalized != response.citation {
            notes.append("📝 Normalized format: \(normalized)")
        }
        
        notes.append("\n💡 This citation may be:")
        notes.append("• From a jurisdiction not covered by CourtListener")
        notes.append("• A recent case not yet indexed")
        notes.append("• Incorrectly formatted")
        notes.append("• A non-case citation (statute, regulation, etc.)")
        
        return notes.joined(separator: "\n")
    }
    
    // Helper function to extract all potential case names from text
    private func extractAllCaseNames(from text: String) -> [String] {
        // Pattern to match case names with "v." or "vs." or "versus"
        let caseNamePattern = #"([A-Za-z\.\s&]+(?:\s+(?:v\.|vs\.|versus)\s+[A-Za-z\.\s&]+))"#
        
        var caseNames: [String] = []
        
        if let regex = try? NSRegularExpression(pattern: caseNamePattern) {
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            
            for match in matches {
                if let range = Range(match.range(at: 1), in: text) {
                    let caseName = String(text[range])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                        .replacingOccurrences(of: " ,", with: ",")
                        .replacingOccurrences(of: "  ", with: " ")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if !caseName.isEmpty {
                        caseNames.append(caseName)
                    }
                }
            }
        }
        
        return caseNames
    }
}

// MARK: - Testing and Debugging

extension CitationService {
    /// Test method to verify API-based citation validation
    /// This method can be used for debugging and testing the new workflow
    public func testValidation(with sampleText: String) async {
        print("\n=== Testing Citation Validation ===")
        print("Sample text: \(sampleText)")
        
        do {
            let result = try await validateText(sampleText)
            print("\n--- Test Results ---")
            print("Citations found: \(result.citations.count)")
            print("Processing time: \(String(format: "%.2f", result.processingTime))s")
            print("Errors: \(result.errors.count)")
            
            for (index, citation) in result.citations.enumerated() {
                print("\nCitation \(index + 1):")
                print("  Original: \(citation.originalText)")
                print("  Normalized: \(citation.normalizedCitation ?? "N/A")")
                print("  Case Name: \(citation.caseName ?? "N/A")")
                print("  Citation Status: \(citation.citationStatus)")
                print("  Case Name Status: \(citation.caseNameStatus)")
                print("  URL: \(citation.courtListenerUrl ?? "N/A")")
                if let notes = citation.notes {
                    print("  Notes: \(notes)")
                }
            }
        } catch {
            print("❌ Test failed with error: \(error)")
        }
        
        print("\n=== Test Complete ===")
    }
} 