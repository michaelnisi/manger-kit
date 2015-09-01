//
//  index.swift
//  MangerKit
//
//  Created by Michael on 8/27/15.
//  Copyright © 2015 Michael Nisi. All rights reserved.
//

// TODO: Make this configurable

import Foundation

public class Certify: NSObject {
  let certs: [SecCertificate]
  init (cert: SecCertificate) {
    self.certs = [cert]
  }
}

extension Certify: NSURLSessionDelegate {
  public func URLSession(
    session: NSURLSession,
    didReceiveChallenge challenge: NSURLAuthenticationChallenge,
    completionHandler: (NSURLSessionAuthChallengeDisposition, NSURLCredential?) -> Void) {
      let space = challenge.protectionSpace
      guard let trust = space.serverTrust else {
        print("no server trust in protection space")
        completionHandler(.CancelAuthenticationChallenge, nil)
        return
      }
      let status = SecTrustSetAnchorCertificates(trust, certs)
      if status == 0 {
        print("performing basic access authentication")
        completionHandler(.PerformDefaultHandling, nil)
      } else {
        print("canceling: \(status)")
        completionHandler(.CancelAuthenticationChallenge, nil)
      }
  }
}

func loadCert (name: String) -> SecCertificate? {
  let bundle = NSBundle.mainBundle()
  if let path = bundle.pathForResource(name, ofType: "der") {
    if let data = NSData(contentsOfFile: path) {
      return SecCertificateCreateWithData(nil, data)
    }
  }
  return nil
}

func headers () -> [NSObject: String] {
  return ["Authorization": "Basic QWxhZGRpbjpvcGVuIHNlc2FtZQ=="]
}

public enum MangerError: ErrorType {
  case NoSession
  case UnexpectedJSON
  case NoData
}

func createSession () throws -> NSURLSession {
  let conf = NSURLSessionConfiguration.defaultSessionConfiguration()
  guard let cert = loadCert("cert") else {
    throw MangerError.NoSession
  }
  conf.HTTPAdditionalHeaders = headers()
  let del = Certify(cert: cert)
  let queue = NSOperationQueue()
  let sess = NSURLSession(configuration: conf, delegate: del, delegateQueue: queue)
  return sess
}

public class MangerService {
  let session: NSURLSession
  let queue = NSOperationQueue()
  
  init (session: NSURLSession) {
    self.session = session
  }
  
  public init () {
    try! self.session = createSession()
  }
  
  public typealias MangerCallback = ([[String: AnyObject]]?, ErrorType?) -> Void
  
  public func entries (cb: MangerCallback) -> NSOperation {
    let q = dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0)
    let url = NSURL(string: "https://podest/entries")!
    let op = MangerOperation(session: session, url: url, queue: q)
    queue.addOperation(op)
    op.completionBlock = { [unowned op] in
      cb(op.result, op.error)
    }
    return op
  }
  
  public func ping (url: NSURL?, cb: MangerCallback) -> NSOperation {
    if url == nil {
      return ping(cb)
    }
    let q = dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0)
    let op = MangerOperation(session: session, url: url!, queue: q)
    queue.addOperation(op)
    op.completionBlock = { [unowned op] in
      cb(op.result, op.error)
    }
    return op
  }
  
  public func ping (cb: MangerCallback) -> NSOperation {
    let url = NSURL(string: "https://podest")!
    return ping(url, cb: cb)
  }
}