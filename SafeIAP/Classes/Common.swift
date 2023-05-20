//
//  IAPCommon.swift
//  CZIAP
//
//  Created by yangxiongkai on 2022/7/13.
//

// 内购最终的结果，以此为依据来刷新h5页面
public typealias IAPSuccessOrFailCallback = ((Bool) -> Void)

open class CZIAPTool {
    
    /// 点击H5的【立即支付】按钮，立即进入内购流程
    public class func buy(productId: String, orderNo: String, price: String, _ callback: IAPSuccessOrFailCallback?) {
        // 0元的支付逻辑未走内购，h5内部处理了

        if orderNo.isEmpty {
            IAPManager.manager.handleIAPResult(.noOrderId)
            return
        }
        
        if productId.isEmpty {
            IAPManager.manager.handleIAPResult(.noProductId)
            return
        }
        
        IAPManager.manager.fromH5Page = true
        IAPManager.manager.fetchAndBuy(productId, orderNo: orderNo, priceStr: price)
        IAPManager.manager.szxdCallback = callback
    }
    
    /// 开始监听，此方法只在AppDelegate中调用且只可调用一次！！！
    public class func begain() {
        IAPManager.start()
        NotificationCenter.default.addObserver(self, selector: #selector(intoH5NFT), name: NSNotification.Name.init(rawValue: "kIntoH5PageForNFT"), object: nil)
    }
    
    /// 进入H5的NFT页面之后检测本地缓存
    @objc private class func intoH5NFT() {
        IAPManager.verImmediately(transaction: nil)
    }
}

// 内购过程中的一些状态...
enum IAPResultState: String {
    
    // h5传值错误...
    case noOrderId          = "订单号不可为空!"
    case noProductId        = "商品ID不可为空!"
    
    // 请求商品信息...
    case proAuthNotAllow    = "您没有发起App内购买的权限!"
    case proRequestFail     = "商品信息有误，购买失败！"// 请求苹果服务器返回的商品信息
    
    // 支付...
    case paying             = "购买商品中..."
    case paySuccess         = "购买成功"
    case payFail            = "购买失败"
    case payCancel          = "您已取消支付"
    
    // 校验...
    case verReceiptError    = "单据信息有误，购买失败!"// 凭证不合法, 比如为空or转base64失败
    case verifying          = "单据校验中..."
    case verSuccess         = "商品购买成功!"
    case verRequestFail     = "单据校验参数错误!"
    case verResponseFail    = "单据校验失败!"
    case verOrderCanceled   = "订单已取消"// 订单因超时未支付而转变成已取消的状态
}



// 内购的一些容错处理，必读！！！！

// 正常不出错的流程如下：
// 1.进入NFT【八选一】的购买页，点击其中一个商品，生成orderId并弹出【立即支付】的弹框(这些都是H5内部处理)
// 2.H5页面点击【立即支付】会调用原生方法并传过来orderId和productId
// 3.原生方法使用productId去请求苹果内购SDK，获取商品，并弹出iOS系统内购页面
// 4.输入密码或指纹或人脸进行支付
// 5.支付结果的state通过SKPaymentTransactionObserver回调给app，如果state为purchased，则代表支付成功，此时用户的appleID已扣款
// 6.扣款后获取票据receipt并转成base64字符串，去请求后端的校验接口
// 7.校验成功后调用finishTransaction方法，以完成此次交易(从交易队列中移除此次交易)


// 可能出现错误情况的节点：
// 1)上面第6步有可能在请求校验接口之前断网，或者请求发出之后还未收到后端返回结果时断网等情况，故无法得知校验结果；
//   为了处理这些情景，在第5步之后立即把orderId、productId、receipt存到本地，然后在AppDelegate中监听SKPaymentTransactionObserver
//   等再次打开app时候，因为上次交易未校验过(未调用过finishTransaction方法)，所以监听的结果
//   还是purchased，此时会从本地取出orderId、productId、receipt，再次进行校验；那么此时又带来了一个问题，如果用户没有退出app怎么办?
//   如果未退出app，那么在点进支付按钮的时候进行监听，但是每次点击支付按钮都会生成新订单，为了避免这种不必要的浪费订单，
//   在进入NFT页面时检测本地是否还存在未校验过的订单信息
//
// 2)上面第6步还可能出现等待时间过长或者长征服务端异常等情况，所以在IAPRequest中设置了一个最大重试次数kMaxRetryTime，具体实现为：
//   在网络请求方法的failCallback中再次请求，直到超出kMaxRetryTime，如果超过最大次数还是失败，那么就不再请求，弹出失败的提示


// 记录一下目前后端的防刷单逻辑：
// 后端有一张orderId和transactionId一一对应关联的表，比如叫OT表，此表中的两个字段是肯定有值的，不会存在一个有值一个为空的情况，这是前提
// 每次app调用校验接口传过去的orderId会先到OT表中查找，如果查找到了此orderId，那么后端会直接返回校验成功
// 如果没查到，则代表是新订单，此时会拿receiptData去苹果服务器校验，校验结束后得到transactionId，
// 此时会在OT表建立一条新的两者关联的数据，同时返回给app端校验成功
