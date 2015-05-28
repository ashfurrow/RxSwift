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

class TableViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    
    let users = Variable([User]())
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.rightBarButtonItem = self.editButtonItem()
        
        let cellFactory = { (tv:UITableView, ip: NSIndexPath, obj: AnyObject) -> UITableViewCell in
            let cell = tv.dequeueReusableCellWithIdentifier("Cell") as! UITableViewCell
            let user = (obj as! User)
            cell.textLabel?.text = user.firstName + " " + user.lastName
            return cell
        }
        
        users
            >- tableView.rx_subscribeRowsTo(cellFactory)
        
        tableView.rx_rowTap()
            >- subscribeNext { [unowned self] (tv, index) in
                let sb = UIStoryboard(name: "Main", bundle: NSBundle(identifier: "RxExample-iOS"))
                let vc = sb.instantiateViewControllerWithIdentifier("DetailViewController") as! DetailViewController
                vc.user = self.getUser(index)
                self.navigationController?.pushViewController(vc, animated: true)
            }
        
        tableView.rx_rowDelete()
            >- subscribeNext { [unowned self] (tv, index) in
                self.removeUser(index)
            }
        
        tableView.rx_rowMove()
            >- subscribeNext { [unowned self] (tv, from, to) in
                self.moveUserFrom(from, to: to)
            }
        
        getSearchResults()
            >- subscribeNext { [unowned self] array in
                self.users.next(array)
            }
        
    }
    
    override func setEditing(editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        tableView.editing = editing
    }
    
    
    // MARK: Work over Variable
    
    func getUser(index: Int) -> User {
        var array = users.value
        return array[index]
    }
    
    func moveUserFrom(from: Int, to: Int) {
        var array = users.value
        let user = array.removeAtIndex(from)
        array.insert(user, atIndex: to)
        users.next(array)
    }
    
    func addUser(user: User) {
        var array = users.value
        array.append(user)
        users.next(array)
    }
    
    func removeUser(index: Int) {
        var array = users.value
        array.removeAtIndex(index)
        users.next(array)
    }
    
    
    // MARK: RandomUser API
    
    private func getSearchResults() -> Observable<[User]> {
        let url = NSURL(string: "http://api.randomuser.me/?results=20")!
        return NSURLSession.sharedSession().rx_JSON(url)
            >- observeSingleOn(Dependencies.sharedDependencies.backgroundWorkScheduler)
            >- mapOrDie { json in
                return castOrFail(json).flatMap { (json: [String: AnyObject]) in
                    return self.parseJSON(json)
                }
            }
            >- observeSingleOn(Dependencies.sharedDependencies.mainScheduler)
    }
    
    private func parseJSON(json: [String: AnyObject]) -> RxResult<[User]> {
        let results = json["results"] as? [[String: AnyObject]]
        let users = results?.map { $0["user"] as? [String: AnyObject] }
        
        let error = NSError(domain: "UserAPI", code: 0, userInfo: nil)
        
        if let users = users {
            let searchResults: [RxResult<User>] = users.map { user in
                let name = user?["name"] as? [String: String]
                let pictures = user?["picture"] as? [String: String]
                
                if let firstName = name?["first"], let lastName = name?["last"], let imageURL = pictures?["medium"] {
                    return success(User(firstName: self.ufc(firstName), lastName: self.ufc(lastName), imageURL: imageURL))
                }
                else {
                    return failure(error)
                }
            }
            
            let values = (searchResults.filter { $0.isSuccess }).map { $0.get() }
            return success(values)
        }
        return failure(error)
    }
    
    private func ufc(string: String) -> String {
        var result = Array(string)
        if !string.isEmpty { result[0] = Character(String(result.first!).uppercaseString) }
        return String(result)
    }
    
}
