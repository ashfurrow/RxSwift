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

let tableViewWrongDelegatesMessage = "Please use rx data source `RxTableViewDataSource` and rx delegate `RxTableViewDelegate` for this table view. You can set them manually or using one of the following methods:\n    rx_subscribeTo\n    rx_subscribeToCellWithIdentifier\n    ..."

public protocol RxTableViewDataSourceBridgeProtocol : class {
    func onRowsSequenceEvent(tableView: UITableView, event: AnyObject)
    func onRowsSequenceIncrementalEvent(tableView: UITableView, event: AnyObject)
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell
    
    func typedBridge<T>() -> T
}

public class RxTableViewDataSourceItemsBridge<Item> {
    public func itemAtIndexPath(indexPath: NSIndexPath) -> Item {
        return rxAbstractMethod()
    }
}

public class RxTableViewDataSourceBridge<Section, Item> : RxTableViewDataSourceItemsBridge<Item>, RxTableViewDataSourceBridgeProtocol {
    public typealias CellFactory = (UITableView, NSIndexPath, Section, Item) -> UITableViewCell
    public typealias SectionInfo = (section: Section, items: [Item])
    
    public var sections: [SectionInfo] = []
    
    public var cellFactory: CellFactory! = nil
    
    public var rowAnimation: UITableViewRowAnimation = .Automatic
    
    private var transactionState: UITransactionState = .Idle
    
    private func ensureTransactionStateGrammar(wantedTransactionState: UITransactionState, event: Event<IncrementalUpdateEvent<Section, Item>>, @noescape action: () -> Void) {
        if transactionState != wantedTransactionState {
            rxPossiblyFatalError("There was an error with state transition during processing of `\(event)`. Expected state was `\(wantedTransactionState)` and actual state was `\(transactionState))`")
        }
        
        action()
    }
    
    public init(sections: [SectionInfo] = []) {
        self.sections = sections
        
        super.init()
        
        self.cellFactory = { [weak self] (_, _, _, _) in
            if let strongSelf = self {
                rxFatalError("There is a minor problem. `cellFactory` property on \(strongSelf) was not set. Please set it manually, or use one of the `rx_subscribeTo` methods.")
            }
            
            return (nil as UITableViewCell!)!
        }
    }
    
    // abstract methods
    
    public override func itemAtIndexPath(indexPath: NSIndexPath) -> Item {
        return sections[indexPath.section].items[indexPath.item]
    }
    
    // casting 
    
    public func typedBridge<T>() -> T {
        if let dataSource = self as? T {
            return dataSource
        }
        else {
            return rxFatalErrorAndDontReturn("There was a problem getting correct table view data source bridge from rx table view data source. It's type is `\(self)` and wanted type was \(T.self)")
        }
    }
    
    // sequence events
    
    public func onRowsSequenceEvent(tableView: UITableView, event: AnyObject) {
        let boxedEvent = event as! RxBox<Event<[SectionInfo]>>
        
        switch boxedEvent.value {
        case .Next(let boxedValue):
            let value = boxedValue.value
            sections = value
            tableView.reloadData()
        case .Error(let error):
#if DEBUG
            rxFatalError("Something went wrong: \(error)")
#endif
        case .Completed:
            break
        }
    }
    
