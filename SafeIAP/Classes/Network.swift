//
//  IAPNetwork.swift
//  CZIAP
//
//  Created by yangxiongkai on 2022/7/14.
//

import Foundation

fileprivate let kRetryMaxTimes: Int = 3
fileprivate let kVerUrl = "xxxx/xxx.php"

class IAPRequest: NSObject {
    
    static var retryTimes: Int = 1
    
    class func ver(orderNo: String, receiptData: String, productId: String, _ callback: ((IAPResultState) -> Void)?) {
        let allEmpty = orderNo.isEmpty && receiptData.isEmpty && productId.isEmpty
        if allEmpty {
            callback?(.verRequestFail)
            return
        }
        retryTimes = 1
        _ver(orderNo: orderNo, receiptData: receiptData, productId: productId, callback)
    }
    
    /// 校验单据
    private class func _ver(orderNo: String, receiptData: String, productId: String, _ callback: ((IAPResultState) -> Void)?) {
        
        /*
        let para: [String : Any] = ["receiptData": receiptData, "orderType": 7, "platformOrderNo": orderNo, "productId": productId]
        Network.request(path: "xxxx/xxx.php",
                                 params: para,
                                 encoding: .json,
                                 response: IAPVerifyModel.self,
                                 timeoutInterval: 30) { res in
            guard let model = res else {
                callback?(.verResponseFail)
                return
            }
            
            switch model.cz_paymentStatus {
            case .success:
                callback?(.verSuccess)

            case .fail:
                callback?(.verResponseFail)// 校验失败

            case .cancel:
                callback?(.verOrderCanceled)// 订单已取消

            case .receiptVerifiedByOtherOrder:
                print("此收据已被其他订单校验过")
                
            case .unkown:
                print("订单校验发生未知错误")
            }
            
        } failure: { error in
            retryTimes += 1
            if retryTimes <= kRetryMaxTimes {
                // 不超过最大重试次数，重试
                _ver(orderNo: orderNo, receiptData: receiptData, productId: productId, callback)
            } else {
                // 超过最大重试次数，直接报错
                // 由于上面的toast会和IAPManager中的toast同时显示，造成UI冲突，所以等上面的error的toast结束以后再回调至IAPManager
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1.5) {
                    print("内购-当前线程3: \(Thread.current), 是否为主线程: \(Thread.current.isMainThread)")
                    callback?(.verResponseFail)
                }
            }
        }
         */
    }
}

fileprivate enum IAPVerifyCode: Int {
    case cancel = -1// 此订单已取消，可能是超时未支付导致
    case unkown = 0
    case success = 1
    case fail = 2
    case receiptVerifiedByOtherOrder = 3// 此收据已被其他订单校验过
}

//fileprivate class IAPVerifyModel: NSObject, HandyJSON {
//
//    public required override init() {}
//
//    /// 产品编号
//    var productId: String = ""
//
//    /// 交易时间
//    var transactionDate: String = ""
//
//    /// 交易编号
//    var transactionId: String = ""
//
//    /// 校验结果状态 1：成功；2：失败 -1:订单已取消
//    public var cz_paymentStatus: IAPVerifyCode = .unkown
//
//    // 重写此方法把paymentStatus字段解析到自建属性cz_paymentStatus上
//    func mapping(mapper: HelpingMapper) {
//        mapper.specify(property: &cz_paymentStatus, name: "paymentStatus") { code in
//            return IAPVerifyCode(rawValue: Int(code) ?? 0) ?? .unkown
//        }
//    }
//}
