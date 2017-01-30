//
//  MangerKitTests.swift
//  MangerKitTests
//
//  Created by Michael on 8/27/15.
//  Copyright © 2015 Michael Nisi. All rights reserved.
//

import XCTest
import Patron
@testable import MangerKit

/// Enqueue a block for execution after a specified delay in milliseconds or, 
/// if `ms` isnt’t supplied, after a random delay between 0 and 10 milliseconds.
///
/// - parameter queue: The queue on which to submit the block..
/// - parameter ms: Delay in milliseconds before the callback is dispatched.
/// - parameter cb: The block to submit after the delay `ms`.
func delay(
  _ ms: Int64 = Int64(arc4random_uniform(10)),
  queue: DispatchQueue = DispatchQueue.main,
  cb: @escaping () -> Void) {
  let delta = ms * Int64(NSEC_PER_MSEC)
  let when = DispatchTime.now() + Double(delta) / Double(NSEC_PER_SEC)
  queue.asyncAfter(deadline: when, execute: cb)
}

private func freshSession() -> URLSession {
  let conf = URLSessionConfiguration.default
  conf.httpShouldUsePipelining = true
  conf.requestCachePolicy = .reloadIgnoringLocalCacheData
  return URLSession(configuration: conf)
}

struct Query: MangerQuery {
  let url: String
  let since: Date
  
  init (url: String, since: Date = Date(timeIntervalSince1970: 0)) {
    self.url = url
    self.since = since
  }
}

let queries: [MangerQuery] = [
  Query(url: "http://feeds.wnyc.org/newyorkerradiohour"),
  Query(url: "http://feed.thisamericanlife.org/talpodcast"),
  Query(url: "http://feeds.serialpodcast.org/serialpodcast")
]

let invalidQueries: [MangerQuery] = [
  Query(url: "http://feeds.wnyc.org/newyorkerradiohour"),
  Query(url: "")
]

let sinceNowQueries: [MangerQuery] = [
  Query(url: "http://feeds.wnyc.org/newyorkerradiohour", since: Date()),
  Query(url: "http://feed.thisamericanlife.org/talpodcast", since: Date()),
  Query(url: "http://feeds.serialpodcast.org/serialpodcast", since: Date())
]

class MangerFailures: XCTestCase {
  var session: URLSession!
  var queue: DispatchQueue!
  var svc: MangerService!
  
  override func setUp() {
    super.setUp()
    queue = DispatchQueue.main
    session = freshSession()
    let url = URL(string: "http://localhost:8385")!
    let client = Patron(URL: url, session: session, target: queue)
    svc = Manger(client: client)
  }
  
  override func tearDown() {
    session.invalidateAndCancel()
    svc = nil
    super.tearDown()
  }
  
  func testHost() {
    XCTAssertEqual(svc.client.host, "localhost")
  }
  
  func callbackWithExpression(
    _ exp: XCTestExpectation)
    -> (Error?, Any?) -> Void {
    func cb (_ error: Error?, result: Any?)-> Void {
      let er = error as! NSError
      XCTAssertEqual(er.code, -1004)
      XCTAssertNil(result)
      exp.fulfill()
    }
    return cb
  }
  
  func testEntries() {
    let exp = self.expectation(description: "entries")
    let cb = callbackWithExpression(exp)
    try! svc.entries(queries, cb: cb)
    self.waitForExpectations(timeout: 10) { er in
      XCTAssertNil(er)
    }
  }
  
  func testFeeds() {
    let exp = self.expectation(description: "feeds")
    let cb = callbackWithExpression(exp)
    try! svc.feeds(queries, cb: cb)
    self.waitForExpectations(timeout: 10) { er in
      XCTAssertNil(er)
    }
  }
  
  func testVersion() {
    let exp = self.expectation(description: "version")
    let cb = callbackWithExpression(exp)
    try! svc.version(cb)
    self.waitForExpectations(timeout: 10) { er in
      XCTAssertNil(er)
    }
  }
}

class MangerKitTests: XCTestCase {
  var session: URLSession!
  var queue: DispatchQueue!
  var svc: MangerService!
  
  override func setUp() {
    super.setUp()
    queue = DispatchQueue(
      label: "com.michaelnisi.patron.json",
      attributes: DispatchQueue.Attributes.concurrent
    )
    session = freshSession()
    let url = URL(string: "http://localhost:8384")!
    let client = Patron(URL: url, session: session, target: queue)
    svc = Manger(client: client)
  }
  
  override func tearDown() {
    super.tearDown()
  }
  
  func testJSTimeFromDate() {
    let f = JSTimeFromDate
    let found = [
      f(Date(timeIntervalSince1970: 0)),
      f(Date(timeIntervalSince1970: 1456042439.415))
    ]
    let wanted = [
      0.0,
      1456042439415.0
    ]
    for (i, b) in wanted.enumerated() {
      let a = found[i]
      XCTAssertEqual(a, b)
    }
  }
  
