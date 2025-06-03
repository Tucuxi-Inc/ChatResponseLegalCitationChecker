import Foundation

#if canImport(PDFKit)
import PDFKit
#endif

#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

/// Represents possible errors that can occur during document parsing
public enum DocumentParserError: Error, LocalizedError {
    /// The file type is not supported by the parser
    case unsupportedFileType
    /// An error occurred while parsing the document
    case parsingError(String)
    /// PDFKit is not available on this platform
    case pdfKitUnavailable
    
    public var errorDescription: String? {
        switch self {
        case .unsupportedFileType:
            return "The file type is not supported by the parser"
        case .parsingError(let message):
            return "An error occurred while parsing the document: \(message)"
        case .pdfKitUnavailable:
            return "PDF parsing is not available on this platform"
        }
    }
}

/// A service class responsible for parsing different types of documents and extracting legal citations
public class DocumentParser {
    /// Shared instance of the DocumentParser for use throughout the application
    public static let shared = DocumentParser()
    
    /// Private initializer to enforce singleton pattern
    private init() {}
    
    /// Parses a document at the given URL and extracts legal citations
    public func parseDocument(at url: URL) async throws -> String {
        let fileType = try getFileType(from: url)
        
        switch fileType {
        case .pdf:
            return try await parsePDF(at: url)
        case .word, .docx:
            return try await parseWord(at: url)
        case .plainText:
            return try await parseText(at: url)
        default:
            throw DocumentParserError.unsupportedFileType
        }
    }
    
    /// Determines the file type of a document at the given URL
    private func getFileType(from url: URL) throws -> UTType {
        #if canImport(UniformTypeIdentifiers)
        guard let fileType = try url.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier,
              let utType = UTType(fileType) else {
            throw DocumentParserError.unsupportedFileType
        }
        
        if utType.conforms(to: .pdf) {
            return .pdf
        } else if utType.conforms(to: .word) || utType.conforms(to: .docx) {
            return .word
        } else if utType.conforms(to: .plainText) {
            return .plainText
        } else {
            throw DocumentParserError.unsupportedFileType
        }
        #else
        // Fallback for platforms without UniformTypeIdentifiers
        let pathExtension = url.pathExtension.lowercased()
        switch pathExtension {
        case "pdf":
            return .pdf
        case "doc", "docx":
            return .word
        case "txt", "text":
            return .plainText
        default:
            throw DocumentParserError.unsupportedFileType
        }
        #endif
    }
    
    /// Parses a PDF document and extracts its text content
    private func parsePDF(at url: URL) async throws -> String {
        #if canImport(PDFKit)
        guard let pdf = PDFDocument(url: url) else {
            throw DocumentParserError.parsingError("Could not open PDF file")
        }
        
        var text = ""
        for i in 0..<pdf.pageCount {
            if let page = pdf.page(at: i) {
                text += page.string ?? ""
            }
        }
        return cleanAndExtractCitations(from: text)
        #else
        throw DocumentParserError.pdfKitUnavailable
        #endif
    }
    
    /// Parses a Word document and extracts its text content
    private func parseWord(at url: URL) async throws -> String {
        do {
            let data = try Data(contentsOf: url)
            
            // Try different encodings
            let encodings: [String.Encoding] = [.utf8, .ascii, .utf16, .isoLatin1]
            
            for encoding in encodings {
                if let text = String(data: data, encoding: encoding) {
                    return cleanAndExtractCitations(from: text)
                }
            }
            
            throw DocumentParserError.parsingError("Could not extract text from Word document")
        } catch {
            throw DocumentParserError.parsingError("Could not read Word document: \(error.localizedDescription)")
        }
    }
    
    /// Parses a plain text document
    private func parseText(at url: URL) async throws -> String {
        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            return cleanAndExtractCitations(from: text)
        } catch {
            throw DocumentParserError.parsingError("Could not read text file: \(error.localizedDescription)")
        }
    }
    
    /// Cleans and extracts legal citations from text content
    public func cleanAndExtractCitations(from text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        var cleanedLines: [String] = []
        
        // Citation patterns
        let citationPattern = #"([A-Za-z\s]+(?:\s+v\.\s+[A-Za-z\s]+)?),\s*(\d+\s+[A-Z\.]+\s+\d+)\s*\(([^)]+)\)"#
        let caseNamePattern = #"([A-Za-z\s]+(?:\s+(?:v\.|vs\.|versus)\s+[A-Za-z\s]+))"#
        let westlawPattern = #"(\d{4}\s+WL\s+\d+)"#
        let reporterPattern = #"(\d+\s+[A-Z\.]+\s+\d+)"#
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip empty lines and common headers
            if trimmedLine.isEmpty ||
               trimmedLine.contains("FILED") ||
               trimmedLine.contains("Page") ||
               trimmedLine.contains("Case No.") ||
               trimmedLine.contains("ORDER") {
                continue
            }
            
            // Look for citations
            if let range = trimmedLine.range(of: citationPattern, options: .regularExpression) {
                cleanedLines.append(String(trimmedLine[range]))
            } else if let range = trimmedLine.range(of: caseNamePattern, options: .regularExpression) {
                let caseName = String(trimmedLine[range])
                if !cleanedLines.contains(caseName) {
                    cleanedLines.append(caseName)
                }
            } else if let range = trimmedLine.range(of: westlawPattern, options: .regularExpression) {
                cleanedLines.append(String(trimmedLine[range]))
            } else if let range = trimmedLine.range(of: reporterPattern, options: .regularExpression) {
                cleanedLines.append(String(trimmedLine[range]))
            }
        }
        
        let uniqueLines = Array(NSOrderedSet(array: cleanedLines)) as? [String] ?? cleanedLines
        return uniqueLines.joined(separator: "\n")
    }
}

#if canImport(UniformTypeIdentifiers)
extension UTType {
    public static let word = UTType("com.microsoft.word.doc")!
    public static let docx = UTType("org.openxmlformats.wordprocessingml.document")!
}
#else
public struct UTType {
    let identifier: String
    
    init(_ identifier: String) {
        self.identifier = identifier
    }
    
    static let pdf = UTType("com.adobe.pdf")
    static let word = UTType("com.microsoft.word.doc")
    static let docx = UTType("org.openxmlformats.wordprocessingml.document")
    static let plainText = UTType("public.plain-text")
    
    func conforms(to type: UTType) -> Bool {
        return self.identifier == type.identifier
    }
}
#endif 