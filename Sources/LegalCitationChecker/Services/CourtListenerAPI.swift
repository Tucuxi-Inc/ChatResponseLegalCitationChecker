import Foundation

// A service that handles all communication with the CourtListener API
// This is implemented as an actor to ensure thread-safe access to the API token
// and to prevent multiple simultaneous API calls from interfering with each other
public actor CourtListenerAPI {
    // The base URL for all CourtListener API requests
    private let baseURL = "https://www.courtlistener.com/api/rest/v4"
    // The API token used to authenticate requests
    private var apiToken: String?
    
    // A shared instance of the API client that can be used throughout the app
    public static let shared = CourtListenerAPI()
    
    // Private initializer to ensure we only use the shared instance
    private init() {}
    
    // Sets the API token that will be used for all future requests
    public func setAPIToken(_ token: String) {
        print("\n=== Setting API Token ===")
        print("Token length: \(token.count) characters")
        print("Token preview: \(token.prefix(8))...")
        self.apiToken = token
        print("✅ API token successfully set")
        print("Has valid token after setting: \(hasValidToken())")
    }
    
    // Gets the current API token status
    public func hasValidToken() -> Bool {
        let hasToken = apiToken != nil && !apiToken!.isEmpty
        print("🔍 Token check - Has token: \(hasToken)")
        if let token = apiToken {
            print("🔍 Token preview: \(token.prefix(8))...")
        } else {
            print("🔍 Token is nil")
        }
        return hasToken
    }
    
    // Creates a URLRequest with the proper headers and authentication
    private func createRequest(_ endpoint: String, method: String = "GET") throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)/\(endpoint)") else {
            throw CourtListenerAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = apiToken {
            request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
        }
        
        print("Creating request for endpoint: \(endpoint)")
        print("URL: \(url)")
        print("Method: \(method)")
        print("Headers: \(request.allHTTPHeaderFields ?? [:])")
        
        return request
    }
    
    // Validates a citation by checking it against CourtListener's database
    public func validateCitation(_ citation: String) async throws -> [CitationResponse] {
        print("\nValidating citation: \(citation)")
        
        guard hasValidToken() else {
            throw CourtListenerAPIError.unauthorized
        }
        
        var request = try createRequest("citation-lookup/", method: "POST")
        let body = ["text": citation]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        print("Request body: \(String(data: request.httpBody!, encoding: .utf8) ?? "")")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw CourtListenerAPIError.invalidResponse
            }
            
            print("Response status code: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("Response data: \(responseString)")
            }
            
            switch httpResponse.statusCode {
            case 200:
                let decodedResponse = try JSONDecoder().decode([CitationResponse].self, from: data)
                print("Decoded response: \(decodedResponse)")
                return decodedResponse
            case 401:
                throw CourtListenerAPIError.unauthorized
            case 403:
                throw CourtListenerAPIError.forbidden
            case 429:
                throw CourtListenerAPIError.rateLimitExceeded
            default:
                throw CourtListenerAPIError.serverError(httpResponse.statusCode)
            }
        } catch let error as CourtListenerAPIError {
            throw error
        } catch {
            throw CourtListenerAPIError.networkError(error)
        }
    }
    
    // Searches for a case by name
    public func searchCaseName(_ caseName: String) async throws -> [CaseResult] {
        print("Searching case name: \(caseName)")
        
        guard hasValidToken() else {
            throw CourtListenerAPIError.unauthorized
        }
        
        let encodedCaseName = caseName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? caseName
        let urlString = "\(baseURL)/search/?type=o&case_name=\(encodedCaseName)"
        print("Search URL: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            throw CourtListenerAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Token \(apiToken ?? "")", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Use the retry logic
        let searchResponse: SearchResponse = try await performRequestWithRetry(
            request: request,
            responseType: SearchResponse.self
        )
        
        print("Found \(searchResponse.count) results")
        return searchResponse.results
    }
    
    // Retrieves the full text of a court opinion
    public func getOpinionText(clusterId: String) async throws -> OpinionResponse {
        print("\nGetting opinion text for cluster ID: \(clusterId)")
        
        guard hasValidToken() else {
            throw CourtListenerAPIError.unauthorized
        }
        
        let request = try createRequest("clusters/\(clusterId)/")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw CourtListenerAPIError.invalidResponse
            }
            
            print("Response status code: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("Response data: \(responseString)")
            }
            
            switch httpResponse.statusCode {
            case 200:
                let decodedResponse = try JSONDecoder().decode(OpinionResponse.self, from: data)
                print("Decoded response: \(decodedResponse)")
                return decodedResponse
            case 401:
                throw CourtListenerAPIError.unauthorized
            case 403:
                throw CourtListenerAPIError.forbidden
            case 429:
                throw CourtListenerAPIError.rateLimitExceeded
            default:
                throw CourtListenerAPIError.serverError(httpResponse.statusCode)
            }
        } catch let error as CourtListenerAPIError {
            throw error
        } catch {
            throw CourtListenerAPIError.networkError(error)
        }
    }
    
    // Looks up citations in a blob of text using the citation-lookup endpoint
    public func lookupCitationsInText(_ text: String) async throws -> [CitationResponse] {
        print("\n=== Starting lookupCitationsInText ===")
        print("Text length: \(text.count) characters")
        
        guard let url = URL(string: "\(baseURL)/citation-lookup/") else {
            print("❌ Invalid URL")
            throw CourtListenerAPIError.invalidURL
        }
        
        guard hasValidToken(), let token = apiToken else {
            print("❌ No valid API token")
            throw CourtListenerAPIError.unauthorized
        }
        
        print("✅ API token present")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Create the JSON body
        let body = ["text": text]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        print("Request details:")
        print("URL: \(url)")
        print("Method: \(request.httpMethod ?? "unknown")")
        print("Headers: \(request.allHTTPHeaderFields ?? [:])")
        print("Body length: \(request.httpBody?.count ?? 0) bytes")
        
        // Use the retry logic
        return try await performRequestWithRetry(
            request: request,
            responseType: [CitationResponse].self
        )
    }
    
    // Health check method to verify API connectivity and token validity
    public func healthCheck() async throws -> Bool {
        guard hasValidToken() else {
            throw CourtListenerAPIError.unauthorized
        }
        
        // Use a simple endpoint to test connectivity
        let request = try createRequest("search/?type=o&q=test")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw CourtListenerAPIError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200:
                return true
            case 401:
                throw CourtListenerAPIError.unauthorized
            case 403:
                throw CourtListenerAPIError.forbidden
            case 429:
                throw CourtListenerAPIError.rateLimitExceeded
            default:
                throw CourtListenerAPIError.serverError(httpResponse.statusCode)
            }
        } catch let error as CourtListenerAPIError {
            throw error
        } catch {
            throw CourtListenerAPIError.networkError(error)
        }
    }
    
    // Performs a request with retry logic for better reliability
    private func performRequestWithRetry<T: Decodable>(
        request: URLRequest,
        responseType: T.Type,
        maxAttempts: Int = 3,
        delay: TimeInterval = 1.0
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 1...maxAttempts {
            do {
                print("🔄 Attempt \(attempt) of \(maxAttempts)")
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw CourtListenerAPIError.invalidResponse
                }
                
                print("Response status code: \(httpResponse.statusCode)")
                
                switch httpResponse.statusCode {
                case 200:
                    let decodedResponse = try JSONDecoder().decode(responseType, from: data)
                    print("✅ Successfully decoded response on attempt \(attempt)")
                    return decodedResponse
                case 401:
                    // Don't retry on authentication errors
                    throw CourtListenerAPIError.unauthorized
                case 403:
                    // Don't retry on forbidden errors
                    throw CourtListenerAPIError.forbidden
                case 429:
                    throw CourtListenerAPIError.rateLimitExceeded
                default:
                    throw CourtListenerAPIError.serverError(httpResponse.statusCode)
                }
            } catch {
                lastError = error
                
                // Don't retry on certain errors
                if let apiError = error as? CourtListenerAPIError {
                    switch apiError {
                    case .unauthorized, .forbidden:
                        throw error
                    default:
                        break
                    }
                }
                
                // Wait before retrying (except on last attempt)
                if attempt < maxAttempts {
                    print("⏳ Waiting \(delay) seconds before retry...")
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? CourtListenerAPIError.unknown("Request failed after \(maxAttempts) attempts")
    }
} 