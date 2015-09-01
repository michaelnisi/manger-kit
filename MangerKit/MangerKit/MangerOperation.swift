//
//  MangerOperation.swift
//  MangerKit
//
//  Created by Michael on 8/30/15.
//  Copyright © 2015 Michael Nisi. All rights reserved.
//

import UIKit
import Ola

typealias MangerResult = [[String:AnyObject]]

func resultWithData (data: NSData) throws -> MangerResult {
  let json = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments)
  if let dict = json as? [String: AnyObject] {
    return [dict]
  } else if let arr = json as? [[String:AnyObject]] {
    return arr
  }
  throw MangerError.UnexpectedJSON
}

public class MangerOperation: NSOperation {
  let queue: dispatch_queue_t
  let session: NSURLSession
  let url: NSURL

  var error: ErrorType?
  var result: MangerResult?
  
  public init (session: NSURLSession, url: NSURL, queue: dispatch_queue_t) {
    self.session = session
    self.url = url
    self.queue = queue
  }
  
  var sema: dispatch_semaphore_t?
  
  func lock () {
    if !cancelled && sema == nil {
      sema = dispatch_semaphore_create(0)
      dispatch_semaphore_wait(sema!, DISPATCH_TIME_FOREVER)
    }
  }
  
  func unlock () {
    if let sema = self.sema {
      dispatch_semaphore_signal(sema)
    }
  }
  
  weak var task: NSURLSessionTask?
  
  func request () {
    self.task?.cancel()
    self.task = session.dataTaskWithURL(url) { [weak self] data, response, error in
      if self?.cancelled == true { return }
      if let er = error {
        if er.code == NSURLErrorNotConnectedToInternet ||
           er.code == NSURLErrorNetworkConnectionLost {
          self?.check()
        } else {
          self?.error = er
          self?.unlock()
        }
        return
      }
      do {
        guard let d = data else { throw MangerError.NoData }
        let result = try resultWithData(d)
        self?.result = result
      } catch let er {
        self?.error = er
      }
      defer {
        self?.unlock()
      }
    }
    self.task?.resume()
  }
  
  var allowsCellularAccess: Bool { get {
    return session.configuration.allowsCellularAccess }
  }
  
  func reachable (status: OlaStatus) -> Bool {
    return status == .Reachable || (status == .Cellular && allowsCellularAccess)
  }
  
  lazy var ola: Ola? = { [unowned self] in
    Ola(host: self.url.host!, queue: self.queue)
  }()
  
  func check () {
    if let ola = self.ola {
      if reachable(ola.reach()) {
        request()
      } else {
        ola.reachWithCallback() { [weak self] status in
          if self?.cancelled == false
            && self?.reachable(status) == true {
              self?.request()
          }
        }
      }
    } else {
      print("could not initialize ola")
    }
  }
  
  public override func main () {
    if cancelled { return }
    request()
    lock()
  }
  
  public override func cancel () {
    task?.cancel()
    unlock()
    super.cancel()
  }
}
