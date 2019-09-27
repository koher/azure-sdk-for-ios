//
//  PagedCollection.swift
//  AzureCore
//
//  Created by Travis Prescott on 9/19/19.
//  Copyright © 2019 Azure SDK Team. All rights reserved.
//

import Foundation
import os.log

// MARK: Paged Collection

/// Defines the property keys used to conform to the Azure paging design.
public struct PagedCodingKeys {
    public let items: String
    public let continuationToken: String

    public init(items: String = "items", continuationToken: String = "continuationToken") {
        self.items = items
        self.continuationToken = continuationToken
    }
}

/// A collection that fetches paged results in a lazy fashion.
public class PagedCollection<SingleElement: Codable>: Sequence, IteratorProtocol {

    public typealias Element = [SingleElement]

    private var _items: Element?

    /// Returns the current running list of items.
    public var items: Element? {
        return _items
    }

    private var pageRange: Range<Int>?

    /// Returns the subset of items that corresponds to the current page.
    public var pageItems: Element? {
        guard let range = pageRange else { return nil }
        guard let slice = _items?[range] else { return nil }
        return Array(slice)
    }

    /// The continuation token used to fetch the next page of results.
    private var continuationToken: String?

    /// An index which tracks the next item to be returned when using the nextItem method.
    private var iteratorIndex: Int = 0

    /// A reference to the configured client that created the PagedCollection. Needed to make follow-up
    /// calls to retrieve additional pages.
    private let client: PipelineClient

    /// Key values needed to deserialize the service response into items and a continuation token.
    private let codingKeys: PagedCodingKeys

    public var underestimatedCount: Int {
        return items?.count ?? 0
    }

    /// Deserializes the JSON payload to append the new items, update tracking of the "current page" of items
    /// and reset the per page iterator.
    private func update(with data: Data?) throws {
        guard let data = data else { throw HttpResponseError.decode }
        let codingKeys = self.codingKeys
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let itemJson = json[codingKeys.items] {
                let decoder = JSONDecoder()
                let itemData = try JSONSerialization.data(withJSONObject: itemJson)
                let newItems = try decoder.decode(Element.self, from: itemData)
                if let currentItems = self._items {
                    // append rather than throw away old items
                    self.pageRange = currentItems.count..<(currentItems.count + newItems.count)
                    self._items = currentItems + newItems
                } else {
                    self._items = newItems
                    self.pageRange = 0..<newItems.count
                }
            }
            self.continuationToken = json[codingKeys.continuationToken] as? String
        }
    }

    public init(client: PipelineClient, data: Data?, codingKeys: PagedCodingKeys? = nil) throws {
        guard let data = data else { throw HttpResponseError.decode }
        self.client = client
        self.codingKeys = codingKeys ?? PagedCodingKeys()
        try update(with: data)
    }

    /// Retrieves the next page of results asynchronously.
    public func nextPage(then completion: @escaping (Result<Element?, Error>) -> Void) {
        guard let continuationToken = continuationToken else {
            completion(.success(nil))
            return
        }
        os_log("Fetching next page with: %@", continuationToken)
        let request = client.request(method: .GET,
                                     urlTemplate: continuationToken)

        client.run(request: request) { result, _ in
            var returnError: Error?
            switch result {
            case .failure(let error):
                returnError = error
            case .success(let data):
                do {
                    try self.update(with: data)
                } catch {
                    returnError = error
                }
            }
            if let returnError = returnError {
                completion(.failure(returnError))
            }
            self.iteratorIndex = 0
            completion(.success(self.pageItems))
        }
    }

    /// Retrieves the next item in the collection, automatically fetching new pages when needed.
    public func nextItem(then completion: @escaping (Result<SingleElement?, Error>) -> Void) {
        guard let pageItems = pageItems else {
            completion(.success(nil))
            return
        }
        if iteratorIndex >= pageItems.count {
            nextPage { result in
                switch result {
                case .failure(let error):
                    completion(.failure(error))
                case .success(let newPage):
                    if let newPage = newPage {
                        // since we return the first new item, the next iteration should start with the second item.
                        self.iteratorIndex = 1
                        completion(.success(newPage[0]))
                    } else {
                        self.iteratorIndex = 0
                        completion(.success(nil))
                    }
                }
            }
        } else {
            if let item = self.pageItems?[iteratorIndex] {
                iteratorIndex += 1
                completion(.success(item))
            } else {
                iteratorIndex = 0
                completion(.success(nil))
            }
        }
    }

    // MARK: Iterator Protocol

    /// Returns the next page of results. In order to conform with the protocol, this
    /// usage must be synchronous.
    public func next() -> Element? {
        guard let items = items else { return nil }
        if iteratorIndex < items.count {
            iteratorIndex = items.count
            return items
        }
        // must force synchronous behavior due to the constraints
        // of the protocol.
        let semaphore = DispatchSemaphore(value: 0)
        var newItems: Element?
        nextPage { result in
            switch result {
            case .success(let newPage):
                self.iteratorIndex = newPage?.count ?? 0
                newItems = newPage
            case .failure(let error):
                os_log("Error: %@", error.localizedDescription)
                newItems = nil
            }
            semaphore.signal()
        }
        _ = semaphore.wait(wallTimeout: .distantFuture)
        return newItems
    }
}