    // The way sections and items are being updated now isn't how UITableView actually deals with
    // changes. But this is a good prototype for testing
    public func onRowsSequenceIncrementalEvent(tableView: UITableView, event boxedEvent: AnyObject) {
        let event = (boxedEvent as! RxBox<Event<IncrementalUpdateEvent<Section, Item>>>).value
        switch event {
        case .Next(let boxedValue):
            let incrementalUpdateEvent = boxedValue.value
            switch incrementalUpdateEvent {
            case .TransactionStarted:
                ensureTransactionStateGrammar(.Idle, event: event) {
                    tableView.beginUpdates()
                    transactionState = .Running
                }
            case .TransactionEnded:
                ensureTransactionStateGrammar(.Idle, event: event) {
                    tableView.endUpdates()
                }
            case .Snapshot(let boxedSnapshot):
                ensureTransactionStateGrammar(.Idle, event: event) {
                    self.sections = boxedSnapshot.value
                    tableView.reloadData()
                }
            case .ItemDeleted(from: let path):
                ensureTransactionStateGrammar(.Idle, event: event) {
                    self.sections[path.section].items.removeAtIndex(path.item)
                    tableView.deleteRowsAtIndexPaths([path], withRowAnimation: rowAnimation)
                }
            case .ItemInserted(item: let boxedItem, to: let path):
                ensureTransactionStateGrammar(.Idle, event: event) {
                    let newItem = boxedItem.value
                    self.sections[path.section].items.insert(newItem, atIndex: path.item)
                    tableView.insertRowsAtIndexPaths([path], withRowAnimation: rowAnimation)
                }
            case .ItemMoved(from: let from, to: let to):
                ensureTransactionStateGrammar(.Idle, event: event) {
                    let item = self.sections[from.section].items.removeAtIndex(from.item)
                    self.sections[to.section].items.insert(item, atIndex: to.item)
                    tableView.moveRowAtIndexPath(from, toIndexPath: to)
                }
            case .SectionInserted(section: let boxedSection, to: let to):
                ensureTransactionStateGrammar(.Idle, event: event) {
                    self.sections.insert(boxedSection.value, atIndex: to)
                    tableView.insertSections(NSIndexSet(index: to), withRowAnimation: rowAnimation)
                }
            case .SectionDeleted(from: let from):
                ensureTransactionStateGrammar(.Idle, event: event) {
                    self.sections.removeAtIndex(from)
                    tableView.deleteSections(NSIndexSet(index: from), withRowAnimation: rowAnimation)
                }
            case .SectionMoved(from: let from, to: let to):
                ensureTransactionStateGrammar(.Idle, event: event) {
                    let section = self.sections.removeAtIndex(from)
                    self.sections.insert(section, atIndex: to)
                }
            }
        case .Error(let error):
            #if DEBUG
                rxFatalError("Something went wrong: \(error)")
            #endif
        case .Completed:
            break
        }
    }
    
    // table view
    
    public func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return sections.count
    }
    
    public func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].items.count
    }
    
    public func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        if indexPath.item < sections[indexPath.section].items.count {
            let item = indexPath.item
            let section = sections[indexPath.section]
            return cellFactory(tableView, indexPath, section.section, section.items[item])
        }
        else {
            rxFatalError("something went wrong")
            let cell: UITableViewCell? = nil
            return cell!
        }
    }
    
}

// This cannot be a generic class because of table view objc runtime that checks for
// implemented selectors in data source
public class RxTableViewDataSource :  NSObject, UITableViewDataSource {
    public typealias RowDeletedObserver = ObserverOf<(tableView: UITableView, indexPath: NSIndexPath)>
    public typealias RowMovedObserver = ObserverOf<(tableView: UITableView, from: NSIndexPath, to: NSIndexPath)>
    
    public typealias RowDeletedDisposeKey = Bag<RowDeletedObserver>.KeyType
    public typealias RowMovedDisposeKey = Bag<RowMovedObserver>.KeyType
    
    var tableViewRowDeletedObservers: Bag<RowDeletedObserver> = Bag()
    var tableViewRowMovedObservers: Bag<RowMovedObserver> = Bag()
    
    public var bridge: RxTableViewDataSourceBridgeProtocol? = nil
    
    private var existingBridge: RxTableViewDataSourceBridgeProtocol {
        get {
            if let bridge = bridge {
                return bridge
            }
            
            return rxFatalErrorAndDontReturn("Please set data source `bridge` property. Using one of the standard methods to subscribe rows like `rx_subscribeTo` should set it properly.")
        }
    }
    
    override init() {
        super.init()
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
    
    public var isDisposable: Bool {
        get {
            return tableViewRowDeletedObservers.count == 0
            && tableViewRowMovedObservers.count == 0
            && bridge == nil
        }
    }
    
    // table view data source methods
   
    public func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return existingBridge.numberOfSectionsInTableView(tableView)
    }
    
