//
// Created by Jeff Roberts on 4/11/17.
// Copyright (c) 2017 Nimble Noggin Software. All rights reserved.
//

import Foundation

public protocol Http {
    func delete(url : String, headers : [String : String]?, body : String?) throws -> Any?
    func get(url : String, headers : [String : String]?, body : String?) throws -> Any?
    func head(url : String, headers : [String : String]?, body : String?) throws -> [String : String]?
    func post(url : String, headers : [String : String]?, body : String?) throws -> Any?
    func put(url : String, headers : [String : String]?, body : String?) throws -> Any?
}

public enum HttpError : Error {
    case badRequest(message : String)
    case other(status : Int, description : String, message: String)
}

public class HttpDriver : Http {
    private static let DELETE = "DELETE"
    private static let GET = "GET"
    private static let HEAD = "HEAD"
    private static let POST = "POST"
    private static let PUT = "PUT"

    private let urlSession : URLSession

    public init(urlSession : URLSession) {
        self.urlSession = urlSession
    }

    public func delete(url : String, headers : [String : String]? = nil, body : String? = nil) throws -> Any? {
        guard let requestUrl = URL(string: url) else {
            throw HttpError.badRequest(message: "Unable to create a URL for \(url)")
        }

        var urlRequest = URLRequest(url: requestUrl)
        urlRequest.httpMethod = HttpDriver.DELETE

        return try send(request: urlRequest, headers: headers, body: body)
    }

    public func get(url : String, headers : [String : String]? = nil, body : String? = nil) throws -> Any? {
        guard let requestUrl = URL(string: url) else {
            throw HttpError.badRequest(message: "Unable to create a URL for \(url)")
        }

        var urlRequest = URLRequest(url: requestUrl)
        urlRequest.httpMethod = HttpDriver.GET

        return try send(request: urlRequest, headers: headers, body: body)
    }

    public func head(url : String, headers : [String : String]? = nil, body : String? = nil) throws -> [String : String]? {
        guard let requestUrl = URL(string: url) else {
            throw HttpError.badRequest(message: "Unable to create a URL for \(url)")
        }

        var urlRequest = URLRequest(url: requestUrl)
        urlRequest.httpMethod = HttpDriver.HEAD

        return try send(request: urlRequest, headers: headers, body: body) as? [String : String]
    }

    public func post(url : String, headers : [String : String]?, body : String?) throws -> Any? {
        guard let requestUrl = URL(string: url) else {
            throw HttpError.badRequest(message: "Unable to create a URL for \(url)")
        }

        var urlRequest = URLRequest(url: requestUrl)
        urlRequest.httpMethod = HttpDriver.POST

        return try send(request: urlRequest, headers: headers, body: body)
    }

    public func put(url : String, headers : [String : String]?, body : String?) throws -> Any? {
        guard let requestUrl = URL(string: url) else {
            throw HttpError.badRequest(message: "Unable to create a URL for \(url)")
        }

        var urlRequest = URLRequest(url: requestUrl)
        urlRequest.httpMethod = HttpDriver.PUT

        return try send(request: urlRequest, headers: headers, body: body)
    }

    private func send(request : URLRequest, headers : [String : String]? = nil, body : String? = nil) throws -> Any? {
        var apiResponse : Any?
        var apiError : Error?
        let semaphore = DispatchSemaphore.init(value: 0)

        let task = self.urlSession.dataTask(with: request) { (data, response, error) in
            guard let data = data else {
                apiError = error
                semaphore.signal()
                return
            }

            do {
                apiResponse = try JSONSerialization.jsonObject(with: data)
            } catch let jsonError {
                apiError = jsonError
            }

            semaphore.signal()
        }

        task.resume()

        let _ = semaphore.wait(timeout: DispatchTime.distantFuture)

        if let response = apiResponse as? [String : Any] {
            return response
        } else if let error = apiError {
            throw error
        } else  {
            throw HttpError.other(status: 500, description: "Server Error", message: "")
        }
    }

}