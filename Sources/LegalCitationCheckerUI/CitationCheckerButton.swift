import SwiftUI
import LegalCitationChecker

/// A button that can be added to any view to enable citation checking
public struct CitationCheckerButton: View {
    /// The text to check for citations
    let text: String
    
    /// The API token for CourtListener
    let apiToken: String
    
    /// Optional callback when validation completes
    let onValidationComplete: ((CitationValidationResult) -> Void)?
    
    @State private var isValidating = false
    @State private var validationResult: CitationValidationResult?
    @State private var showResults = false
    @State private var hasError = false
    @State private var errorMessage = ""
    
    /// Creates a new citation checker button
    /// - Parameters:
    ///   - text: The text to check for citations
    ///   - apiToken: The CourtListener API token
    ///   - onValidationComplete: Optional callback when validation completes
    public init(
        text: String,
        apiToken: String,
        onValidationComplete: ((CitationValidationResult) -> Void)? = nil
    ) {
        self.text = text
        self.apiToken = apiToken
        self.onValidationComplete = onValidationComplete
    }
    
    public var body: some View {
        Button {
            Task {
                await validateCitations()
            }
        } label: {
            Image(systemName: isValidating ? "clock" : "checkmark.seal")
                .imageScale(.small)
                .foregroundStyle(buttonColor)
                .background(.clear)
        }
        .disabled(isValidating || text.isEmpty)
        .help("Check Legal Citations")
        .popover(isPresented: $showResults) {
            CitationResultsView(
                validationResult: validationResult,
                hasError: hasError,
                errorMessage: errorMessage
            )
        }
        .buttonStyle(.plain)
        .padding(0)
        .padding(.vertical, 2)
    }
    
    private var buttonColor: Color {
        if hasError {
            return .red
        } else if isValidating {
            return .orange
        } else if validationResult?.citations.isEmpty == false {
            return .green
        } else {
            return .secondary
        }
    }
    
    @MainActor
    private func validateCitations() async {
        isValidating = true
        hasError = false
        validationResult = nil
        
        do {
            // Set API token
            await LegalCitationChecker.shared.setAPIToken(apiToken)
            
            // Validate citations
            let result = try await LegalCitationChecker.shared.validateCitations(in: text)
            validationResult = result
            showResults = true
            onValidationComplete?(result)
        } catch {
            hasError = true
            errorMessage = error.localizedDescription
            showResults = true
        }
        
        isValidating = false
    }
} 