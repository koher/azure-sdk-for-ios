// --------------------------------------------------------------------------
//
// Copyright (c) Microsoft Corporation. All rights reserved.
//
// The MIT License (MIT)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the ""Software""), to
// deal in the Software without restriction, including without limitation the
// rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
// sell copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED *AS IS*, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
// IN THE SOFTWARE.
//
// --------------------------------------------------------------------------

import AzureCommunication
import AzureCore
import Foundation

public class ChatClient {
    // MARK: Properties

    private let endpoint: String
    private let credential: CommunicationTokenCredential
    private let options: AzureCommunicationChatClientOptions
    private let service: Chat

    // MARK: Initializers

    /// Create a ChatClient.
    /// - Parameters:
    ///   - endpoint: The Communication Services endpoint.
    ///   - credential: The user credential.
    ///   - options: Options used to configure the client.
    public init(
        endpoint: String,
        credential: CommunicationTokenCredential,
        withOptions options: AzureCommunicationChatClientOptions
    ) throws {
        self.endpoint = endpoint
        self.credential = credential
        self.options = options

        guard let endpointUrl = URL(string: endpoint) else {
            throw AzureError.client("Unable to form base URL.")
        }

        let communicationCredential = CommunicationPolicyTokenCredential(credential)
        let authPolicy = BearerTokenCredentialPolicy(credential: communicationCredential, scopes: [])

        let client = try AzureCommunicationChatClient(
            endpoint: endpointUrl,
            authPolicy: authPolicy,
            withOptions: options
        )

        self.service = client.chat
    }

    // MARK: Public Methods

    /// Create a ChatThreadClient for the ChatThread with id threadId.
    /// - Parameters:
    ///   - threadId: The threadId.
    public func createClient(forThread threadId: String) throws -> ChatThreadClient {
        return try ChatThreadClient(
            endpoint: endpoint,
            credential: credential,
            threadId: threadId,
            withOptions: options
        )
    }

    /// Create a new ChatThread.
    /// - Parameters:
    ///   - thread: Request for creating a chat thread with the topic and members to add.
    ///   - options: Create chat thread options.
    ///   - completionHandler: A completion handler that receives a ChatThreadClient on success.
    public func create(
        thread: CreateThreadRequest,
        withOptions options: Chat.CreateChatThreadOptions? = nil,
        completionHandler: @escaping HTTPResultHandler<CreateThreadResult>
    ) {
        // Set the repeatabilityRequestID if it is not provided
        let requestOptions = ((options?.repeatabilityRequestID) != nil) ? options : Chat.CreateChatThreadOptions(
            repeatabilityRequestID: UUID().uuidString,
            clientRequestId: options?.clientRequestId,
            cancellationToken: options?.cancellationToken,
            dispatchQueue: options?.dispatchQueue,
            context: options?.context
        )

        // Convert Participants to ChatParticipants
        let participants = thread.participants.map {
            ChatParticipant(
                id: $0.user.identifier,
                displayName: $0.displayName,
                shareHistoryTime: $0.shareHistoryTime
            )
        }

        // Convert to CreateChatThreadRequest for generated code
        let request = CreateChatThreadRequest(
            topic: thread.topic,
            participants: participants
        )

        service.create(chatThread: request, withOptions: requestOptions) { result, httpResponse in
            switch result {
            case let .success(chatThreadResult):
                completionHandler(.success(CreateThreadResult(from: chatThreadResult)), httpResponse)

            case let .failure(error):
                completionHandler(.failure(error), httpResponse)
            }
        }
    }

    /// Get the Thread with given id.
    /// - Parameters:
    ///   - threadId: The chat thread id.
    ///   - options: Get chat thread options.
    ///   - completionHandler: A completion handler that receives the chat thread on success.
    public func get(
        thread threadId: String,
        withOptions options: Chat.GetChatThreadOptions? = nil,
        completionHandler: @escaping HTTPResultHandler<Thread>
    ) {
        service.getChatThread(chatThreadId: threadId, withOptions: options) { result, httpResponse in
            switch result {
            case let .success(chatThread):
                completionHandler(.success(Thread(from: chatThread)), httpResponse)

            case let .failure(error):
                completionHandler(.failure(error), httpResponse)
            }
        }
    }

    /// Gets the list of ChatThreads for the user.
    /// - Parameters:
    ///   - options: List chat threads options.
    ///   - completionHandler: A completion handler that receives the list of chat thread info on success.
    public func listThreads(
        withOptions options: Chat.ListChatThreadsOptions? = nil,
        completionHandler: @escaping HTTPResultHandler<PagedCollection<ChatThreadInfo>>
    ) {
        service.listChatThreads(withOptions: options) { result, httpResponse in
            switch result {
            case let .success(chatThreads):
                completionHandler(.success(chatThreads), httpResponse)

            case let .failure(error):
                completionHandler(.failure(error), httpResponse)
            }
        }
    }

    /// Delete the ChatThread with id chatThreadId.
    /// - Parameters:
    ///   - threadId: The chat thread id.
    ///   - options: Delete chat thread options.
    ///   - completionHandler: A completion handler.
    public func delete(
        thread threadId: String,
        withOptions options: Chat.DeleteChatThreadOptions? = nil,
        completionHandler: @escaping HTTPResultHandler<Void>
    ) {
        service.deleteChatThread(chatThreadId: threadId, withOptions: options) { result, httpResponse in
            switch result {
            case .success:
                completionHandler(.success(()), httpResponse)

            case let .failure(error):
                completionHandler(.failure(error), httpResponse)
            }
        }
    }
}