    public func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return existingBridge.tableView(tableView, numberOfRowsInSection: section)
    }
    
    public func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        return existingBridge.tableView(tableView, cellForRowAtIndexPath: indexPath)
    }
    
    public func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        if tableViewRowDeletedObservers.count > 0 {
            return true
        }
        return false
    }
    
    public func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            dispatchNext((tableView, indexPath), tableViewRowDeletedObservers)
        }
    }
    
    public func tableView(tableView: UITableView, canMoveRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        if tableViewRowMovedObservers.count > 0 {
            return true
        }
        return false
    }
    
    public func tableView(tableView: UITableView, moveRowAtIndexPath sourceIndexPath: NSIndexPath, toIndexPath destinationIndexPath: NSIndexPath) {
        dispatchNext((tableView, sourceIndexPath, destinationIndexPath), tableViewRowMovedObservers)
    }
}

public class RxTableViewDelegate: RxScrollViewDelegate, UITableViewDelegate {
    public typealias RowTapedObserver = ObserverOf<(tableView: UITableView, indexPath: NSIndexPath)>
    
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
        
        dispatchNext((tableView, indexPath), tableViewRowTapedObservers)
    }
    
    public var isDisposable: Bool {
        get {
            return self.tableViewRowTapedObservers.count == 0
        }
    }
    
    deinit {
        if tableViewRowTapedObservers.count > 0 {
            handleVoidObserverResult(failure(rxError(RxCocoaError.InvalidOperation, "Something went wrong. Deallocating table view delegate while there are still subscribed observers means that some subscription was left undisposed.")))
        }
    }
}

// This is the most simple (but probably most common) way of using rx with UITableView.
extension UITableView {
 
    // factory methods
    
    public func rx_createBridge<Section, Row>() -> RxTableViewDataSourceBridge<Section, Row> {
        return RxTableViewDataSourceBridge()
    }
    
    override public func rx_createDelegate() -> RxTableViewDelegate {
        return RxTableViewDelegate()
    }
    
    public func rx_createDataSource() -> RxTableViewDataSource {
        return RxTableViewDataSource()
    }
    
    // `reloadData` - section subscription methods
    
    public func rx_subscribeSectionsTo<Section, Item>
        (bridge: RxTableViewDataSourceBridge<Section, Item>)
        -> Observable<[(section: Section, items: [Item])]> -> Disposable {
        return { source in
            MainScheduler.ensureExecutingOnScheduler()
            
            var dataSource = self.rx_getTableViewDataSource()
            
            let clearDataSource = AnonymousDisposable {
                contract(self.dataSource == nil || self.dataSource === dataSource)
                contract(dataSource!.existingBridge === bridge)
                
                if dataSource!.isDisposable {
                    self.dataSource = nil
                }
            }
                
            let disposable = source.subscribe(AnonymousObserver { event in
                MainScheduler.ensureExecutingOnScheduler()
                
                dataSource = self.rx_ensureTableViewDataSourceIsSet()
                
                if let existingBridge = dataSource?.bridge {
                    contract(existingBridge === bridge)
                }
                
                dataSource!.bridge = bridge
                
                dataSource!.existingBridge.onRowsSequenceEvent(self, event: RxBox(event))
            })
                
            return CompositeDisposable(clearDataSource, disposable)
        }
    }
    
    public func rx_subscribeSectionsTo<Section, Item>
        (cellFactory: (UITableView, NSIndexPath, Item) -> UITableViewCell)
        -> Observable<[(section: Section, items: [Item])]> -> Disposable {
        return { source in
            let bridge: RxTableViewDataSourceBridge<Section, Item> = self.rx_createBridge()
            bridge.cellFactory = { (tv, ip, _, item) in
                return cellFactory(tv, ip, item)
            }
                
            return self.rx_subscribeSectionsTo(bridge)(source)
        }
    }
    
