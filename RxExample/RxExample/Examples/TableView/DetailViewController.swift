//
//  DetailViewController.swift
//  RxExample
//
//  Created by carlos on 26/5/15.
//  Copyright (c) 2015 Krunoslav Zaher. All rights reserved.
//

import UIKit
import RxSwift

class DetailViewController: UIViewController {
    
    weak var masterVC: TableViewController!
    var user: User!
    
    var disposeBag = DisposeBag()
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var label: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        imageView.layer.cornerRadius = imageView.frame.size.width / 2
        imageView.layer.borderColor = UIColor.darkGrayColor().CGColor
        imageView.layer.borderWidth = 5
        imageView.layer.masksToBounds = true
        
        let url = NSURL(string: user.imageURL)!
        let request = NSURLRequest(URL: url)
        
        NSURLSession.sharedSession().rx_data(request)
            >- observeSingleOn(Dependencies.sharedDependencies.mainScheduler)
            >- subscribeNext { data in
                let image = UIImage(data: data)
                self.imageView.image = image
            }
            >- disposeBag.addDisposable
        
        label.text = user.firstName + " " + user.lastName
    }
    
    deinit {
        disposeBag.dispose()
    }

}
