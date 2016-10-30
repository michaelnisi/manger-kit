//
//  index.swift
//  MangerKit
//
//  Created by Michael on 8/27/15.
//  Copyright © 2015 Michael Nisi. All rights reserved.
//

// TODO: Hit URL query path for single feeds without dates to improve caching

import Foundation
import Patron

public enum MangerError: Error {
  case unexpectedResult(result: Any?)
  case cancelledByUser
  case noQueries
  case invalidQuery
  case niy
}

private func retypeError(_ error: Error?) -> Error? {
  guard let er = error as? NSError else {
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

public protocol MangerQuery {
  var url: String { get }
  var since: Date { get }
}

typealias Payload = [[String : Any]]

private func payloadWithQueries(_ queries: [MangerQuery]) -> Payload {
  return queries.map { query in
    let since = JSTimeFromDate(query.since)
    guard since != 0 else {
      return ["url": query.url as AnyObject]
    }
    return ["url": query.url as AnyObject, "since": since as AnyObject]
  }
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
    cb: @escaping (Error?, [[String : AnyObject]]?) -> Void
  ) throws -> URLSessionTask
  
  @discardableResult func version(
    _ cb: @escaping (Error?, String?) -> Void
  ) throws -> URLSessionTask
}

func HTTPBodyFromPayload(_ payload: [[String : Any]]) -> Data {
  return try! JSONSerialization.data(withJSONObject: payload, options: .prettyPrinted)
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

  private func queryTaskWithPayload(
    _ payload: Payload,
    forPath path: String,
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

  /// Requests feeds for specified queries.
  ///
  /// - returns: The URL session task.
  /// - throws: Invalid URLs or failed payload serialization can obstruct
  /// successful task creation.
  public func feeds(
    _ queries: [MangerQuery],
    cb: @escaping (Error?, [[String : AnyObject]]?) -> Void
  ) throws ->  URLSessionTask {
    try checkQueries(queries)
    let payload = payloadWithQueries(queries)
    return try queryTaskWithPayload(payload, forPath: "/feeds", cb: cb)
  }
  
  /// Requests entries for specified queries.
  ///
  /// - returns: The URL session task.
  /// - throws: Invalid URLs or failed payload serialization can obstruct
  /// successful task creation.
  public func entries(
    _ queries: [MangerQuery],
    cb: @escaping (Error?, [[String : AnyObject]]?) -> Void
  ) throws -> URLSessionTask {
    try checkQueries(queries)
    let payload = payloadWithQueries(queries)
    return try queryTaskWithPayload(payload, forPath: "/entries", cb: cb)
  }

  /// Requests the version of the remote API.
  ///
  /// - returns: The URL session task.
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