    public func rx_subscribeSectionsToWithCellIdentifier<Section, Item, Cell: UITableViewCell>
        (cellIdentifier: String, configureCell: (NSIndexPath, Section, Item, Cell) -> Void)
        -> Observable<[(section: Section, items: [Item])]> -> Disposable {
        return { source in
            let dataSource = RxTableViewDataSourceBridge<Section, Item>()
            dataSource.cellFactory = { (tv, indexPath, section, item) in
                let cell = tv.dequeueReusableCellWithIdentifier(cellIdentifier, forIndexPath: indexPath) as! Cell
                configureCell(indexPath, section, item, cell)
                return cell
            }
            
            return self.rx_subscribeSectionsTo(dataSource)(source)
        }
    }
    
    // `reloadData` - items subscription methods (it's assumed that there is one section, and it has type `Void`)
    
    public func rx_subscribeItemsTo<Item>(bridge: RxTableViewDataSourceBridge<Void, Item>)
        -> Observable<[Item]> -> Disposable {
        return { source in
            let sourceWithSections = source >- map { items in
                return [(section: (), items: items)]
            }
            
            return self.rx_subscribeSectionsTo(bridge)(sourceWithSections)
        }
    }
    
    public func rx_subscribeItemsTo<Item>
        (cellFactory: (UITableView, NSIndexPath, Item) -> UITableViewCell)
        -> Observable<[Item]> -> Disposable {
        return { source in
            let bridge: RxTableViewDataSourceBridge<Void, Item> = self.rx_createBridge()
            bridge.cellFactory = { (tv, ip, _, item) in
                return cellFactory(tv, ip, item)
            }
            
            return self.rx_subscribeItemsTo(bridge)(source)
        }
    }
    
    public func rx_subscribeItemsToWithCellIdentifier<Item, Cell: UITableViewCell>
        (cellIdentifier: String, configureCell: (NSIndexPath, Item, Cell) -> Void)
        -> Observable<[Item]> -> Disposable {
        return { source in
            let bridge = RxTableViewDataSourceBridge<Void, Item>()
            bridge.cellFactory = { (tv, indexPath, section, item) in
                let cell = tv.dequeueReusableCellWithIdentifier(cellIdentifier, forIndexPath: indexPath) as! Cell
                configureCell(indexPath, item, cell)
                return cell
            }
            
            return self.rx_subscribeItemsTo(bridge)(source)
        }
    }
    
    // `beginUpdates`/`endUpdates` subscription methods
    
    public func rx_subscribeIncrementalSectionsTo<Section, Row>
        (bridge: RxTableViewDataSourceBridge<Section, Row>)
        -> Observable<IncrementalUpdateEvent<Section, Row>> -> Disposable {
        return { source in
            MainScheduler.ensureExecutingOnScheduler()
            
            var dataSource = self.rx_getTableViewDataSource()
            
            let clearDataSource = AnonymousDisposable {
                contract(self.dataSource == nil || self.dataSource === dataSource)
                
                if dataSource!.isDisposable {
                    self.dataSource = nil
                }
            }
            
            let disposable = source.subscribe(AnonymousObserver { event in
                MainScheduler.ensureExecutingOnScheduler()
                
                dataSource = self.rx_ensureTableViewDataSourceIsSet()
               
                if let existingBridge = dataSource?.bridge {
                    contract(existingBridge === bridge)
                }
                
                dataSource!.bridge = bridge
                
                dataSource!.existingBridge.onRowsSequenceIncrementalEvent(self, event: RxBox(event))
            })
                
            return CompositeDisposable(clearDataSource, disposable)
        }
    }
    
    // events
    
    public func rx_tappedItemIndexPath() -> Observable<(tableView: UITableView, indexPath: NSIndexPath)> {
        _ = rx_getTableViewDelegate()
        
        return AnonymousObservable { observer in
            MainScheduler.ensureExecutingOnScheduler()
            
            let delegate = self.rx_ensureTableViewDelegateIsSet()
            
            contract(self.delegate === delegate)
            
            let key = delegate.addTableViewRowTapedObserver(observer)
            
            return AnonymousDisposable {
                MainScheduler.ensureExecutingOnScheduler()
                
                contract(self.delegate == nil || self.delegate === delegate)
                
                delegate.removeTableViewRowTapedObserver(key)
                
                if delegate.isDisposable {
                    self.delegate = nil
                }
            }
        }
    }
    
