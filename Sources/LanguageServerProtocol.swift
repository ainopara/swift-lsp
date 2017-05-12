/*
 * This implements the necessary components for implementing the v3.0 'Language Server Protocol'
 * as defined here: https://github.com/Microsoft/language-server-protocol/. 
 *
 * This is a common, JSON-RPC based protocol used to define interactions between a client endpoint,
 * such as a code editor, and a language server instance that is running. The transport mechanism
 * is not defined, nor is the language the server is running against.
 *
 * Copyright (c) Kiad Studios, LLC. All rights reserved.
 * Licensed under the MIT License. See License in the project root for license information.
 */

// The type of data that is send from the `InputBuffer`.
public typealias MessageData = [UInt8]

/// Defines the body of the message contract defined in the `Language Server Protocol`. This
/// provides one additional layer of provide a `data` agnostic approach to passing the data around.
/// While the spec call for JSON-RPC only, this `Message` allows authors to provide a different
/// implementation of a transport mechanism vai the `MessageProtocol` protocol for efficiency
/// purposes.
public struct Message {
    /// The details for the message header.
    let header: MessageHeader

    /// The set of data that is coming as part of the message body. The size of this data is defined
    /// as the the `Content-Length` field within the message header. The encoding of this data
    /// should be defined with the `Content-Type` field within the message header; this defaults to
    /// UTF8.
    let content: MessageData
}

/// The header for all messages.
public struct MessageHeader {
    /// The key for the `Content-Length` property. This is one of the supported header fields.
    public static let contentLengthKey = "Content-Length"

    /// The key for the `Content-Type` property. This is one of the supported header fields.
    public static let contentTypeKey = "Content-Type"

    /// All message headers must be terminated with the sequence of `\r\n\r\n` as per spec.
    /// NOTE: There is discussion about allowing other terminators like `\n\n` as well. This parser
    /// implementation will allow for both `\n\n` and `\r\r` as a convenience. However, when
    /// serializing the header out, the standard `\r\n\r\n` will be used.
    public static let messageHeaderSeparator = "\r\n\r\n"

    /// The default value for the `Content-Type` field if one is not explicitly given.
    public static let defaultContentType = "application/vscode-jsonrpc; charset=utf-8"

    /// The set of header fields. This parser will parse all header field values, not just those
    /// defined in the spec. Note that all values will be held as a string, any type coercion must
    /// be handled by the message consumer.
    public var headerFields: [String:String] = [:]

    /// Retrieves the value of `Content-Length` from `headerFields`.
    public var contentLength: Int {
        if let length = headerFields[MessageHeader.contentLengthKey] {
            return Int(length) ?? 0
        }

        return 0
    }

    /// Retrieves the value of the `Content-Type` from `headerFields` or the default value.
    public var contentType: String {
        return headerFields[MessageHeader.contentTypeKey] ?? MessageHeader.defaultContentType
    }
}

/// The bottom layer in the messaging stack that is the source of the raw message data.
public protocol InputBuffer {
    /// Starts listening for new messages to come in. Whenever a message comes in, the `received`
    /// closure is invoked.
    /// Implementation note: this function is intended to spawn a new thread for handling incoming
    /// message data. As such, this is a non-blocking function call.
    func run(received: @escaping (Message) -> MessageData?)

    /// Used to signal that the message source should stop processing input feeds.
    func stop()
}

/// A message protocol is a layer that is used to convert an incoming message of type `MessageData`
/// into a usable `LanguageServerCommand`. If that message cannot be converted, then the `translate`
/// function will throw.
public protocol MessageProtocol {
    /// The internal type representation of the message content for the protocol.
    associatedtype ProtocolMessageType

    /// The form for all message parsers. If the raw message data cannot be converted into a 
    /// `LanguageServerCommand`, the parser should throw with a detailed error message.
    typealias MessageParser = (ProtocolMessageType) throws -> LanguageServerCommand

    /// The registration table for all of the commands that can be handled via this protocol.
    var protocols: [String:MessageParser] { get }

