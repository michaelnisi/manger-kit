//
//  MasterViewController.swift
//  MangerExample
//
//  Created by Michael on 8/27/15.
//  Copyright © 2015 Michael Nisi. All rights reserved.
//

import UIKit
import MangerKit

class MasterViewController: UITableViewController {
  
  var detailViewController: DetailViewController? = nil
  
  var items: [Item] = DetailedItems
  let svc = MangerService()

   // MARK: - View controller
  
  override func viewDidLoad() {
    super.viewDidLoad()
    if let split = self.splitViewController {
      let controllers = split.viewControllers
      self.detailViewController = (controllers[controllers.count-1]
        as! UINavigationController).topViewController as? DetailViewController
    }
  }
  
  override func viewWillAppear(animated: Bool) {
    self.clearsSelectionOnViewWillAppear = self.splitViewController!.collapsed
    super.viewWillAppear(animated)
  }
  
  override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
    if segue.identifier == "showDetail" {
      if let indexPath = self.tableView.indexPathForSelectedRow {
        let item = items[indexPath.row]
        let controller = (segue.destinationViewController
          as! UINavigationController).topViewController as! DetailViewController
        controller.detailItem = item
        controller.svc = svc
      }
    }
  }

  // MARK: - Table View

  override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
    return 1
  }

  override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return items.count
  }

  override func tableView(tableView: UITableView,
    cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath)
    let item = items[indexPath.row]
    cell.textLabel!.text = item.title
    return cell
  }
}

