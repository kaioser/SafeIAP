//
//  IAPManager.swift
//  CZIAP
//
//  Created by yangxiongkai on 2022/7/7.
//

import Indicator
import StoreKit

class IAPManager: NSObject {
    static let manager = IAPManager()
    
    /// 是否从H5页面进入的内购流程(可理解为是否为常规内购流程)
    var fromH5Page: Bool = false
    
    /// 回调给壳工程的支付结果
    var szxdCallback: IAPSuccessOrFailCallback?
    
    var productId: String?
    var orderId: String?
    var price: String?
    
    /// 购买流程
    private var normalProcess: Bool {
        if let oid = orderId {
            return !oid.isEmpty
        } else {
            return false
        }
    }
    
    /// 内购初始化方法，写在appDelegate的didFinishLaunch中
    class func start() {
        StoreObserver.shared.addTransactionObserver()
        StoreObserver.shared.callback = { state, transaction in
            if state != .paySuccess {
                manager.handleIAPResult(state)
                return
            }
            
            verImmediately(transaction: transaction)
        }
    }
    
    /// 拆出来的方法，以便单独调用
    class func verImmediately(transaction: SKPaymentTransaction?) {
        
        if let t = transaction {
            print("内购-传了transaction-1)app启动监听到了 2)正常购买监听到了")
            
            // transaction有值，有两种情况：1)app启动监听到了 2)正常购买监听到了
            // 无论是由哪种监听而来，为了简单易懂，统一从本地取，因为肯定存过
            
            guard let tid = t.transactionIdentifier,
                  let info = getLocalInfo(transactionId: tid),
                  let oid = info.orderId,
                  let pid = info.productId,
                  let receipt = info.receipt else {
                manager.handleIAPResult(.verReceiptError)
                // 监听到purchased，但是本地取不到数据，说明上次StoreKit的支付结果未返回时app已经闪退
                // 此时因为没有回调到observer，所以本地未存储票据信息，此时直接完成交易即可
                StoreObserver.shared.finishTransaction(t)
                return
            }
            
            IAPManager.manager.verNetwork(oid, receipt: receipt, pid: pid, info: info)
            
        } else {
            print("内购-没传transaction-本地遍历取info")
            
            // transaction没有值，说明是刚进入NFT页面执行的此方法，此时取本地数据遍历请求验证接口
            guard let infos = getLocalInfos(), infos.isEmpty == false else {
                print("内购-没传transaction-本地遍历取info-infos为空")
                return
            }
            for info in infos {
                if let oid = info.orderId, let pid = info.productId, let receipt = info.receipt {
                    IAPManager.manager.verNetwork(oid, receipt: receipt, pid: pid, info: info)
                }
            }
        }
    }
    
    /// 获取商品列表并购买对应商品
    func fetchAndBuy(_ pid: String, orderNo: String, priceStr: String) {
        price = priceStr
        orderId = orderNo
        
        guard SKPaymentQueue.canMakePayments() else {
            handleIAPResult(.proAuthNotAllow)
            return
        }
        
        print("内购-当前线程0: \(Thread.current), 是否为主线程: \(Thread.current.isMainThread)")
        productId = pid
        
        handleIAPResult(.paying)
        let req = SKProductsRequest(productIdentifiers: [pid] as Set)
        req.delegate = self
        req.start()
    }
}

extension IAPManager {
    /// 校验请求
    private func verNetwork(_ oid: String, receipt: String, pid: String, info: LocalInfoIAP) {
        handleIAPResult(.verifying)
        
        IAPRequest.ver(orderNo: oid, receiptData: receipt, productId: pid) { res in
            self.handleIAPResult(res)
            
            if res == .verSuccess || res == .verOrderCanceled {
                self.orderId = nil
                self.productId = nil
                self.price = nil
                clearLocalInfo(info)// 校验成功，清理本地缓存
                
                let s = SKPaymentQueue.default().transactions
                for transaction in s {
                    // 多一层判断productId
                    if transaction.payment.productIdentifier == pid {
                        if transaction.transactionState == .purchased || transaction.transactionState == .restored {
                            StoreObserver.shared.finishTransaction(transaction)// 完成交易
                        }
                    }
                }
            }
        }
    }
}

