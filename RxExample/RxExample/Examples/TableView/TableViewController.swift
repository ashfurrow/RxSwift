//
//  TableViewController.swift
//  RxExample
//
//  Created by carlos on 26/5/15.
//  Copyright (c) 2015 Krunoslav Zaher. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

func delay(delay:Double, closure:()->()) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(delay * Double(NSEC_PER_SEC))),
        dispatch_get_main_queue(),
        closure)
}

class TableViewController: UITableViewController {
    
    let paybacks = Variable([Payback]())
    let tvdt = RxTableViewDelegate()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.dataSource = nil // it is necesary
        
        
        let cellFactory = { (tv:UITableView, ip: NSIndexPath, obj: AnyObject) -> UITableViewCell in
            let cell = tv.dequeueReusableCellWithIdentifier("Cell") as! UITableViewCell
            
            let payback = (obj as! Payback)
            
            cell.textLabel?.text = payback.firstName + " " + payback.lastName
            
            return cell
        }
        
        let tvds = RxTableViewDataSource(cellFactory: cellFactory)
        tableView.delegate = tvdt
        
        tableView.rx_rowTap()
            >- subscribeNext { (tv, index) in
                let sb = UIStoryboard(name: "Main", bundle: NSBundle(identifier: "RxExample-iOS"))
                let vc = sb.instantiateViewControllerWithIdentifier("DetailViewController") as! DetailViewController
                self.navigationController?.pushViewController(vc, animated: true)
        }
        
        paybacks
            >- tableView.rx_subscribeRowsTo(tvds)
        
        tableView.rx_rowDelete()
            >- subscribeNext { (tv, index) in
                self.removePayback(index)
            }
        
        addPayback(Payback(firstName: "Kruno", lastName: "Zaher", createdAt: NSDate(), amount: 22))
        
        delay(1) { [unowned self] in
            self.addPayback(Payback(firstName: "Carlos", lastName: "García", createdAt: NSDate(), amount: 22))
        }
        
    }
    
    
    func addPayback(payback: Payback) {
        var array = paybacks.value
        array.append(payback)
        paybacks.next(array)
    }
    
    func removePayback(index: Int) {
        var array = paybacks.value
        array.removeAtIndex(index)
        paybacks.next(array)
    }

}
