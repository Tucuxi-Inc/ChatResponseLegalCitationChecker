import SwiftUI
import LegalCitationChecker

/// A view that displays citation validation results
public struct CitationResultsView: View {
    let validationResult: CitationValidationResult?
    let hasError: Bool
    let errorMessage: String
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if hasError {
                errorView
            } else if let result = validationResult {
                resultsView(result)
            } else {
                Text("No results available")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(minWidth: 300, maxWidth: 400)
    }
    
    private var errorView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Error", systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
            
            Text(errorMessage)
                .foregroundStyle(.secondary)
        }
    }
    
    private func resultsView(_ result: CitationValidationResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Summary
            HStack {
                Text("Citation Check Results")
                    .font(.headline)
                Spacer()
                Text("\(result.citations.count) citations found")
                    .foregroundStyle(.secondary)
            }
            
            // Citations list
            if !result.citations.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(result.citations) { citation in
                            CitationResultRow(citation: citation)
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
            
            // Processing time
            if result.processingTime > 0 {
                Text("Processed in \(String(format: "%.2f", result.processingTime))s")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// A row displaying a single citation result
private struct CitationResultRow: View {
    let citation: Citation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Citation text
            Text(citation.originalText)
                .font(.system(.body, design: .monospaced))
            
            // Status and details
            HStack {
                statusBadge
                if let caseName = citation.caseName {
                    Text(caseName)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Additional information
            if let notes = citation.notes {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // CourtListener link
            if let url = citation.courtListenerUrl {
                Link("View on CourtListener", destination: URL(string: url)!)
                    .font(.caption)
            }
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private var statusBadge: some View {
        Text(citation.citationStatus.rawValue.capitalized)
            .font(.caption)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(statusColor.opacity(0.2))
            .foregroundStyle(statusColor)
            .cornerRadius(4)
    }
    
    private var statusColor: Color {
        switch citation.citationStatus {
        case .valid:
            return .green
        case .invalid:
            return .red
        case .error:
            return .orange
        case .pending:
            return .gray
        }
    }
} 