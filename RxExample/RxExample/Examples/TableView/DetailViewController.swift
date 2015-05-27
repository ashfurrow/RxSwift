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
    var payback: Payback!
    
    @IBOutlet weak var firstNameTF: UITextField!
    @IBOutlet weak var lastNameTF: UITextField!
    @IBOutlet weak var amountTF: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        firstNameTF.text = payback.firstName
        lastNameTF.text = payback.lastName
        amountTF.text = "\(payback.amount)"
    }

}
