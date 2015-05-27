//
//  UITableView+Rx.swift
//  RxCocoa
//
//  Created by Krunoslav Zaher on 4/2/15.
//  Copyright (c) 2015 Krunoslav Zaher. All rights reserved.
//

import Foundation
import RxSwift
import UIKit

// This cannot be a generic class because of table view objc runtime that checks for 
// implemented selectors in data source
public class RxTableViewDataSource :  NSObject, UITableViewDataSource {
    public typealias CellFactory = (UITableView, NSIndexPath, AnyObject) -> UITableViewCell
    
    public typealias RowDeletedObserver = ObserverOf<(tableView: UITableView, row: Int)>
    public typealias RowMovedObserver = ObserverOf<(tableView: UITableView, from: Int, to: Int)>
    
    public typealias RowDeletedDisposeKey = Bag<RowDeletedObserver>.KeyType
    public typealias RowMovedDisposeKey = Bag<RowMovedObserver>.KeyType
    
    var tableViewRowDeletedObservers: Bag<RowDeletedObserver>
    var tableViewRowMovedObservers: Bag<RowMovedObserver>
    
    public var rows: [AnyObject] {
        get {
            return _rows
        }
    }
    
    var _rows: [AnyObject]
    
    var cellFactory: CellFactory! = nil
    
    public init(cellFactory: CellFactory) {
        tableViewRowDeletedObservers = Bag()
        tableViewRowMovedObservers = Bag()
        self._rows = []
        self.cellFactory = cellFactory
    }
    
    public func addTableViewRowDeletedObserver(observer: RowDeletedObserver) -> RowDeletedDisposeKey {
        MainScheduler.ensureExecutingOnScheduler()
        
        return tableViewRowDeletedObservers.put(observer)
    }
    
    public func addTableViewRowMovedObserver(observer: RowMovedObserver) -> RowMovedDisposeKey {
        MainScheduler.ensureExecutingOnScheduler()
        
        return tableViewRowMovedObservers.put(observer)
    }
    
    public func removeTableViewRowDeletedObserver(key: RowDeletedDisposeKey) {
        MainScheduler.ensureExecutingOnScheduler()
        
        let element = tableViewRowDeletedObservers.removeKey(key)
        if element == nil {
            removingObserverFailed()
        }
    }
    
    public func removeTableViewRowMovedObserver(key: RowMovedDisposeKey) {
        MainScheduler.ensureExecutingOnScheduler()
        
        let element = tableViewRowMovedObservers.removeKey(key)
        if element == nil {
            removingObserverFailed()
        }
    }
    
    public func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    public func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return _rows.count
    }
    
    public func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        if indexPath.row < _rows.count {
            let row = indexPath.row
            if cellFactory == nil {
                rxFatalError("Please subscribe table rows using one of the 'rx_subscribeRowsTo' methods")
            }
            return cellFactory(tableView, indexPath, self._rows[row])
        }
        else {
            rxFatalError("something went wrong")
            let cell: UITableViewCell? = nil
            return cell!
        }
    }
    
    public func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        if tableViewRowDeletedObservers.count > 0 {
            return true
        }
        return false
    }
    
    public func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            dispatchNext((tableView, indexPath.row), tableViewRowDeletedObservers)
        }
    }
    
    public func tableView(tableView: UITableView, canMoveRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        if tableViewRowMovedObservers.count > 0 {
            return true
        }
        return false
    }
    
    public func tableView(tableView: UITableView, moveRowAtIndexPath sourceIndexPath: NSIndexPath, toIndexPath destinationIndexPath: NSIndexPath) {
        dispatchNext((tableView, sourceIndexPath.row, destinationIndexPath.row), tableViewRowMovedObservers)
    }
}

public class RxTableViewDelegate: RxScrollViewDelegate, UITableViewDelegate {
    public typealias RowTapedObserver = ObserverOf<(tableView: UITableView, row: Int)>
    
    public typealias RowTapedDisposeKey = Bag<RowTapedObserver>.KeyType
    
    var tableViewRowTapedObservers: Bag<RowTapedObserver>
    
