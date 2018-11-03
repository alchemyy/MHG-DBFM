//
//  DoubanModel.swift
//  DoubanFM
//
//  Created by alchemist on 5/7/2018.
//  Copyright (c) 2018 alchemist. All rights reserved.
//

import UIKit

protocol doubanModelProtocol {
    func didRecieveResults(_ results:NSDictionary)
}

class DoubanModel: NSObject {
    
    var delegate : doubanModelProtocol?
    
    func searchWithUrl(_ url:String){
//        let protectionSpace = URLProtectionSpace.init(host: "api.douban.com",
//                                                      port: 8080,
//                                                      protocol: "https",
//                                                      realm: nil,
//                                                      authenticationMethod: nil)
        let session = URLSession.shared
        var URL : Foundation.URL = Foundation.URL(string: url)!
//        session.dataTask(with: URL, completionHandler: {
//                    (data:Data!, response:URLResponse!, error:Error!)->Void in
//            do{
//                var jsonResult : NSDictionary = try JSONSerialization.jsonObject(with: data!, options: []) as! NSDictionary
//                //"?"语法的优点显示出来了：以往在OC中需要使用 if (self.delegate respondsToSelector:) 现在只要一个”?“就行了
//                self.delegate?.didRecieveResults(jsonResult)
//                }
//                catch{
//                    print(error)
//                }
//
//                } as! (Data?, URLResponse?, Error?) -> Void)
//        session.dataTask(with: URL).resume()
        let task2 = URLSession.shared.dataTask(with: URL, completionHandler: {(data:Data!, response:URLResponse!, error:Error!) ->Void in
            do{
                var jsonResult : NSDictionary = try JSONSerialization.jsonObject(with: data!, options: []) as! NSDictionary
                //print(NSString(data: data!, encoding: String.Encoding.utf8.rawValue))
                //"?"语法的优点显示出来了：以往在OC中需要使用 if (self.delegate respondsToSelector:) 现在只要一个”?“就行了
                self.delegate?.didRecieveResults(jsonResult)
            }
            catch{
                print(error)
            }

        } as! (Data?, URLResponse?, Error?) -> Void)
        task2.resume()
    }
    
}

