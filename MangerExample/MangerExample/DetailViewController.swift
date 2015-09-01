//
//  DetailViewController.swift
//  MangerExample
//
//  Created by Michael on 8/27/15.
//  Copyright © 2015 Michael Nisi. All rights reserved.
//

import UIKit
import MangerKit

enum ItemType: Int {
  case Version
  case Cleartext
  case NotFound
}

struct Item {
  let title: String
  let type: ItemType
}

let DetailedItems = [
  Item(title: "GET /", type: .Version),
  Item(title: "Cleartext HTTP", type: .Cleartext),
  Item(title: "Not found", type: .NotFound)
]

class DetailViewController: UIViewController {
  @IBOutlet weak var detailDescriptionLabel: UILabel!
  
  var detailItem: Item?
  var svc: MangerService?
  
  weak var op: NSOperation?
  
  func ping (url: NSURL?) {
    let label = detailDescriptionLabel
    op = svc?.ping(url) { json, error in
      var text: String?
      if let er = error {
        text = "\(er)"
      } else if let desc = json?.first?.description {
        text = desc
      }
      if text != nil {
        dispatch_async(dispatch_get_main_queue(), {
          label.text = text
        })
      }
    }
  }
  
  func update() {
    if let detail = self.detailItem {
      if let label = self.detailDescriptionLabel {
        label.text = detail.title
      }
      switch detail.type {
      case .Version:
        ping(nil)
      case .Cleartext:
        let url = NSURL(string: "http://google.com")!
        ping(url)
      case .NotFound:
        let url = NSURL(string: "https://nowhere")!
        ping(url)
      }
    }
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    update()
  }
  
  deinit {
    op?.cancel()
  }
}