    /// Translates the data from the raw `MessageData` to a valid `ProtocolDataType`. This function
    /// can throw, providing detailed error information about why the transformation could not be
    /// done.
    func translate(message: Message) throws -> LanguageServerCommand

    /// Translates the response into a raw `MessageData`. This function can throw, providing detailed
    /// error information about why the transformation could not be done.
    func translate(response: ResponseMessage) throws -> MessageData
}

/// Defines the API to describe a command for the language server.
public enum LanguageServerCommand {
    case initialize(requestId: RequestId?, params: InitializeParams)
    case initialized(requestId: RequestId?)
    case shutdown(requestId: RequestId?)
    case exit(requestId: RequestId?)
    case cancelRequest(requestId: RequestId?, params: CancelParams)

    case windowShowMessage(requestId: RequestId?, params: ShowMessageParams)
    case windowShowMessageRequest(requestId: RequestId?, params: ShowMessageRequestParams)
    case windowLogMessage(requestId: RequestId?, params: LogMessageParams)
    case telemetryEvent(requestId: RequestId?, params: Any)

    case clientRegisterCapability(requestId: RequestId?, params: RegistrationParams)
    case clientUnregisterCapability(requestId: RequestId?, params: UnregistrationParams)

    case workspaceDidChangeConfiguration(requestId: RequestId?, params: DidChangeConfigurationParams)
    case workspaceDidChangeWatchedFiles(requestId: RequestId?, params: DidChangeWatchedFilesParams)
    case workspaceSymbol(requestId: RequestId?, params: WorkspaceSymbolParams)
    case workspaceExecuteCommand(requestId: RequestId?, params: ExecuteCommandParams)
    case workspaceApplyEdit(requestId: RequestId?, params: ApplyWorkspaceEditParams)

    case textDocumentPublishDiagnostics(requestId: RequestId?, params: PublishDiagnosticsParams)
    case textDocumentDidOpen(requestId: RequestId?, params: DidOpenTextDocumentParams)
    case textDocumentDidChange(requestId: RequestId?, params: DidChangeTextDocumentParams)
    case textDocumentWillSave(requestId: RequestId?, params: WillSaveTextDocumentParams)
    case textDocumentWillSaveWaitUntil(requestId: RequestId?, params: WillSaveTextDocumentParams)
    case textDocumentDidSave(requestId: RequestId?, params: DidSaveTextDocumentParams)
    case textDocumentDidClose(requestId: RequestId?, params: DidCloseTextDocumentParams)
    case textDocumentCompletion(requestId: RequestId?, params: TextDocumentPositionParams)
    case completionItemResolve(requestId: RequestId?, params: CompletionItem)
    case textDocumentHover(requestId: RequestId?, params: TextDocumentPositionParams)
    case textDocumentSignatureHelp(requestId: RequestId?, params: TextDocumentPositionParams)
    case textDocumentReferences(requestId: RequestId?, params: ReferenceParams)
    case textDocumentDocumentHighlight(requestId: RequestId?, params: TextDocumentPositionParams)
    case textDocumentDocumentSymbol(requestId: RequestId?, params: DocumentSymbolParams)
    case textDocumentFormatting(requestId: RequestId?, params: DocumentFormattingParams)
    case textDocumentRangeFormatting(requestId: RequestId?, params: DocumentRangeFormattingParams)
    case textDocumentOnTypeFormatting(requestId: RequestId?, params: DocumentOnTypeFormattingParams)
    case textDocumentDefinition(requestId: RequestId?, params: TextDocumentPositionParams)
    case textDocumentCodeAction(requestId: RequestId?, params: CodeActionParams)
    case textDocumentCodeLens(requestId: RequestId?, params: CodeLensParams)
    case codeLensResolve(requestId: RequestId?, params: CodeLens)
    case textDocumentDocumentLink(requestId: RequestId?, params: DocumentLinkParams)
    case documentLinkResolve(requestId: RequestId?, params: DocumentLink)
    case textDocumentRename(requestId: RequestId?, params: RenameParams)
}