  func testEntriesWithEmptyQueries() {
    let exp = self.expectation(description: "entries")
    let q = [MangerQuery]()
    do {
      try svc.entries(q) { _, _ in }
    } catch MangerError.noQueries {
      exp.fulfill()
    } catch {
      XCTFail("should throw expected error")
    }
    self.waitForExpectations(timeout: 10) { er in
      XCTAssertNil(er)
    }
  }
  
  func testEntries() {
    let exp = self.expectation(description: "entries")
    try! svc.entries(queries) { error, entries in
      XCTAssertNil(error)
      XCTAssert(entries!.count > 0)
      exp.fulfill()
    }
    self.waitForExpectations(timeout: 10) { er in
      XCTAssertNil(er)
    }
  }
  
  func testEntriesSinceNow() {
    let exp = self.expectation(description: "entries")
    try! svc.entries(sinceNowQueries) { error, entries in
      XCTAssertNil(error)
      XCTAssertEqual(entries!.count, 0)
      exp.fulfill()
    }
    self.waitForExpectations(timeout: 10) { er in
      XCTAssertNil(er)
    }
  }
  
  func testEntriesCancel() {
    let exp = self.expectation(description: "entries")
    let op = try! svc.entries(queries) { error, entries in
      defer {
        exp.fulfill()
      }
      guard entries == nil else {
        return
      }
      do {
        throw error!
      } catch MangerError.cancelledByUser {
      } catch {
        XCTFail("should be expected error")
      }
    }
    delay() {
      op.cancel()
    }
    self.waitForExpectations(timeout: 10) { er in
      XCTAssertNil(er)
    }
  }
  
  func testEntriesWithInvalidQueries() {
    let exp = self.expectation(description: "entries")
    do {
      try svc.entries(invalidQueries) { _, _ in }
    } catch MangerError.invalidQuery {
      exp.fulfill()
    } catch {
      XCTFail("should throw expected error")
    }
    self.waitForExpectations(timeout: 10) { er in
      XCTAssertNil(er)
    }
  }
  
  func testFeeds() {
    let exp = self.expectation(description: "feeds")
    try! svc.feeds(queries) { error, feeds in
      XCTAssertNil(error)
      XCTAssertEqual(feeds!.count, queries.count)
      exp.fulfill()
    }
    self.waitForExpectations(timeout: 10) { er in
      XCTAssertNil(er)
    }
  }
  
  func testFeedsCancel() {
    let exp = self.expectation(description: "feeds")
    let op = try! svc.feeds(queries) { error, feeds in
      defer {
        exp.fulfill()
      }
      guard feeds == nil else {
        return
      }
      do {
        throw error!
      } catch MangerError.cancelledByUser {
      } catch {
        XCTFail("should be expected error")
      }
    }
    delay() {
      op.cancel()
    }
    self.waitForExpectations(timeout: 10) { er in
      XCTAssertNil(er)
    }
  }
  
  func testFeedsWithEmptyQueries() {
    let exp = self.expectation(description: "entries")
    let queries = [MangerQuery]()
    do {
      try svc.feeds(queries) { _, _ in }
    } catch MangerError.noQueries {
      exp.fulfill()
    } catch {
      XCTFail("should throw expected error")
    }
    self.waitForExpectations(timeout: 10) { er in
      XCTAssertNil(er)
    }
  }
  
  func testFeedsWithInvalidQueries() {
    let exp = self.expectation(description: "entries")
    do {
      try svc.feeds(invalidQueries) { _, _ in }
    } catch MangerError.invalidQuery {
      exp.fulfill()
    } catch {
      XCTFail("should throw expected error")
    }
    self.waitForExpectations(timeout: 10) { er in
      XCTAssertNil(er)
    }
  }
  
  func testVersion() {
    let exp = self.expectation(description: "version")
    try! svc.version() { error, version in
      XCTAssertNil(error)
      XCTAssertEqual(version, "2.1.0")
      exp.fulfill()
    }
    self.waitForExpectations(timeout: 10) { er in
      XCTAssertNil(er)
    }
  }
  
  func testVersionCancel() {
    let svc = self.svc!
    let exp = self.expectation(description: "version")
    let task = try! svc.version { error, version in
      do {
        throw error!
      } catch MangerError.cancelledByUser {
      } catch {
        XCTFail("should be expected error")
      }
      XCTAssertNil(version)
      exp.fulfill()
    }
    task.cancel()
    self.waitForExpectations(timeout: 10) { er in
      XCTAssertNil(er)
    }
  }
  
  func testHTTPBodyFromPayload() {
    let payload: [[String : String]] = [
      ["url": "http://newyorker.com/feed/posts"],
      ["url": "http://newyorker.com/feed/posts", "since": "01 Sep 2015"]
    ]
    let body = HTTPBodyFromPayload(payload)
    let json = try! JSONSerialization.jsonObject(with: body, options: [])
    let found = json as! [[String : String]]
    for (i, wanted) in payload.enumerated() {
      XCTAssertEqual(found[i], wanted)
    }
  }
}
