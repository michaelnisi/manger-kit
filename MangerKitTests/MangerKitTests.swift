//
//  MangerKitTests.swift
//  MangerKitTests
//
//  Created by Michael on 8/27/15.
//  Copyright © 2015 Michael Nisi. All rights reserved.
//

import XCTest
@testable import MangerKit

func delay (ms: Int64 = Int64(arc4random_uniform(10)), cb: () -> Void) {
  let delta = ms * Int64(NSEC_PER_MSEC)
  let when = dispatch_time(DISPATCH_TIME_NOW, delta)
  dispatch_after(when, dispatch_get_main_queue(), cb)
}

func freshSession () -> NSURLSession {
  let conf = NSURLSessionConfiguration.defaultSessionConfiguration()
  conf.HTTPShouldUsePipelining = true
  conf.requestCachePolicy = .ReloadIgnoringLocalCacheData
  return NSURLSession(configuration: conf)
}

struct Query: MangerQuery {
  let url: String
  let since: NSDate
  
  init (url: String, since: NSDate = NSDate(timeIntervalSince1970: 0)) {
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

class MangerFailures: XCTestCase {
  var session: NSURLSession!
  var queue: dispatch_queue_t!
  var svc: MangerService!
  
  override func setUp () {
    super.setUp()
    queue = dispatch_queue_create("com.michaelnisi.patron.json", DISPATCH_QUEUE_CONCURRENT)
    session = freshSession()
    let url = NSURL(string: "http://localhost:8385")!
    svc = Manger(URL: url, queue: queue, session: session)
  }
  
  override func tearDown() {
    session.invalidateAndCancel()
    svc = nil
    super.tearDown()
  }
  
  func callbackWithExpression (exp: XCTestExpectation) -> (ErrorType?, Any?) -> Void {
    func cb (error: ErrorType?, result: Any?)-> Void {
      let er = error as! NSError
      XCTAssertEqual(er.code, -1004)
      XCTAssertNil(result)
      exp.fulfill()
    }
    return cb
  }
  
  func testEntries () {
    let exp = self.expectationWithDescription("entries")
    let cb = callbackWithExpression(exp)
    try! svc.entries(queries, cb: cb)
    self.waitForExpectationsWithTimeout(10) { er in
      XCTAssertNil(er)
    }
  }
  
  func testFeeds () {
    let exp = self.expectationWithDescription("feeds")
    let cb = callbackWithExpression(exp)
    try! svc.feeds(queries, cb: cb)
    self.waitForExpectationsWithTimeout(10) { er in
      XCTAssertNil(er)
    }
  }
  
  func testVersion () {
    let exp = self.expectationWithDescription("version")
    let cb = callbackWithExpression(exp)
    try! svc.version(cb)
    self.waitForExpectationsWithTimeout(10) { er in
      XCTAssertNil(er)
    }
  }
}

class MangerKitTests: XCTestCase {
  var session: NSURLSession!
  var queue: dispatch_queue_t!
  var svc: MangerService!
  
  override func setUp () {
    super.setUp()
    queue = dispatch_queue_create("com.michaelnisi.patron.json", DISPATCH_QUEUE_CONCURRENT)
    session = freshSession()
    let url = NSURL(string: "http://localhost:8384")!
    svc = Manger(URL: url, queue: queue, session: session)
  }
  
  override func tearDown () {
    super.tearDown()
  }
  
  func testEntriesWithEmptyQueries () {
    let exp = self.expectationWithDescription("entries")
    let q = [MangerQuery]()
    do {
      try svc.entries(q) { _, _ in }
    } catch MangerError.NoQueries {
      exp.fulfill()
    } catch {
      XCTFail("should throw expected error")
    }
    self.waitForExpectationsWithTimeout(10) { er in
      XCTAssertNil(er)
    }
  }
  
  func testEntries () {
    let exp = self.expectationWithDescription("entries")
    try! svc.entries(queries) { error, entries in
      XCTAssertNil(error)
      XCTAssert(entries!.count > 0)
      exp.fulfill()
    }
    self.waitForExpectationsWithTimeout(10) { er in
      XCTAssertNil(er)
    }
  }
  
  func testEntriesCancel () {
    let exp = self.expectationWithDescription("entries")
    let op = try! svc.entries(queries) { error, entries in
      defer {
        exp.fulfill()
      }
      guard entries == nil else {
        return
      }
      do {
        throw error!
      } catch MangerError.CancelledByUser {
      } catch {
        XCTFail("should be expected error")
      }
    }
    delay() {
      op.cancel()
    }
    self.waitForExpectationsWithTimeout(10) { er in
      XCTAssertNil(er)
    }
  }
  
  func testEntriesWithInvalidQueries () {
    let exp = self.expectationWithDescription("entries")
    do {
      try svc.entries(invalidQueries) { _, _ in }
    } catch MangerError.InvalidQuery {
      exp.fulfill()
    } catch {
      XCTFail("should throw expected error")
    }
    self.waitForExpectationsWithTimeout(10) { er in
      XCTAssertNil(er)
    }
  }
  
  func testFeeds () {
    let exp = self.expectationWithDescription("feeds")
    try! svc.feeds(queries) { error, feeds in
      XCTAssertNil(error)
      XCTAssertEqual(feeds!.count, queries.count)
      exp.fulfill()
    }
    self.waitForExpectationsWithTimeout(10) { er in
      XCTAssertNil(er)
    }
  }
  
  func testFeedsCancel () {
    let exp = self.expectationWithDescription("feeds")
    let op = try! svc.feeds(queries) { error, feeds in
      defer {
        exp.fulfill()
      }
      guard feeds == nil else {
        return
      }
      do {
        throw error!
      } catch MangerError.CancelledByUser {
      } catch {
        XCTFail("should be expected error")
      }
    }
    delay() {
      op.cancel()
    }
    self.waitForExpectationsWithTimeout(10) { er in
      XCTAssertNil(er)
    }
  }
  
  func testFeedsWithEmptyQueries () {
    let exp = self.expectationWithDescription("entries")
    let queries = [MangerQuery]()
    do {
      try svc.feeds(queries) { _, _ in }
    } catch MangerError.NoQueries {
      exp.fulfill()
    } catch {
      XCTFail("should throw expected error")
    }
    self.waitForExpectationsWithTimeout(10) { er in
      XCTAssertNil(er)
    }
  }
  
  func testFeedsWithInvalidQueries () {
    let exp = self.expectationWithDescription("entries")
    do {
      try svc.feeds(invalidQueries) { _, _ in }
    } catch MangerError.InvalidQuery {
      exp.fulfill()
    } catch {
      XCTFail("should throw expected error")
    }
    self.waitForExpectationsWithTimeout(10) { er in
      XCTAssertNil(er)
    }
  }
  
  func testVersion () {
    let exp = self.expectationWithDescription("version")
    try! svc.version() { error, version in
      XCTAssertNil(error)
      XCTAssertEqual(version, "1.0.3")
      exp.fulfill()
    }
    self.waitForExpectationsWithTimeout(10) { er in
      XCTAssertNil(er)
    }
  }
  
  func testVersionCancel () {
    let svc = self.svc!
    let exp = self.expectationWithDescription("version")
    let task = try! svc.version { error, version in
      do {
        throw error!
      } catch MangerError.CancelledByUser {
      } catch {
        XCTFail("should be expected error")
      }
      XCTAssertNil(version)
      exp.fulfill()
    }
    task.cancel()
    self.waitForExpectationsWithTimeout(10) { er in
      XCTAssertNil(er)
    }
  }
  
  func testHTTPBodyFromPayload () {
    let payload: Array<Dictionary<String, AnyObject>> = [
      ["url": "http://newyorker.com/feed/posts"],
      ["url": "http://newyorker.com/feed/posts", "since": "01 Sep 2015"]
    ]
    let body = HTTPBodyFromPayload(payload)
    let json = try! NSJSONSerialization.JSONObjectWithData(body, options: .AllowFragments)
    let found = json as! [NSDictionary]
    let wanted = payload
    XCTAssertEqual(found, wanted)
  }
}
