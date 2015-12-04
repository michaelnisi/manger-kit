//
//  index.swift
//  MangerKit
//
//  Created by Michael on 8/27/15.
//  Copyright © 2015 Michael Nisi. All rights reserved.
//

import Foundation
import Patron

public enum MangerError: ErrorType {
  case UnexpectedResult(result: AnyObject?)
  case CancelledByUser
  case NoData
  case OlaInitializationFailed
  case NoSession
  case NoQueries
  case InvalidQuery
}

func retypeError(error: ErrorType?) -> ErrorType? {
  guard error != nil else {
    return nil
  }
  do {
    throw error!
  } catch PatronError.CancelledByUser {
    return MangerError.CancelledByUser
  } catch PatronError.NoData {
    return MangerError.NoData
  } catch PatronError.OlaInitializationFailed {
    return MangerError.OlaInitializationFailed
  } catch {
    return error
  }
}

func JSTimeFromDate(date: NSDate) -> Int {
  return Int(date.timeIntervalSince1970 * 1000)
}

public protocol MangerQuery {
  var url: String { get }
  var since: NSDate { get }
}

func payloadWithQueries(queries: [MangerQuery]) -> [[String:AnyObject]] {
  return queries.map { query in
    let since = JSTimeFromDate(query.since)
    guard since != 0 else {
      return ["url": query.url]
    }
    return ["url": query.url, "since": since]
  }
}

public protocol MangerService {
  func feeds (queries: [MangerQuery], cb: (ErrorType?, [[String: AnyObject]]?) -> Void) throws -> NSOperation
  func entries (queries: [MangerQuery], cb: (ErrorType?, [[String: AnyObject]]?) -> Void) throws -> NSOperation
  func version (cb: (ErrorType?, String?) -> Void) -> NSOperation
}

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

func loadCertWithName (name: String, fromBundle bundle: NSBundle) -> SecCertificate? {
  if let path = bundle.pathForResource(name, ofType: "der") {
    if let data = NSData(contentsOfFile: path) {
      return SecCertificateCreateWithData(nil, data)
    }
  }
  return nil
}

func headers () -> [NSObject: AnyObject] {
  return [
    "Authorization": "Basic QWxhZGRpbjpvcGVuIHNlc2FtZQ==",
    "Accept-Encoding": "compress, gzip"
  ]
}

func HTTPBodyFromPayload (payload: [[String: AnyObject]]) -> NSData {
  return try! NSJSONSerialization.dataWithJSONObject(payload, options: .PrettyPrinted)
}

func checkQueries (queries: [MangerQuery]) throws {
  guard queries.count > 0 else { throw MangerError.NoQueries }
  let invalids = queries.filter { q in
    q.url == ""
  }
  if invalids.count != 0 {
    throw MangerError.InvalidQuery
  }
}

public class Manger: MangerService {
  
  class func defaultSession (scheme: String) throws -> NSURLSession {
    let conf = NSURLSessionConfiguration.defaultSessionConfiguration()
    func delegate () throws -> NSURLSessionDelegate? {
      if scheme == "https" {
        let bundle = NSBundle.mainBundle()
        guard let cert = loadCertWithName("cert", fromBundle: bundle) else {
          throw MangerError.NoSession
        }
        return Certify(cert: cert)
      }
      return nil
    }
    // Remember that these are mostly POST requests, and--as such--are not cached,
    // unless we would use:
    // conf.requestCachePolicy = .ReturnCacheDataElseLoad
    // ... and than also would have to remove cached responses manually.
    conf.HTTPAdditionalHeaders = headers()
    conf.HTTPShouldUsePipelining = true
    let del = try! delegate()
    let queue = NSOperationQueue()
    return NSURLSession(configuration: conf, delegate: del, delegateQueue: queue)
  }
  
  let baseURL: NSURL
  let queue: NSOperationQueue
  let session: NSURLSession

  public init (baseURL: NSURL, queue: NSOperationQueue, session: NSURLSession) {
    self.baseURL = baseURL
    self.queue = queue
    self.session = session
  }
  
  func addOperation (
    op: PatronOperation,
    withCallback cb: (ErrorType?, [[String : AnyObject]]?) -> Void) {
      
    op.completionBlock = { [unowned op] in
      if let er = retypeError(op.error) {
        cb(er, nil)
      } else if let result = op.result as? [[String : AnyObject]] {
        cb(nil, result)
      } else {
        cb(MangerError.UnexpectedResult(result: op.result), nil)
      }
    }
    queue.addOperation(op)
  }

  func operationWithRequest (req: NSURLRequest) -> PatronOperation {
    let q = dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0)
    return PatronOperation(session: session, request: req, queue: q)
  }
  
  func urlWithPath (path: String) -> NSURL {
    return NSURL(string: path, relativeToURL: baseURL)!
  }
  
  func query (
    url: NSURL,
    payload: [[String: AnyObject]],
    cb: (ErrorType?, [[String: AnyObject]]?) -> Void) -> NSOperation {
      
    let req = NSMutableURLRequest(URL: url)
    req.HTTPMethod = "POST"
    req.HTTPBody = HTTPBodyFromPayload(payload)
    let op = operationWithRequest(req)
    addOperation(op, withCallback: cb)
    return op
  }
  
  public func feeds (queries: [MangerQuery], cb: (ErrorType?, [[String: AnyObject]]?) -> Void) throws ->  NSOperation {
    try checkQueries(queries)
    let payload = payloadWithQueries(queries)
    let url = urlWithPath("feeds")
    return query(url, payload: payload, cb: cb)
  }

  public func entries (queries: [MangerQuery], cb: (ErrorType?, [[String: AnyObject]]?) -> Void) throws -> NSOperation {
    try checkQueries(queries)
    let payload = payloadWithQueries(queries)
    let url = urlWithPath("entries")
    return query(url, payload: payload, cb: cb)
  }

  public func version(cb: (ErrorType?, String?) -> Void) -> NSOperation {
    let url = urlWithPath("/")
    let req = NSURLRequest(URL: url)
    let op = operationWithRequest(req)
    op.completionBlock = { [unowned op] in
      if let er = retypeError(op.error) {
        cb(er, nil)
      } else if let version = op.result?["version"] as? String {
        cb(nil, version)
      } else {
        cb(MangerError.UnexpectedResult(result: op.result), nil)
      }
    }
    queue.addOperation(op)
    return op
  }
}

