//
//  IAPLocalTool.swift
//  CZIAP
//
//  Created by yangxiongkai on 2022/8/4.
//

// 本地存储逻辑如下：
// orderId、productId、receipt、transactionId、timestamp五个值为一组，以组为单位存取

typealias LocalInfoIAP = [String : String]
extension LocalInfoIAP {
    var orderId : String? { self[OrderIdKey] }
    var productId : String? { self[ProductIdKey] }
    var receipt : String? { self[ReceiptKey] }
    var transactionId: String? { self[TransactionIdKey] }
}

func saveIAPInfo(orderId: String, productId: String, receipt: String, transactionId: String) {
    if orderId.isEmpty || productId.isEmpty || receipt.isEmpty || transactionId.isEmpty { return }
    let timestamp = String(Date().timeIntervalSince1970)
    let newInfo: LocalInfoIAP = [OrderIdKey: orderId, ProductIdKey: productId, ReceiptKey: receipt, TransactionIdKey: transactionId, TimestampKey: timestamp]
    saveInfo(newInfo)
}

/// 获取本地指定的info
func getLocalInfo(transactionId: String) -> LocalInfoIAP? {
    if transactionId.isEmpty { return nil }
    guard let infos = getLocalInfos() else { return nil }
    for info in infos {
        if info.transactionId == transactionId {
            return info
        }
    }
    
    return nil
}

/// 清理指定info
func clearLocalInfo(_ target: LocalInfoIAP) {
    guard var infos = getLocalInfos() else { return }
    infos.removeAll { info in
        compareInfo(info, target)
    }
    UserDefaults.standard.set(infos, forKey: LocalUnfinishedIAPInfoKey)
    UserDefaults.standard.synchronize()
}

/// 清理所有本地info
func clearAllLocalInfo() {
    UserDefaults.standard.removeObject(forKey: LocalUnfinishedIAPInfoKey)
    UserDefaults.standard.synchronize()
}

fileprivate func saveInfo(_ newInfo: LocalInfoIAP) {
    var infos = [LocalInfoIAP]()
    if let localInfos = getLocalInfos() {
        infos = localInfos
    }
    
    var existInfo = false
    for info in infos {
        if compareInfo(info, newInfo) {
            existInfo = true
            break
        }
    }
    
    if existInfo == false {
        infos.append(newInfo)
    }

    UserDefaults.standard.set(infos, forKey: LocalUnfinishedIAPInfoKey)
    UserDefaults.standard.synchronize()
    print("内购-本地缓存infos:\(infos)")
}

/// 获取本地存储的infos
 func getLocalInfos() -> [LocalInfoIAP]? {
    return UserDefaults.standard.value(forKey: LocalUnfinishedIAPInfoKey) as? [LocalInfoIAP]
}

/// 比较两个info
fileprivate func compareInfo(_ info1: LocalInfoIAP, _ info2: LocalInfoIAP) -> Bool {
    if info1.count != info2.count { return false }
    if info1.isEmpty { return false }
    
    let sameOrderId = (info1.orderId == info2.orderId) && (info1.orderId != nil)
    let sameProductId = (info1.productId == info2.productId) && (info1.productId != nil)
    let sameReceipt = (info1.receipt == info2.receipt) && (info1.receipt != nil)
    let sameTransactionId = (info1.transactionId == info2.transactionId) && (info1.transactionId != nil)
    return sameOrderId && sameProductId && sameReceipt && sameTransactionId
}

fileprivate let LocalUnfinishedIAPInfoKey   = "LocalUnfinishedIAPInfoKey"
fileprivate let OrderIdKey                  = "orderId"
fileprivate let ProductIdKey                = "productId"
fileprivate let ReceiptKey                  = "receipt"
fileprivate let TransactionIdKey            = "transactionId"
fileprivate let TimestampKey                = "timestamp"
