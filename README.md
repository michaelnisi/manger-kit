# MangerKit

Browse podcasts with MangerKit. The MangerKit Swift package provides a JSON HTTP client that lets you request combined ranges of podcast feeds from the [manger-http](https://github.com/michaelnisi/manger-http) service, a caching RSS feed proxy.

MangerKit is used in the [Podest](https://github.com/michaelnisi/podest) podcast app.

## Example

Requesting all episodes of three podcasts. You can limit the time range with the `since` property.

```swift
import Foundation
import Patron
import MangerKit

let url = URL(string: "https://your.endpoint")!
let s = URLSession(configuration: .default)
let p = Patron(URL: url, session: s)
let svc = Manger(client: p)

struct Query: MangerQuery {
  let url: String
  let since: Date

  init(url: String, since: Date = Date(timeIntervalSince1970: 0)) {
    self.url = url
    self.since = since
  }
}

let queries: [MangerQuery] = [
  Query(url: "http://feeds.wnyc.org/newyorkerradiohour"),
  Query(url: "http://feed.thisamericanlife.org/talpodcast"),
  Query(url: "http://feeds.serialpodcast.org/serialpodcast")
]

try! svc.entries(queries) { result, error in
  print(error ?? result)
}
```

The result is an unprocessed array of dictionaries, `[[String: AnyObject]]?`, typed `Any?` because JSON. Please refer to [manger-http](https://github.com/michaelnisi/manger-http) for details.

## Dependencies

- [Patron](https://github.com/michaelnisi/patron), JSON HTTP client

## Types

### MangerError

The simple error type also covers invalid queries.

```swift
enum MangerError: Error {
  case unexpectedResult(result: Any?)
  case cancelledByUser
  case noQueries
  case invalidQuery
  case niy
}
```

### MangerQuery

Today, I don’t see why queries shouldn’t be `struct`—[why we should be critical of using protocols](http://chris.eidhof.nl/post/protocol-oriented-programming/).

```swift
protocol MangerQuery {
  var url: String { get }
  var since: Date { get }
}
```

### MangerService

```swift
protocol MangerService {
  var client: JSONService { get }

  @discardableResult func feeds(
    _ queries: [MangerQuery],
    cachePolicy: NSURLRequest.CachePolicy,
    cb: @escaping (_ error: Error?, _ payload: [[String : AnyObject]]?) -> Void
  ) throws -> URLSessionTask

  @discardableResult func feeds(
    _ queries: [MangerQuery],
    cb: @escaping (_ error: Error?, _ payload: [[String : AnyObject]]?) -> Void
  ) throws -> URLSessionTask

  @discardableResult func entries(
    _ queries: [MangerQuery],
    cachePolicy: NSURLRequest.CachePolicy,
    cb: @escaping (_ error: Error?, _ payload: [[String : AnyObject]]?) -> Void
  ) throws -> URLSessionTask

  @discardableResult func entries(
    _ queries: [MangerQuery],
    cb: @escaping (_ error: Error?, _ payload: [[String : AnyObject]]?) -> Void
  ) throws -> URLSessionTask

  @discardableResult func version(
    _ cb: @escaping (_ error: Error?, _ service: String?) -> Void
  ) throws -> URLSessionTask
}
```

#### client

```swift
var client: JSONService { get }
```

The client property gives access to the underlying [Patron](https://github.com/michaelnisi/patron) client, providing hostname and status of the remote service.

## Test

With **manger-http** running, do:

```
$ swift test
```

## Install

📦 Add `https://github.com/michaelnisi/manger-kit`  to your package manifest.

## License

[MIT License](https://github.com/michaelnisi/manger-kit/blob/master/LICENSE)