    public func rx_deletedItemIndexPath() -> Observable<(tableView: UITableView, indexPath: NSIndexPath)> {
        _ = rx_getTableViewDataSource()
        
        return AnonymousObservable { observer in
            MainScheduler.ensureExecutingOnScheduler()
            
            let dataSource = self.rx_ensureTableViewDataSourceIsSet()
            
            let key = dataSource.addTableViewRowDeletedObserver(observer)
            
            return AnonymousDisposable {
                MainScheduler.ensureExecutingOnScheduler()
                
                contract(self.dataSource == nil || self.dataSource === dataSource)
                
                dataSource.removeTableViewRowDeletedObserver(key)
                
                if dataSource.isDisposable {
                    self.dataSource = nil
                }
            }
        }
    }
    
    public func rx_movedItemIndexPath() -> Observable<(tableView: UITableView, from: NSIndexPath, to: NSIndexPath)> {
        _ = rx_getTableViewDataSource()
        
        return AnonymousObservable { observer in
            MainScheduler.ensureExecutingOnScheduler()
            
            let dataSource = self.rx_ensureTableViewDataSourceIsSet()
            
            let key = dataSource.addTableViewRowMovedObserver(observer)
            
            return AnonymousDisposable {
                MainScheduler.ensureExecutingOnScheduler()
                
                contract(self.dataSource == nil || self.dataSource === dataSource)
                
                dataSource.removeTableViewRowMovedObserver(key)
                
                if dataSource.isDisposable {
                    self.dataSource = nil
                }
            }
        }
    }
    
    // typed events
    
    public func rx_tappedItemContext<Section, Item>() -> Observable<(path: NSIndexPath, section: Section, item: Item)> {
        
        return rx_tappedItemIndexPath() >- map { (tableView, itemIndexPath) -> (path: NSIndexPath, section: Section, item: Item) in
            let dataSource: RxTableViewDataSourceBridge<Section, Item> = self.rx_ensureTableViewDataSourceIsSet().existingBridge.typedBridge()
            
            let section = dataSource.sections[itemIndexPath.section]
            
            return (path: itemIndexPath, section: section.section, item: section.items[itemIndexPath.item])
        }
        
    }
    
    public func rx_tappedItem<Item>() -> Observable<Item> {
        
        return rx_tappedItemIndexPath() >- map { (tableView, itemIndexPath) -> Item in
            let dataSource: RxTableViewDataSourceItemsBridge<Item> = self.rx_ensureTableViewDataSourceIsSet().existingBridge.typedBridge()
            
            return dataSource.itemAtIndexPath(itemIndexPath)
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
            rxFatalError(tableViewWrongDelegatesMessage)
        }
        
        return maybeDataSource!
    }
    
    private func rx_getTableViewDelegate() -> RxTableViewDelegate? {
        MainScheduler.ensureExecutingOnScheduler()
        
        if self.delegate == nil {
            return nil
        }
        
        let maybeDelegate = self.delegate as? RxTableViewDelegate
        
        if maybeDelegate == nil {
            rxFatalError(tableViewWrongDelegatesMessage)
        }
        
        return maybeDelegate!
    }
 
    private func rx_ensureTableViewDelegateIsSet() -> RxTableViewDelegate {
        MainScheduler.ensureExecutingOnScheduler()
     
        let maybeDelegate = rx_getTableViewDelegate()
        
        if let delegate = maybeDelegate {
            return delegate
        }
        
        let delegate = self.rx_createDelegate()
        self.delegate = delegate
        return delegate
    }
    
    private func rx_ensureTableViewDataSourceIsSet() -> RxTableViewDataSource {
        MainScheduler.ensureExecutingOnScheduler()
        
        let maybeDataSource: RxTableViewDataSource? = rx_getTableViewDataSource()
        
        if let dataSource = maybeDataSource {
            return dataSource
        }
        
        let dataSource = rx_createDataSource()
        
        self.dataSource = dataSource
        return dataSource
    }
}