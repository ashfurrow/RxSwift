//
//  OperationQueueScheduler.swift
//  Rx
//
//  Created by Krunoslav Zaher on 4/4/15.
//  Copyright (c) 2015 Krunoslav Zaher. All rights reserved.
//

import Foundation

public class OperationQueueScheduler: ImmediateScheduler {
    private let operationQueue: NSOperationQueue
    
    public init(operationQueue: NSOperationQueue) {
        self.operationQueue = operationQueue
    }
    
    public func schedule<StateType>(state: StateType, action: (ImmediateScheduler, StateType) -> RxResult<Disposable>) -> RxResult<Disposable> {
        
        let compositeDisposable = CompositeDisposable()
        
        let operation = NSBlockOperation {
            if compositeDisposable.disposed {
                return
            }
            
            ensureScheduledSuccessfully(action(self, state).map { disposable in
                compositeDisposable.addDisposable(disposable)
                return ()
            })
        }
        
        self.operationQueue.addOperation(operation)
        
        compositeDisposable.addDisposable(AnonymousDisposable {
            operation.cancel()
        })
        
        return success(compositeDisposable)
    }
}