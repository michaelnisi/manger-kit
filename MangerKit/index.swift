//
//  index.swift
//  MangerKit
//
//  Created by Michael on 8/27/15.
//  Copyright © 2015 Michael Nisi. All rights reserved.
//

import Foundation
import Patron

// MARK: API

public enum MangerError: Error {
  case unexpectedResult(result: Any?)
  case cancelledByUser
  case noQueries
  case invalidQuery
  case niy
}

public protocol MangerQuery {
  var url: String { get }
  var since: Date { get }
}

/// Define **manger** service, a client for **manger-http**, an HTTP JSON API
/// for requesting feeds and entries within time intervals.
public protocol MangerService {
  var client: JSONService { get }
  
  @discardableResult func feeds(
    _ queries: [MangerQuery],
    cb: @escaping (Error?, [[String : AnyObject]]?) -> Void
    ) throws -> URLSessionTask
  
  @discardableResult func entries(
    _ queries: [MangerQuery],
    reload: Bool,
    cb: @escaping (Error?, [[String : AnyObject]]?) -> Void
  ) throws -> URLSessionTask
  
  @discardableResult func entries(
    _ queries: [MangerQuery],
    cb: @escaping (Error?, [[String : AnyObject]]?) -> Void
  ) throws -> URLSessionTask
  
  @discardableResult func version(
    _ cb: @escaping (Error?, String?) -> Void
    ) throws -> URLSessionTask
}

// MARK: -

private func retypeError(_ error: Error?) -> Error? {
  guard let er = error as NSError? else {
    return error
  }
  switch er.code {
  case -999: return MangerError.cancelledByUser
  default: return er
  }
}

func JSTimeFromDate(_ date: Date) -> Double {
  let ms = date.timeIntervalSince1970 * 1000
  return round(ms)
}

private typealias Payload = [[String : Any]]

private func payloadWithQueries(_ queries: [MangerQuery]) -> Payload {
  return queries.map { query in
    let since = JSTimeFromDate(query.since)
    guard since != 0 else {
      return ["url": query.url as AnyObject]
    }
    return ["url": query.url as AnyObject, "since": since as AnyObject]
  }
}

private func urlEncode(_ path: String, for url: String) -> String {
  let url = url.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
  return "\(path)/\(url)"
}

private func checkQueries(_ queries: [MangerQuery]) throws {
  guard queries.count > 0 else { throw MangerError.noQueries }
  let invalids = queries.filter { q in
    q.url == ""
  }
  if invalids.count != 0 {
    throw MangerError.invalidQuery
  }
}

func HTTPBodyFromPayload(_ payload: [[String : Any]]) -> Data {
  return try! JSONSerialization.data(withJSONObject: payload, options: .prettyPrinted)
}

/// The production implementation of `MangerService`. Note that this object 
/// invalidates its session, hence: Do not share sessions!
public final class Manger: MangerService {
  
  /// The underlying JSON service client.
  public let client: JSONService

  /// Create and return a new `Manger` object.
  ///
  /// - parameter client: The JSON service to use.
  public init(client: JSONService) {
    self.client = client
  }

  private func post(
    _ payload: Payload,
    to path: String,
    cb: @escaping (Error?, [[String : AnyObject]]?) -> Void
  ) throws -> URLSessionTask {
    let json = payload as AnyObject
    return try client.post(path: path, json: json) { json, response, error in
      if let er = retypeError(error) {
        cb(er, nil)
      } else if let result = json as? [[String : AnyObject]] {
        cb(nil, result)
      } else {
        cb(MangerError.unexpectedResult(result: json), nil)
      }
    }
  }
  
  private func get(
    _ path: String,
    reload: Bool,
    cb: @escaping (Error?, [[String : AnyObject]]?) -> Void
  ) throws -> URLSessionTask {
    
    let cachePolicy: NSURLRequest.CachePolicy =
      reload ? .reloadIgnoringLocalCacheData : .useProtocolCachePolicy
    
    return client.get(path: path,
                      allowsCellularAccess: true,
                      cachePolicy: cachePolicy) { json, response, error in
                        
      if let er = retypeError(error) {
        cb(er, nil)
      } else if let result = json as? [[String : AnyObject]] {
        cb(nil, result)
      } else {
        cb(MangerError.unexpectedResult(result: json), nil)
      }
    }
  }

  /// Requests feeds for specified queries.
  ///
  /// - parameter queries: An array of `MangerQuery` objects.
  /// - parameter cb: The callback to apply when the request is complete.
  /// - parameter error: An eventual error.
  /// - parameter payload: The payload is an array of feed dictionaries.
  ///
  /// - returns: The URL session task.
  ///
  /// - throws: Invalid URLs or failed payload serialization might obstruct
  /// successful task creation.
  public func feeds(
    _ queries: [MangerQuery],
    cb: @escaping (_ error: Error?, _ payload: [[String : AnyObject]]?) -> Void
  ) throws ->  URLSessionTask {
    try checkQueries(queries)
    
    if queries.count == 1 {
      let query = queries.first!
      return try get(urlEncode("/feed", for: query.url), reload: false, cb: cb)
    }
    
    let payload = payloadWithQueries(queries)
    return try post(payload, to: "/feeds", cb: cb)
  }
  
  /// Requests entries for specified queries.
  ///
  /// - parameter queries: An array of `MangerQuery` objects.
  /// - parameter reload: Reload data ignoring cache.
  /// - parameter cb: The callback to apply when the request is complete.
  /// - parameter error: An eventual error.
  /// - parameter payload: The payload is an array of entry dictionaries.
  ///
  /// - returns: The URL session task.
  ///
  /// - throws: Invalid URLs or failed payload serialization can obstruct
  /// successful task creation.
  public func entries(
    _ queries: [MangerQuery],
    reload: Bool,
    cb: @escaping (_ error: Error?, _ payload: [[String : AnyObject]]?) -> Void
  ) throws -> URLSessionTask {
    try checkQueries(queries)
    
    if queries.count == 1, queries.first?.since.timeIntervalSince1970 == 0 {
      let query = queries.first!
      return try get(urlEncode("/entries", for: query.url), reload: reload, cb: cb)
    }
    
    let payload = payloadWithQueries(queries)
    return try post(payload, to: "/entries", cb: cb)
  }
  
  /// Requests entries for specified queries.
  ///
  /// - parameter queries: An array of `MangerQuery` objects.
  /// - parameter cb: The callback to apply when the request is complete.
  /// - parameter error: An eventual error.
  /// - parameter payload: The payload is an array of entry dictionaries.
  ///
  /// - returns: The URL session task.
  ///
  /// - throws: Invalid URLs or failed payload serialization can obstruct
  /// successful task creation.
  public func entries(
    _ queries: [MangerQuery],
    cb: @escaping (_ error: Error?, _ payload: [[String : AnyObject]]?) -> Void
  ) throws -> URLSessionTask {
    return try entries(queries, reload: false, cb: cb)
  }

  /// Requests the version of the remote API.
  ///
  /// - returns: The URL session task.
  ///
  /// - throws: Invalid URLs or failed payload serialization can obstruct
  /// successful task creation.
  public func version(_ cb: @escaping (Error?, String?) -> Void) throws -> URLSessionTask {
    return client.get(path: "/") { json, response, error in
      if let er = retypeError(error) {
        cb(er, nil)
      } else if let version = json?["version"] as? String {
        cb(nil, version)
      } else {
        cb(MangerError.unexpectedResult(result: json), nil)
      }
    }
  }
}