    override public init() {
        tableViewRowTapedObservers = Bag()
    }
    
    public func addTableViewRowTapedObserver(observer: RowTapedObserver) -> RowTapedDisposeKey {
        MainScheduler.ensureExecutingOnScheduler()
        
        return tableViewRowTapedObservers.put(observer)
    }
    
    public func removeTableViewRowTapedObserver(key: RowTapedDisposeKey) {
        MainScheduler.ensureExecutingOnScheduler()
        
        let element = tableViewRowTapedObservers.removeKey(key)
        if element == nil {
            removingObserverFailed()
        }
    }
 
    public func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
        
        dispatchNext((tableView, indexPath.row), tableViewRowTapedObservers)
    }
    
    deinit {
        if tableViewRowTapedObservers.count > 0 {
            handleVoidObserverResult(failure(rxError(RxCocoaError.InvalidOperation, "Something went wrong. Deallocating table view delegate while there are still subscribed observers means that some subscription was left undisposed.")))
        }
    }
}

// This is the most simple (but probably most common) way of using rx with UITableView.
extension UITableView {
    override func rx_createDelegate() -> RxScrollViewDelegate {
        return RxTableViewDelegate()
    }
    
    func rx_createDataSource() -> RxTableViewDataSource {
        return RxTableViewDataSource(cellFactory: { a, b, c in UITableViewCell() })
    }
    
    public func rx_subscribeRowsTo<E where E: AnyObject>
        (dataSource: RxTableViewDataSource)
        (source: Observable<[E]>)
        -> Disposable {
        MainScheduler.ensureExecutingOnScheduler()
        
        if self.dataSource != nil && self.dataSource !== dataSource {
            rxFatalError("Data source is different")
        }

        self.dataSource = dataSource
            
        let clearDataSource = AnonymousDisposable {
            if self.dataSource != nil && self.dataSource !== dataSource {
                rxFatalError("Data source is different")
            }
            
            self.dataSource = nil
        }
            
        let disposable = source.subscribe(AnonymousObserver { event in
            MainScheduler.ensureExecutingOnScheduler()
            
            switch event {
            case .Next(let boxedValue):
                let value = boxedValue.value
                dataSource._rows = value
                self.reloadData()
            case .Error(let error):
#if DEBUG
                rxFatalError("Something went wrong: \(error)")
#endif
            case .Completed:
                break
            }
        })
            
        return CompositeDisposable(clearDataSource, disposable)
    }
    
    public func rx_subscribeRowsTo<E where E : AnyObject>
        (cellFactory: (UITableView, NSIndexPath, E) -> UITableViewCell)
        (source: Observable<[E]>)
        -> Disposable {
            
        let dataSource = RxTableViewDataSource {
            cellFactory($0, $1, $2 as! E)
        }
            
        return self.rx_subscribeRowsTo(dataSource)(source: source)
    }
    
    public func rx_subscribeRowsToCellWithIdentifier<E, Cell where E : AnyObject, Cell: UITableViewCell>
        (cellIdentifier: String, configureCell: (UITableView, NSIndexPath, E, Cell) -> Void)
        (source: Observable<[E]>)
        -> Disposable {
            
        let dataSource = RxTableViewDataSource {
            let cell = $0.dequeueReusableCellWithIdentifier(cellIdentifier, forIndexPath: $1) as! Cell
            configureCell($0, $1, $2 as! E, cell)
            return cell
        }
        
        return self.rx_subscribeRowsTo(dataSource)(source: source)
    }
    
    public func rx_rowTap() -> Observable<(tableView: UITableView, row: Int)> {
        _ = rx_checkTableViewDelegate()
        
        return AnonymousObservable { observer in
            MainScheduler.ensureExecutingOnScheduler()
            
            let delegate = self.ensureCorrectDelegate()
            
            let key = delegate.addTableViewRowTapedObserver(observer)
            
            return AnonymousDisposable {
                MainScheduler.ensureExecutingOnScheduler()
                
                _ = self.rx_checkTableViewDelegate()
                
                delegate.removeTableViewRowTapedObserver(key)
                
                if delegate.tableViewRowTapedObservers.count == 0 {
                    self.delegate = nil
                }
            }
        }
    }
    
