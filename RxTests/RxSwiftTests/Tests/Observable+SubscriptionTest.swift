//
//  Observable+SubscriptionTest.swift
//  RxTests
//
//  Created by Krunoslav Zaher on 10/13/15.
//
//

import Foundation
import RxSwift
import XCTest

class ObservableSubscriptionTests : RxTest {
    func testSubscribeOnNext() {
        let publishSubject = PublishSubject<Int>()

        var onNextCalled = 0
        var onErrorCalled = 0
        var onCompletedCalled = 0
        var onDisposedCalled = 0

        var lastElement: Int? = nil
        var lastError: ErrorType? = nil

        let subscription = publishSubject.subscribe(onNext: { n in
                lastElement = n
                onNextCalled++
            }, onError: { e in
                lastError = e
                onErrorCalled++
            }, onCompleted: {
                onCompletedCalled++
            }, onDisposed: {
                onDisposedCalled++
            })

        XCTAssertTrue(lastElement == nil)
        XCTAssertTrue(lastError == nil)
        XCTAssertTrue(onNextCalled == 0)
        XCTAssertTrue(onErrorCalled == 0)
        XCTAssertTrue(onCompletedCalled == 0)
        XCTAssertTrue(onDisposedCalled == 0)

        publishSubject.on(.Next(1))

        XCTAssertTrue(lastElement == 1)
        XCTAssertTrue(lastError == nil)
        XCTAssertTrue(onNextCalled == 1)
        XCTAssertTrue(onErrorCalled == 0)
        XCTAssertTrue(onCompletedCalled == 0)
        XCTAssertTrue(onDisposedCalled == 0)

        subscription.dispose()
        publishSubject.on(.Next(2))

        XCTAssertTrue(lastElement == 1)
        XCTAssertTrue(lastError == nil)
        XCTAssertTrue(onNextCalled == 1)
        XCTAssertTrue(onErrorCalled == 0)
        XCTAssertTrue(onCompletedCalled == 0)
        XCTAssertTrue(onDisposedCalled == 1)
    }

    func testSubscribeOnError() {
        let publishSubject = PublishSubject<Int>()

        var onNextCalled = 0
        var onErrorCalled = 0
        var onCompletedCalled = 0
        var onDisposedCalled = 0

        var lastElement: Int? = nil
        var lastError: ErrorType? = nil

        let subscription = publishSubject.subscribe(onNext: { n in
                lastElement = n
                onNextCalled++
            }, onError: { e in
                lastError = e
                onErrorCalled++
            }, onCompleted: {
                onCompletedCalled++
            }, onDisposed: {
                onDisposedCalled++
            })

        XCTAssertTrue(lastElement == nil)
        XCTAssertTrue(lastError == nil)
        XCTAssertTrue(onNextCalled == 0)
        XCTAssertTrue(onErrorCalled == 0)
        XCTAssertTrue(onCompletedCalled == 0)
        XCTAssertTrue(onDisposedCalled == 0)

        publishSubject.on(.Error(testError))

        XCTAssertTrue(lastElement == nil)
        XCTAssertTrue((lastError as? NSError) === testError)
        XCTAssertTrue(onNextCalled == 0)
        XCTAssertTrue(onErrorCalled == 1)
        XCTAssertTrue(onCompletedCalled == 0)
        XCTAssertTrue(onDisposedCalled == 1)

        subscription.dispose()
        publishSubject.on(.Next(2))
        publishSubject.on(.Completed)

        XCTAssertTrue(lastElement == nil)
        XCTAssertTrue((lastError as? NSError) === testError)
        XCTAssertTrue(onNextCalled == 0)
        XCTAssertTrue(onErrorCalled == 1)
        XCTAssertTrue(onCompletedCalled == 0)
        XCTAssertTrue(onDisposedCalled == 1)
    }

    func testSubscribeOnCompleted() {
        let publishSubject = PublishSubject<Int>()

        var onNextCalled = 0
        var onErrorCalled = 0
        var onCompletedCalled = 0
        var onDisposedCalled = 0

        var lastElement: Int? = nil
        var lastError: ErrorType? = nil

        let subscription = publishSubject.subscribe(onNext: { n in
            lastElement = n
            onNextCalled++
            }, onError: { e in
                lastError = e
                onErrorCalled++
            }, onCompleted: {
                onCompletedCalled++
            }, onDisposed: {
                onDisposedCalled++
        })

        XCTAssertTrue(lastElement == nil)
        XCTAssertTrue(lastError == nil)
        XCTAssertTrue(onNextCalled == 0)
        XCTAssertTrue(onErrorCalled == 0)
        XCTAssertTrue(onCompletedCalled == 0)
        XCTAssertTrue(onDisposedCalled == 0)

        publishSubject.on(.Completed)

        XCTAssertTrue(lastElement == nil)
        XCTAssertTrue(lastError == nil)
        XCTAssertTrue(onNextCalled == 0)
        XCTAssertTrue(onErrorCalled == 0)
        XCTAssertTrue(onCompletedCalled == 1)
        XCTAssertTrue(onDisposedCalled == 1)

        subscription.dispose()
        publishSubject.on(.Next(2))
        publishSubject.on(.Error(testError))

        XCTAssertTrue(lastElement == nil)
        XCTAssertTrue(lastError == nil)
        XCTAssertTrue(onNextCalled == 0)
        XCTAssertTrue(onErrorCalled == 0)
        XCTAssertTrue(onCompletedCalled == 1)
        XCTAssertTrue(onDisposedCalled == 1)
    }

    func testDisposed() {
        let publishSubject = PublishSubject<Int>()

        var onNextCalled = 0
        var onErrorCalled = 0
        var onCompletedCalled = 0
        var onDisposedCalled = 0

        var lastElement: Int? = nil
        var lastError: ErrorType? = nil

        let subscription = publishSubject.subscribe(onNext: { n in
            lastElement = n
            onNextCalled++
            }, onError: { e in
                lastError = e
                onErrorCalled++
            }, onCompleted: {
                onCompletedCalled++
            }, onDisposed: {
                onDisposedCalled++
        })

        XCTAssertTrue(lastElement == nil)
        XCTAssertTrue(lastError == nil)
        XCTAssertTrue(onNextCalled == 0)
        XCTAssertTrue(onErrorCalled == 0)
        XCTAssertTrue(onCompletedCalled == 0)
        XCTAssertTrue(onDisposedCalled == 0)

        publishSubject.on(.Next(1))
        subscription.dispose()
        publishSubject.on(.Next(2))
        publishSubject.on(.Error(testError))
        publishSubject.on(.Completed)

        XCTAssertTrue(lastElement == 1)
        XCTAssertTrue(lastError == nil)
        XCTAssertTrue(onNextCalled == 1)
        XCTAssertTrue(onErrorCalled == 0)
        XCTAssertTrue(onCompletedCalled == 0)
        XCTAssertTrue(onDisposedCalled == 1)
    }
}