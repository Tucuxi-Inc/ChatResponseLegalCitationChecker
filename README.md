# Legal Citation Checker

A Swift package that provides legal citation validation and checking functionality for macOS and iOS apps. This package integrates with the CourtListener API to validate legal citations and case names in text.

## Features

- 🔍 Citation validation against CourtListener API
- 📝 Case name validation and lookup
- 🎯 Citation highlighting and formatting
- 📊 Detailed validation results
- 🎨 Beautiful SwiftUI components
- 🔄 Support for both manual and automatic checking
- 📄 Document processing capabilities
- 🛠️ Easy integration with existing apps

## Requirements

- iOS 16.0+ / macOS 13.0+
- Swift 5.9+
- Xcode 15.0+
- CourtListener API token

## Installation

### Swift Package Manager

Add the package to your Xcode project:

1. In Xcode, select File > Add Packages...
2. Enter the repository URL: `https://github.com/Kevin-Tucuxi/ChatResponseLegalCitationChecker.git`
3. Select the version you want to use
4. Click Add Package

Or add it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Kevin-Tucuxi/ChatResponseLegalCitationChecker.git", from: "1.0.0")
]
```

## Usage

### Basic Integration

Add the citation checker button to any view:

```swift
import LegalCitationCheckerUI

struct YourView: View {
    let messageText: String
    let apiToken: String
    
    var body: some View {
        HStack {
            Text(messageText)
            CitationCheckerButton(
                text: messageText,
                apiToken: apiToken
            )
        }
    }
}
```

### Automatic Citation Checking

For automatic citation checking in your app:

```swift
import LegalCitationChecker

class YourViewModel: ObservableObject {
    let citationChecker = LegalCitationChecker.shared
    
    func checkCitations(in text: String) async {
        do {
            await citationChecker.setAPIToken(yourApiToken)
            let result = try await citationChecker.validateCitations(in: text)
            // Handle the result
        } catch {
            // Handle the error
        }
    }
}
```

### Document Processing

Process and validate citations in documents:

```swift
let result = try await citationChecker.processAndValidateDocument(at: documentURL)
```

### Text Analysis

Analyze text for citations:

```swift
// Check if text contains citations
let hasCitations = citationChecker.containsCitations(text)

// Extract citations without validation
let citations = citationChecker.extractCitations(from: text)

// Find citation ranges for highlighting
let ranges = citationChecker.findCitationRanges(in: text)
```

## Configuration

### CourtListener API Token

You'll need a CourtListener API token to use this package. Get one at [CourtListener](https://www.courtlistener.com/api/rest-info/).

Set the token in your app:

```swift
await LegalCitationChecker.shared.setAPIToken(yourApiToken)
```

### Settings

The package provides several configuration options:

```swift
// Enable/disable automatic citation checking
CitationCheckerSettings.autoCheckCitations = true

// Enable/disable citation highlighting
CitationCheckerSettings.highlightCitations = true
```

## Components

### CitationCheckerButton

A reusable button component that handles citation checking and displays results:

```swift
CitationCheckerButton(
    text: "Your text here",
    apiToken: "your-api-token",
    onValidationComplete: { result in
        // Handle validation result
    }
)
```

### CitationResultsView

A view that displays citation validation results:

```swift
CitationResultsView(
    validationResult: result,
    hasError: false,
    errorMessage: ""
)
```

## Error Handling

The package provides comprehensive error handling:

```swift
do {
    let result = try await citationChecker.validateCitations(in: text)
} catch CourtListenerAPIError.invalidToken {
    // Handle invalid API token
} catch CourtListenerAPIError.networkError {
    // Handle network issues
} catch {
    // Handle other errors
}
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- [CourtListener](https://www.courtlistener.com/) for providing the API
- The legal tech community for inspiration and support 