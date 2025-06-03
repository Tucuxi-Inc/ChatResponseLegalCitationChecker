import Foundation

// MARK: - CourtListener API Response Models

// Represents a response from the citation validation endpoint
public struct CitationResponse: Codable, Sendable {
    // The original citation that was validated
    public let citation: String
    // Standardized versions of the citation
    public let normalizedCitations: [String]
    // Where the citation starts in the input text
    public let startIndex: Int
    // Where the citation ends in the input text
    public let endIndex: Int
    // The HTTP status code from the API
    public let status: Int
    // Any error message from the API
    public let errorMessage: String
    // The matching cases found in CourtListener
    public let clusters: [Cluster]
    
    enum CodingKeys: String, CodingKey {
        case citation
        case normalizedCitations = "normalized_citations"
        case startIndex = "start_index"
        case endIndex = "end_index"
        case status
        case errorMessage = "error_message"
        case clusters
    }
    
    public var description: String {
        return "Citation: \(citation), Status: \(status), Clusters: \(clusters.count)"
    }
}

// Represents a response from the case search endpoint
public struct CaseSearchResponse: Codable, Sendable {
    // Total number of cases found
    public let count: Int
    // The list of matching cases
    public let results: [CaseResult]
    
    public var description: String {
        return "Count: \(count), Results: \(results.count)"
    }
}

// Model for case search results
public struct CaseResult: Codable, Sendable {
    public let caseName: String
    public let citation: [String]
    public let absoluteUrl: String
    public let clusterId: Int
    public let court: String
    public let dateFiled: String
    
    enum CodingKeys: String, CodingKey {
        case caseName = "caseName"
        case citation = "citation"
        case absoluteUrl = "absolute_url"
        case clusterId = "cluster_id"
        case court = "court"
        case dateFiled = "dateFiled"
    }
}

// Model for search response
public struct SearchResponse: Codable, Sendable {
    public let count: Int
    public let next: String?
    public let previous: String?
    public let results: [CaseResult]
}

// Represents a cluster (case) in CourtListener
public struct Cluster: Codable, Sendable {
    // The unique identifier for the case
    public let id: Int
    // The name of the case
    public let caseName: String
    // The URL to view the case on CourtListener
    public let absoluteUrl: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case caseName = "case_name"
        case absoluteUrl = "absolute_url"
    }
    
    // Converts the numeric ID to a string for storage
    public var stringId: String {
        return String(id)
    }
    
    public var description: String {
        return "ID: \(id), Case: \(caseName)"
    }
}

// Represents a response from the opinion text endpoint
public struct OpinionResponse: Codable, Sendable {
    // The unique identifier for the opinion
    public let id: Int
    // The name of the case
    public let caseName: String
    // The citation for the case
    public let citation: String
    // The URL to view the case on CourtListener
    public let absoluteUrl: String
    // The full text of the opinion
    public let plainText: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case caseName = "case_name"
        case citation
        case absoluteUrl = "absolute_url"
        case plainText = "plain_text"
    }
    
    public var description: String {
        return "ID: \(id), Case: \(caseName), Citation: \(citation)"
    }
}

// MARK: - Error Types

// Errors that can occur when interacting with the CourtListener API
public enum CourtListenerAPIError: Error, LocalizedError, Sendable {
    case invalidURL           // The API URL is not valid
    case invalidResponse      // The API returned an unexpected response
    case invalidData         // The API returned data that couldn't be processed
    case unauthorized        // The API token is invalid or missing
    case rateLimitExceeded   // Too many requests to the API
    case serverError(Int)    // The server returned an error with the given status code
    case unknown(String)     // Any other error that might occur
    case forbidden           // The API token is forbidden
    case networkError(Error) // Network connectivity issues
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The API URL is not valid"
        case .invalidResponse:
            return "The API returned an unexpected response"
        case .invalidData:
            return "The API returned data that couldn't be processed"
        case .unauthorized:
            return "The API token is invalid or missing"
        case .rateLimitExceeded:
            return "Too many requests to the API. Please try again later."
        case .serverError(let code):
            return "Server error with status code: \(code)"
        case .unknown(let message):
            return "Unknown error: \(message)"
        case .forbidden:
            return "The API token is forbidden"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
} 