//
//  index.swift
//  MangerKit
//
//  Created by Michael on 8/27/15.
//  Copyright © 2015 Michael Nisi. All rights reserved.
//

// TODO: Document MangerKit 

import Foundation
import Patron

public enum MangerError: ErrorType {
  case UnexpectedResult(result: AnyObject?)
  case CancelledByUser
  case NoQueries
  case InvalidQuery
  case NIY
}

func retypeError(error: ErrorType?) -> ErrorType? {
  guard error != nil else {
    return nil
  }
  do {
    throw error!
  } catch let error as NSError {
    switch error.code {
    case -999: return MangerError.CancelledByUser
    default: return error
    }
  } catch {
    return error
  }
}

func JSTimeFromDate(date: NSDate) -> Double {
  let ms = date.timeIntervalSince1970 * 1000
  return round(ms)
}

public protocol MangerQuery {
  var url: String { get }
  var since: NSDate { get }
}

typealias Payload = [[String:AnyObject]]

func payloadWithQueries(queries: [MangerQuery]) -> Payload {
  return queries.map { query in
    let since = JSTimeFromDate(query.since)
    guard since != 0 else {
      return ["url": query.url]
    }
    return ["url": query.url, "since": since]
  }
}

public protocol MangerService {
  
  func feeds(
    queries: [MangerQuery],
    cb: (ErrorType?, [[String: AnyObject]]?) -> Void
  ) throws -> NSURLSessionTask
  
  func entries(
    queries: [MangerQuery],
    cb: (ErrorType?, [[String: AnyObject]]?) -> Void
  ) throws -> NSURLSessionTask
  
  func version(cb: (ErrorType?, String?) -> Void) throws -> NSURLSessionTask
}

// TODO: Deprecate useage of self-signed certificates.

class Certify: NSObject {
  let certs: [SecCertificate]
  init (cert: SecCertificate) {
    self.certs = [cert]
  }
}

extension Certify: NSURLSessionDelegate {
  func URLSession(
    session: NSURLSession,
    didReceiveChallenge challenge: NSURLAuthenticationChallenge,
    completionHandler: (NSURLSessionAuthChallengeDisposition, NSURLCredential?) -> Void) {
      let space = challenge.protectionSpace
      guard let trust = space.serverTrust else {
        completionHandler(.CancelAuthenticationChallenge, nil)
        return
      }
      let status = SecTrustSetAnchorCertificates(trust, certs)
      if status == 0 {
        completionHandler(.PerformDefaultHandling, nil)
      } else {
        completionHandler(.CancelAuthenticationChallenge, nil)
      }
  }
}

func loadCertWithName(name: String, fromBundle bundle: NSBundle) -> SecCertificate? {
  if let path = bundle.pathForResource(name, ofType: "der") {
    if let data = NSData(contentsOfFile: path) {
      return SecCertificateCreateWithData(nil, data)
    }
  }
  return nil
}

// --

func headers() -> [NSObject: AnyObject] {
  return [
    "Authorization": "Basic QWxhZGRpbjpvcGVuIHNlc2FtZQ==",
    "Accept-Encoding": "compress, gzip"
  ]
}

func HTTPBodyFromPayload(payload: [[String: AnyObject]]) -> NSData {
  return try! NSJSONSerialization.dataWithJSONObject(payload, options: .PrettyPrinted)
}

func checkQueries(queries: [MangerQuery]) throws {
  guard queries.count > 0 else { throw MangerError.NoQueries }
  let invalids = queries.filter { q in
    q.url == ""
  }
  if invalids.count != 0 {
    throw MangerError.InvalidQuery
  }
}

/// This adoption invalidates its session. Do not share sessions!

public final class Manger: MangerService {
  
  let client: Patron
  let session: NSURLSession

  public init (URL: NSURL, queue: dispatch_queue_t, session: NSURLSession) {
    self.session = session
    self.client = PatronClient(URL: URL, queue: queue, session: session)
  }
  
  deinit {
    session.invalidateAndCancel()
  }

  func queryTaskWithPayload (
    payload: Payload,
    forPath path: String,
    cb: (ErrorType?, [[String: AnyObject]]?) -> Void
  ) throws -> NSURLSessionTask {
    return try client.post(path, json: payload) { json, response, error in
      if let er = retypeError(error) {
        cb(er, nil)
      } else if let result = json as? [[String:AnyObject]] {
        cb(nil, result)
      } else {
        cb(MangerError.UnexpectedResult(result: json), nil)
      }
    }
  }
  
  public func feeds(
    queries: [MangerQuery],
    cb: (ErrorType?, [[String: AnyObject]]?) -> Void
  ) throws ->  NSURLSessionTask {
    try checkQueries(queries)
    let payload = payloadWithQueries(queries)
    return try queryTaskWithPayload(payload, forPath: "/feeds", cb: cb)
  }

  public func entries(
    queries: [MangerQuery],
    cb: (ErrorType?, [[String: AnyObject]]?) -> Void
  ) throws -> NSURLSessionTask {
    try checkQueries(queries)
    let payload = payloadWithQueries(queries)
    return try queryTaskWithPayload(payload, forPath: "/entries", cb: cb)
  }

  public func version(cb: (ErrorType?, String?) -> Void) throws -> NSURLSessionTask {
    return try client.get("/") { json, response, error in
      if let er = retypeError(error) {
        cb(er, nil)
      } else if let version = json?["version"] as? String {
        cb(nil, version)
      } else {
        cb(MangerError.UnexpectedResult(result: json), nil)
      }
    }
  }
}

