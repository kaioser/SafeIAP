//
//  IAPStoreObserver.swift
//  CZIAP
//
//  Created by yangxiongkai on 2022/7/7.
//

import StoreKit

typealias ObserverCallback = (IAPResultState, SKPaymentTransaction?) -> Void

class StoreObserver: NSObject {
    static let shared = StoreObserver()
    
    var callback: ObserverCallback?
    
    func addTransactionObserver() {
        SKPaymentQueue.default().add(self)
        
        NotificationCenter.default.addObserver(self, selector: #selector(removeTransactionObserver(_:)), name: UIApplication.willTerminateNotification, object: nil)
    }
    
    @objc func removeTransactionObserver(_ noti: Notification? = nil) {
        SKPaymentQueue.default().remove(self)
    }
    
    func buy(_ product: SKProduct) {
        let payment = SKPayment(product: product)
        SKPaymentQueue.default().add(payment)
        
        // 如果在收到updatedTransactions代理方法之前，出现app被杀死等异常情况
        // 此时有可能已经扣款成功，再次打开app时可能会监听到purchased
        // 但是由于此时本地没有存储orderId等信息，无法去校验
        // 所以最终方案：如果出现这种情况，直接给他finish掉本次交易
    }
}

extension StoreObserver: SKPaymentTransactionObserver {
    
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            
            switch transaction.transactionState {
                // Transaction is being added to the server queue.
                // 事务正在添加至服务器队列中。
            case .purchasing:
                print("内购-SDK回调state: purchasing")
                break
                
                // Transaction is in queue, user has been charged, Client should complete the transaction.
                // 交易已在队列中, 用户已被扣款, 客户端需要完成事务。
            case .purchased:
                print("内购-SDK回调state: purchased")
                handlePurchased(transaction)
                
                // Transaction was cancelled or failed before being added to the server queue.
                // 事务在被添加到服务器队列之前被取消或失败。
            case .failed:
                print("内购-SDK回调state: failed")
                handleFailed(transaction)
                
                // Transaction was restored from user's purchase history.  Client should complete the transaction.
                // 事务被从用户的购买历史中恢复。客户应完成事务。
                // 数字心动的NFT是消耗性商品，所以不会出现这种『恢复购买』的情景
            case .restored:
                print("内购-SDK回调state: restored")
                handlePurchased(transaction)
                
                // Do not block your UI. Allow the user to continue using your app.
                // The transaction is in the queue, but its final status is pending external action.
                // 事务在队列中，但它的最终状态是等待外部操作。
            case .deferred:
                print("内购-SDK回调state: deferred")
                
                // 默认支付失败
            @unknown default:
                print("内购-SDK回调state: default")
                handleFailed(transaction)
            }
        }
    }
}

extension StoreObserver {
    func finishTransaction(_ transaction: SKPaymentTransaction) {
        SKPaymentQueue.default().finishTransaction(transaction)
    }
    
    private func handlePurchased(_ transaction: SKPaymentTransaction) {
        // 扣款成功，本地缓存支付信息，待校验成功后再清除
        
        if let orderId = IAPManager.manager.orderId {
            
            // 有orderId，说明是正常流程购买监听到的
            guard let url = Bundle.main.appStoreReceiptURL,
                  let receiptData = try? Data(contentsOf: url),
                  let transactionId = transaction.transactionIdentifier else { return }
            let receipt = receiptData.base64EncodedString()
            saveIAPInfo(orderId: orderId, productId: transaction.payment.productIdentifier, receipt: receipt, transactionId: transactionId)
            
        } else {
            // 无orderId，说明是app一启动就监听到的，此时这些信息已存储过，不再重复存储
        }
        
        // 扣款成功，拿着票据去后端验证
        makeCallback(.paySuccess, transaction)
    }
    
    private func handleFailed(_ transaction: SKPaymentTransaction) {
        let message = transaction.error?.localizedDescription ?? "SDK未返回失败原因"
        print("内购-商品id \(transaction.payment.productIdentifier) 购买失败, 原因: \(message)")
        
        if (transaction.error as? SKError)?.code == .paymentCancelled {
            DispatchQueue.main.async {
                self.makeCallback(.payCancel, nil)
            }
        } else {
            DispatchQueue.main.async {
                self.makeCallback(.payFail, nil)
            }
        }
        
        finishTransaction(transaction)
    }
    
    private func makeCallback(_ state: IAPResultState, _ transaction: SKPaymentTransaction?) {
        if Thread.current.isMainThread {
            self.callback?(state, transaction)
        } else {
            DispatchQueue.main.async {
                self.callback?(state, transaction)
                return
            }
        }
    }
}
