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

class TableViewController: ViewController {
    
    @IBOutlet weak var tableView: UITableView!
    
    var disposeBag = DisposeBag()
    
    let users = Variable([User]())
    let favoriteUsers = Variable([User]())
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.rightBarButtonItem = self.editButtonItem()
        
        let cellFactory = { (tv:UITableView, ip: NSIndexPath, obj: AnyObject) -> UITableViewCell in
            let cell = tv.dequeueReusableCellWithIdentifier("Cell") as! UITableViewCell
            let user = (obj as! User)
            cell.textLabel?.text = user.firstName + " " + user.lastName
            return cell
        }
        
        let tvds = RxTableViewDataSource(cellFactory: cellFactory, sections: ["Favorite Users", "Normal users"])
        
        favoriteUsers
            >- tableView.rx_subscribeRowsTo(tvds, section: 1)
            >- disposeBag.addDisposable
        
        users
            >- tableView.rx_subscribeRowsTo(tvds, section: 2)
            >- disposeBag.addDisposable
        
        tableView.rx_rowTapped()
            >- subscribeNext { [unowned self] (tv, indexPath) in
                self.showDetailsForUser(indexPath)
            }
            >- disposeBag.addDisposable
        
        tableView.rx_rowDeleted()
            >- subscribeNext { [unowned self] (tv, indexPath) in
                self.removeUser(indexPath)
            }
            >- disposeBag.addDisposable
        
        tableView.rx_rowMoved()
            >- subscribeNext { [unowned self] (tv, from, to) in
                self.moveUserFrom(from, to: to)
            }
            >- disposeBag.addDisposable
        
        RandomUserAPI.sharedAPI.getExampleUserResultSet()
            >- subscribeNext { [unowned self] array in
                self.users.next(array)
            }
            >- disposeBag.addDisposable
        
        
        
        favoriteUsers.next([User(firstName: "Super", lastName: "Man", imageURL: "http://nerdreactor.com/wp-content/uploads/2015/02/Superman1.jpg")])
    }
    
    override func setEditing(editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        tableView.editing = editing
    }
    
    
    // MARK: Navigation
    
    private func showDetailsForUser(indexPath: NSIndexPath) {
        let sb = UIStoryboard(name: "Main", bundle: NSBundle(identifier: "RxExample-iOS"))
        let vc = sb.instantiateViewControllerWithIdentifier("DetailViewController") as! DetailViewController
        vc.user = self.getUser(indexPath)
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    // MARK: Work over Variable
    
    func getUser(indexPath: NSIndexPath) -> User {
        var array: [User]
        switch indexPath.section {
        case 0:
            array = favoriteUsers.value
        case 1:
            array = users.value
        default:
            fatalError("Section out of range")
        }
        return array[indexPath.row]
    }
    
    func moveUserFrom(from: NSIndexPath, to: NSIndexPath) {
        var user: User
        var fromArray: [User]
        var toArray: [User]
        
        switch from.section {
        case 0:
            fromArray = favoriteUsers.value
            user = fromArray.removeAtIndex(from.row)
            favoriteUsers.next(fromArray)
        case 1:
            fromArray = users.value
            user = fromArray.removeAtIndex(from.row)
            users.next(fromArray)
        default:
            fatalError("Section out of range")
        }
        
        
        switch to.section {
        case 0:
            toArray = favoriteUsers.value
            toArray.insert(user, atIndex: to.row)
            favoriteUsers.next(toArray)
        case 1:
            toArray = users.value
            toArray.insert(user, atIndex: to.row)
            users.next(toArray)
        default:
            fatalError("Section out of range")
        }
    }
    
    func addUser(user: User) {
        var array = users.value
        array.append(user)
        users.next(array)
    }
    
    func removeUser(indexPath: NSIndexPath) {
        var array: [User]
        switch indexPath.section {
        case 0:
            array = favoriteUsers.value
            array.removeAtIndex(indexPath.row)
            favoriteUsers.next(array)
        case 1:
            array = users.value
            array.removeAtIndex(indexPath.row)
            users.next(array)
        default:
            fatalError("Section out of range")
        }
    }
    
}
