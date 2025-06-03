import SwiftUI
import LegalCitationChecker

/// A SwiftUI view that displays the validation status of a citation as a colored badge
public struct ValidationBadge: View {
    // MARK: - Properties
    
    /// Internal status representation
    private let displayStatus: DisplayStatus
    
    /// The title text for the badge
    public let title: String
    
    /// Size variant for the badge
    public let size: BadgeSize
    
    // MARK: - Internal Status Type
    
    private enum DisplayStatus {
        case citationStatus(CitationStatus)
        case caseNameStatus(CaseNameStatus)
        
        var color: Color {
            switch self {
            case .citationStatus(let status):
                return status.color
            case .caseNameStatus(let status):
                return status.color
            }
        }
        
        var displayName: String {
            switch self {
            case .citationStatus(let status):
                return status.displayName
            case .caseNameStatus(let status):
                return status.displayName
            }
        }
    }
    
    // MARK: - Initialization
    
    /// Creates a validation badge for a citation status
    /// - Parameters:
    ///   - status: The citation validation status
    ///   - title: Optional custom title (defaults to status description)
    ///   - size: The size variant for the badge
    public init(
        status: CitationStatus,
        title: String? = nil,
        size: BadgeSize = .normal
    ) {
        self.displayStatus = .citationStatus(status)
        self.title = title ?? status.displayName
        self.size = size
    }
    
    /// Creates a validation badge for a case name status
    /// - Parameters:
    ///   - status: The case name validation status
    ///   - title: Optional custom title (defaults to status description)
    ///   - size: The size variant for the badge
    public init(
        status: CaseNameStatus,
        title: String? = nil,
        size: BadgeSize = .normal
    ) {
        self.displayStatus = .caseNameStatus(status)
        self.title = title ?? status.displayName
        self.size = size
    }
    
    // MARK: - Body
    
    public var body: some View {
        Text(title)
            .font(size.font)
            .foregroundColor(.white)
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .background(displayStatus.color)
            .cornerRadius(size.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: size.cornerRadius)
                    .stroke(displayStatus.color.opacity(0.3), lineWidth: 1)
            )
    }
}

// MARK: - Badge Size Variants

public enum BadgeSize {
    case small
    case normal
    case large
    
    var font: Font {
        switch self {
        case .small:
            return .caption2
        case .normal:
            return .caption
        case .large:
            return .footnote
        }
    }
    
    var horizontalPadding: CGFloat {
        switch self {
        case .small:
            return 6
        case .normal:
            return 8
        case .large:
            return 12
        }
    }
    
    var verticalPadding: CGFloat {
        switch self {
        case .small:
            return 2
        case .normal:
            return 4
        case .large:
            return 6
        }
    }
    
    var cornerRadius: CGFloat {
        switch self {
        case .small:
            return 4
        case .normal:
            return 6
        case .large:
            return 8
        }
    }
}

// MARK: - Status Extensions

extension CitationStatus {
    /// User-friendly display name for the status
    public var displayName: String {
        switch self {
        case .pending:
            return "Pending"
        case .valid:
            return "Valid"
        case .invalid:
            return "Invalid"
        case .error:
            return "Error"
        }
    }
    
    /// Color associated with the status
    public var color: Color {
        switch self {
        case .pending:
            return .gray
        case .valid:
            return .green
        case .invalid:
            return .red
        case .error:
            return .orange
        }
    }
    
    /// System image name for the status
    public var systemImage: String {
        switch self {
        case .pending:
            return "clock"
        case .valid:
            return "checkmark.circle.fill"
        case .invalid:
            return "xmark.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }
}

extension CaseNameStatus {
    /// User-friendly display name for the status
    public var displayName: String {
        switch self {
        case .pending:
            return "Pending"
        case .valid:
            return "Valid"
        case .partiallyValid:
            return "Found"
        case .invalid:
            return "Invalid"
        case .error:
            return "Error"
        }
    }
    
    /// Color associated with the status
    public var color: Color {
        switch self {
        case .pending:
            return .gray
        case .valid:
            return .green
        case .partiallyValid:
            return .yellow
        case .invalid:
            return .red
        case .error:
            return .orange
        }
    }
    
    /// System image name for the status
    public var systemImage: String {
        switch self {
        case .pending:
            return "clock"
        case .valid:
            return "checkmark.circle.fill"
        case .partiallyValid:
            return "questionmark.circle.fill"
        case .invalid:
            return "xmark.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Validation Badges") {
    VStack(spacing: 10) {
        Text("Citation Status Badges")
            .font(.headline)
        
        HStack(spacing: 10) {
            ValidationBadge(status: CitationStatus.pending, size: .small)
            ValidationBadge(status: CitationStatus.valid, size: .small)
            ValidationBadge(status: CitationStatus.invalid, size: .small)
            ValidationBadge(status: CitationStatus.error, size: .small)
        }
        
        HStack(spacing: 10) {
            ValidationBadge(status: CitationStatus.pending)
            ValidationBadge(status: CitationStatus.valid)
            ValidationBadge(status: CitationStatus.invalid)
            ValidationBadge(status: CitationStatus.error)
        }
        
        HStack(spacing: 10) {
            ValidationBadge(status: CitationStatus.pending, size: .large)
            ValidationBadge(status: CitationStatus.valid, size: .large)
            ValidationBadge(status: CitationStatus.invalid, size: .large)
            ValidationBadge(status: CitationStatus.error, size: .large)
        }
    }
    .padding()
}
#endif 