    public func rx_rowDelete() -> Observable<(tableView: UITableView, row: Int)> {
        _ = rx_checkTableViewDataSource()
        
        return AnonymousObservable { observer in
            MainScheduler.ensureExecutingOnScheduler()
            
            let dataSource = self.ensureCorrectDataSource()
            
            let key = dataSource.addTableViewRowDeletedObserver(observer)
            
            return AnonymousDisposable {
                MainScheduler.ensureExecutingOnScheduler()
                
                _ = self.rx_checkTableViewDataSource()
                
                dataSource.removeTableViewRowDeletedObserver(key)
            }
        }
    }
    
    public func rx_rowMove() -> Observable<(tableView: UITableView, from: Int, to: Int)> {
        _ = rx_checkTableViewDataSource()
        
        return AnonymousObservable { observer in
            MainScheduler.ensureExecutingOnScheduler()
            
            let dataSource = self.ensureCorrectDataSource()
            
            let key = dataSource.addTableViewRowMovedObserver(observer)
            
            return AnonymousDisposable {
                MainScheduler.ensureExecutingOnScheduler()
                
                _ = self.rx_checkTableViewDataSource()
                
                dataSource.removeTableViewRowMovedObserver(key)
            }
        }
    }
    
    public func rx_elementTap<E>() -> Observable<E> {
        
        return rx_rowTap() >- map { (tableView, rowIndex) -> E in
            let maybeDataSource: RxTableViewDataSource? = self.rx_getTableViewDataSource()
            
            if maybeDataSource == nil {
                rxFatalError("To use element tap table view needs to use table view data source. You can still use `rx_observableRowTap`.")
            }
            
            let dataSource = maybeDataSource!
            
            return dataSource.rows[rowIndex] as! E
        }
    }
    
    // private methods
   
    private func rx_getTableViewDataSource() -> RxTableViewDataSource? {
        MainScheduler.ensureExecutingOnScheduler()
        
        if self.dataSource == nil {
            return nil
        }
        
        let maybeDataSource = self.dataSource as? RxTableViewDataSource
        
        if maybeDataSource == nil {
            rxFatalError("View already has incompatible data source set. Please remove earlier delegate registration.")
        }
        
        return maybeDataSource!
    }
    
    private func rx_checkTableViewDataSource() -> RxTableViewDataSource? {
        MainScheduler.ensureExecutingOnScheduler()
        
        if self.dataSource == nil {
            return nil
        }
        
        let maybeDataSource = self.dataSource as? RxTableViewDataSource
        
        if maybeDataSource == nil {
            rxFatalError("View already has incompatible data source set. Please remove earlier delegate registration.")
        }
        
        return maybeDataSource!
    }
    
    private func rx_checkTableViewDelegate() -> RxTableViewDelegate? {
        MainScheduler.ensureExecutingOnScheduler()
        
        if self.delegate == nil {
            return nil
        }
        
        let maybeDelegate = self.delegate as? RxTableViewDelegate
        
        if maybeDelegate == nil {
            rxFatalError("View already has incompatible delegate set. To use rx observable (for now) please remove earlier delegate registration.")
        }
        
        return maybeDelegate!
    }
    
    private func ensureCorrectDelegate() -> RxTableViewDelegate {
        var maybeDelegate = self.rx_checkTableViewDelegate()
        
        if maybeDelegate == nil {
            let delegate = self.rx_createDelegate() as! RxTableViewDelegate
            self.delegate = delegate
            return delegate
        }
        else {
            return maybeDelegate!
        }
    }
    
    private func ensureCorrectDataSource() -> RxTableViewDataSource {
        var maybeDataSource = self.rx_checkTableViewDataSource()
        
        if maybeDataSource == nil {
            let dataSource = self.rx_createDataSource()
            self.dataSource = dataSource
            return dataSource
        }
        else {
            return maybeDataSource!
        }
    }
}