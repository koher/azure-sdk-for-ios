//
//  PipelineResponse.swift
//  AzureCore
//
//  Created by Travis Prescott on 8/29/19.
//  Copyright © 2019 Azure SDK Team. All rights reserved.
//

import Foundation

@objc(AZCorePipelineResponse)
public class PipelineResponse: NSObject, PipelineContextSupportable {
    @objc public var httpRequest: HttpRequest
    @objc public var httpResponse: HttpResponse
    internal var context: PipelineContext?

    @objc convenience init(request: HttpRequest, response: HttpResponse) {
        self.init(request: request, response: response, context: nil)
    }

    @objc init(request: HttpRequest, response: HttpResponse, context: PipelineContext?) {
        self.httpRequest = request
        self.httpResponse = response
        self.context = context
    }

    @objc public func add(value: AnyObject, forKey key: AnyHashable) {
        if let context = self.context {
            self.context = context.add(value: value, forKey: key)
        } else {
            self.context = PipelineContext(key: key, value: value)
        }
    }

    @objc public func getValue(forKey key: AnyHashable) -> AnyObject? {
        return self.context?.getValue(forKey: key)
    }
}
