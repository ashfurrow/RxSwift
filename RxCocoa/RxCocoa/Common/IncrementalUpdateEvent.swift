//
//  IncrementalUpdateEvent.swift
//  RxCocoa
//
//  Created by Krunoslav Zaher on 5/30/15.
//  Copyright (c) 2015 Krunoslav Zaher. All rights reserved.
//

import Foundation
import RxSwift

public enum IncrementalUpdateEvent<Section, Item> {
    public typealias SnapshotType = [(section: Section, items: [Item])]
    
    case Snapshot(RxBox<SnapshotType>)
    
    case TransactionStarted
    case TransactionEnded
    
    case ItemMoved(from: NSIndexPath, to: NSIndexPath)
    case ItemInserted(item: RxBox<Item>, to: NSIndexPath)
    case ItemDeleted(from: NSIndexPath)
    
    case SectionMoved(from: Int, to: Int)
    case SectionInserted(section: RxBox<(section: Section, items: [Item])>, to: Int)
    case SectionDeleted(from: Int)
}