/// Helper to convert the message into a printable output.
extension Message: CustomStringConvertible {
    public var description: String {
        var output = ""
        for (key, value) in self.header.headerFields {
            output += "\(key): \(value)\r\n"
        }

        let content = String(bytes: self.content, encoding: .utf8) ?? "<error converting content>"
        output += "\r\n\(content)"

        return output
    }
}

/// This is a utility class that provides a queueing mechanism for incoming messages. This is
/// exposed publicly to allow other authors of an `InputBuffer` to share this logic as this should
/// be shared across all implementations. This class takes a given set of raw bytes that comes in
/// and parses those into the header and content parts. So long as the messages data follows the
/// spec for VS Code encoded messages, this will work regardless of the internal format that is
/// chosen for the data within the message.
public final class MessageBuffer {
    /// The local cache of bytes that has been read so far.
    private var buffer: [UInt8] = []

    /// Exposing publicly...
    public init() {}

    /// Appends the data to the current set of data. If possible, any messages that can be parsed out
    /// of all of the received data will be returned. Once a message is returned, its content is
    /// removed from the internal buffer.
    public func write(data: MessageData) -> [Message] {
        buffer += data

        var messages: [Message] = []

        do {
            while (true) {
                if let (header, headerSize) = try parse(header: buffer) {
                    if let (content, contentSize) = try parse(header: header, offset: headerSize, body: buffer) {
                        messages.append(Message(header: header, content: content))
                        buffer = [UInt8](buffer.dropFirst(contentSize + headerSize))
                        continue
                    }
                }

                break
            }
        }
        catch {
            fatalError("content is incorrect...")
        }

        return messages
    }

    private func parse(header buffer: [UInt8]) throws -> (MessageHeader, Int)? {
        enum ParserState {
            case field
            case value
        }

        func isNewline(_ c: Character) -> Bool {
            return c == "\n" || c == "\r" || c == "\r\n"
        }

        func isValidHeaderFieldCharacter(_ c: Character) -> Bool {
            return (UnicodeScalar("\(c)")?.isASCII ?? false) && c != ":" && !isNewline(c)
        }

        func isValidHeaderValueCharacter(_ c: Character) -> Bool {
            return (UnicodeScalar("\(c)")?.isASCII ?? false) && !isNewline(c)
        }       

        var header = MessageHeader()
        var field = ""
        var value = ""

        var state = ParserState.field
        var headerSize = 0
        var skip = false

        for (index, byte) in buffer.enumerated() {
            headerSize += 1
            if skip { skip = false; continue }

            let c = Character(UnicodeScalar(byte))

            switch state {
            case .field:
                if isValidHeaderFieldCharacter(c) {
                    field += "\(c)"
                }
                else if c == ":" {
                    state = .value
                    value = ""
                }
                else if c == "\r" {
                    if let next = buffer.at(index + 1) {
                        let nextC = Character(UnicodeScalar(next))
                        if nextC == "\n" {
                            headerSize += 1
                        }
                    }
                    return (header, headerSize)
                }
                else if c == "\n" {
                    return (header, headerSize)
                }
                else {
                    throw "The value '\(c)' is not expected or allowed here."
                }

            case .value:
                if isValidHeaderValueCharacter(c) {
                    value += "\(c)"
                }
                else if c == "\r" || c == "\n" {
                    if c == "\r" {
                        if let next = buffer.at(index + 1) {
                            let nextC = Character(UnicodeScalar(next))
                            if nextC == "\n" {
                                skip = true
                            }
                        }
                    }

                    value = value.trimmingCharacters(in: .whitespaces)
                    if value != "" {
                        header.headerFields[field] = value
                        state = .field
                        field = ""
                    }
                    else {
                        throw "An empty value is not supported."
                    }
                }
            }
        }

        return nil
    }

    private func parse(header: MessageHeader, offset: Int, body buffer: [UInt8]) throws -> (MessageData, Int)? {
        let length = header.contentLength
        if length <= 0 { throw "Invalid content length: \(length)" }
        let messageSize = offset + length
        if buffer.count < messageSize { return nil }

        return ([UInt8](buffer[offset..<messageSize]), length)
    }
}