extension IAPManager: SKProductsRequestDelegate {
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        var p: SKProduct?
        for item in response.products {
            let n = NSDecimalNumber(string: price)
            let res = item.price.compare(n)
            if item.productIdentifier == productId, res == .orderedSame {
                p = item
                break
            }
        }
        
        print("内购-当前线程1: \(Thread.current), 是否为主线程: \(Thread.current.isMainThread)")
        guard let rp = p else {
            handleIAPResult(.proRequestFail)
            return
        }
        
        StoreObserver.shared.buy(rp)
    }
    
    func request(_ request: SKRequest, didFailWithError error: Error) {
        handleIAPResult(.proRequestFail)
    }
}

extension IAPManager {
    
    func handleIAPResult(_ state: IAPResultState) {
        print("内购-当前线程2: \(Thread.current), 是否为主线程: \(Thread.current.isMainThread)")
        
        if Thread.current.isMainThread {
            handleIAPResultPro(state)
        } else {
            DispatchQueue.main.async {
                self.handleIAPResultPro(state)
                return
            }
        }
    }
    
    private func handleIAPResultPro(_ state: IAPResultState) {
//        ZTProgressHUD.stopAllLoading(nil)
        print("内购-自定义state:\(state)")
        
        // toast和HUD是否需要展示取决于orderId(有orderId说明是正常流程一步步购买的，此时需要显示toast和HUD；没有orderId说明是app启动监听或者进入NFT页面后本地取的值，不需要显示toast等)
        // 所以只有正常流程购买的商品才能显示Toast或HUD
        let needToast = normalProcess
        // 只有正常流程购买的商品才能刷新h5页面
        let needRefesh = normalProcess
        
        switch state {
            
        case .noOrderId, .noProductId, .proAuthNotAllow, .proRequestFail:
            if needToast {
//                CZToast.toast(state.rawValue)
            }
            
        case .paying, .verifying:
            if needToast {
//                ZTProgressHUD.showLoading(state.rawValue, view: nil)
            }
            
        case .paySuccess:// 这里故意不回调, 因为要以校验成功的结果为准
            print(state.rawValue)
            
        case .verResponseFail, .verRequestFail, .verReceiptError, .payCancel, .payFail:
            if needToast {
//                CZToast.toast(state.rawValue)
            }
            
            if needRefesh {
                szxdCallback?(false)
            }
            
        case .verSuccess:
            if needRefesh {
                szxdCallback?(true)
            }
            
        case .verOrderCanceled:
            // 系统提示：此订单已取消
            // UIAlert...因网络异常,本次扣款未购买成功,请联系苹果客服进行退款操作,给您带来的不便敬请谅解.
            checkRootAndShowAlert()
            if needRefesh {
                szxdCallback?(false)
            }
        }
    }
}

import Extension

fileprivate func cancelAlert() {
    print("内购-弹出已取消订单的alert")
    let vc = UIAlertController(title: "因网络异常,本次扣款未购买成功,请联系苹果客服进行退款操作,给您带来的不便敬请谅解.", message: nil, preferredStyle: .alert)
    vc.addAction(UIAlertAction(title: "确定", style: .cancel))
    UIViewController.current()?.present(vc, animated: true)
}

private func checkRootAndShowAlert() {
    print("内购-等待rootVC切换成tabbarVC")
    
    let isTabBar = UIViewController.current() == nil ? false : (UIViewController.current()!.tabBarController != nil)
    if isTabBar {
        DispatchQueue.main.asyncAfter(wallDeadline: .now() + 0.2) {
            cancelAlert()
        }
    } else {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            checkRootAndShowAlert()
        }
    }
}
