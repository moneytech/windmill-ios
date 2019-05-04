//
//  PaymentQueue.swift
//  windmill
//
//  Created by Markos Charatzas on 31/01/2019.
//  Copyright © 2019 Windmill. All rights reserved.
//

import Foundation
import Alamofire
import StoreKit
import os

class PaymentQueue: NSObject, SKPaymentTransactionObserver, SKRequestDelegate {

    static let TransactionPurchased = Notification.Name("io.windmill.windmill.transaction.purchased")
    static let TransactionPurchasing = Notification.Name("io.windmill.windmill.transaction.purchasing")
    static let TransactionError = Notification.Name("io.windmill.windmill.transaction.error")
    static let RestoreCompletedTransactionsFinished = Notification.Name("io.windmill.windmill.transaction.restore.finished")
    static let RestoreCompletedTransactionsFailed = Notification.Name("io.windmill.windmill.transaction.restore.error")
    
    static let ReceiptRefreshing = Notification.Name("io.windmill.windmill.receipt.refreshing")
    static let ReceiptRefreshed = Notification.Name("io.windmill.windmill.receipt.refreshed")
    static let ReceiptRefreshFailed = Notification.Name("io.windmill.windmill.receipt.refresh.failed")

    static let `default` = PaymentQueue()
    
    private let queue = SKPaymentQueue.default()
    
    /* unowned */ weak var subscriptionManager: SubscriptionManager?
    var receiptRefreshRequest: SKReceiptRefreshRequest?
    
    deinit {
        self.receiptRefreshRequest?.cancel()
    }
    
    private override init() {
        
    }
    
    func add(_ payment: SKPayment) {
        self.queue.add(payment)
    }

    func startObservingPaymentTransactions() {
        self.queue.add(self)
    }
    
    private func purchaseSubscription(receiptData: String, completion: @escaping SubscriptionResource.TransactionsCompletion) {
        let subscriptionManager = self.subscriptionManager ?? SubscriptionManager.shared
        subscriptionManager.purchaseSubscription(receiptData: receiptData, completion: completion)
    }
    
    private func restoreSubscription(receiptData: String) {
        let subscriptionManager = self.subscriptionManager ?? SubscriptionManager.shared
        subscriptionManager.restoreSubscription(receiptData: receiptData)
    }

    public func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        
        for transaction in transactions {
            switch transaction.transactionState {
            case .purchased:
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: PaymentQueue.TransactionPurchased, object: self, userInfo: nil)
                }

                guard let appStoreReceiptURL = Bundle.main.appStoreReceiptURL, FileManager.default.fileExists(atPath: appStoreReceiptURL.path), let rawReceiptData = try? Data(contentsOf: appStoreReceiptURL) else {
                    return
                }
                
                let receiptData = rawReceiptData.base64EncodedString()
                
                self.purchaseSubscription(receiptData: receiptData){ (token, error) in                    
                    self.queue.finishTransaction(transaction)
                }
                
            case .purchasing:
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: PaymentQueue.TransactionPurchasing, object: self, userInfo: nil)
                }
                return
            case .failed:

                // Only set if state is SKPaymentTransactionFailed
                guard let error = transaction.error else {
                    return
                }
                
                self.queue.finishTransaction(transaction)
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: PaymentQueue.TransactionError, object: self, userInfo: ["error": error])
                }
                return
            case .restored:
                self.queue.finishTransaction(transaction)
            case .deferred:
                break
            @unknown default:
                break
            }
        }
    }
    
    func restoreCompletedTransactions() {
        self.queue.restoreCompletedTransactions()
    }
    
    func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {

        DispatchQueue.main.async {
            NotificationCenter.default.post(name: PaymentQueue.RestoreCompletedTransactionsFinished, object: self, userInfo: nil)
        }

        guard let appStoreReceiptURL = Bundle.main.appStoreReceiptURL, FileManager.default.fileExists(atPath: appStoreReceiptURL.path), let rawReceiptData = try? Data(contentsOf: appStoreReceiptURL) else {
            return
        }
        
        let receiptData = rawReceiptData.base64EncodedString()
        
        self.restoreSubscription(receiptData: receiptData)
    }
    
    func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: PaymentQueue.RestoreCompletedTransactionsFailed, object: self, userInfo: ["error": error])
        }
    }
    
    @discardableResult func refreshReceipt() -> SKReceiptRefreshRequest {
        
        let receiptRefreshRequest = SKReceiptRefreshRequest()
        receiptRefreshRequest.delegate = self
        receiptRefreshRequest.start()
        
        self.receiptRefreshRequest = receiptRefreshRequest
        
        NotificationCenter.default.post(name: PaymentQueue.ReceiptRefreshing, object: self)
        
        return receiptRefreshRequest
    }
    
    // MARK: SKRequestDelegate
    func requestDidFinish(_ request: SKRequest) {
        
        /*
         the delegate also receives a callback for the #products(productIdentifiers:) request.
         since the SKProductsRequest, on success, calls back on the #productsRequest(:didReceive:), this is done so as
         to avoid the double callback
         */
        guard request == self.receiptRefreshRequest else {
            return
        }
        
        guard let appStoreReceiptURL = Bundle.main.appStoreReceiptURL, FileManager.default.fileExists(atPath: appStoreReceiptURL.path) else {
            return
        }
        
        guard let rawReceiptData = try? Data(contentsOf: appStoreReceiptURL) else {
            return
        }
        
        let receipt = rawReceiptData.base64EncodedString()
        NotificationCenter.default.post(name: PaymentQueue.ReceiptRefreshed, object: self, userInfo: ["receipt": receipt])
    }
    
    func request(_ request: SKRequest, didFailWithError error: Error) {
        NotificationCenter.default.post(name: PaymentQueue.ReceiptRefreshFailed, object: self, userInfo: ["error": error])
    }
}
