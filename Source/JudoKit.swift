//
//  JudoKit.swift
//  Judo
//
//  Copyright (c) 2016 Alternative Payments Ltd
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

import Foundation
import PassKit


/**
 A method that checks if the device it is currently running on is jailbroken or not
 
 - returns: true if device is jailbroken
 */
public func isCurrentDeviceJailbroken() -> Bool {
    let fileManager = NSFileManager.defaultManager()
    return fileManager.fileExistsAtPath("/private/var/lib/apt/")
}


/// Entry point for interacting with judoKit
public class JudoKit: NSObject {
    
    /// JudoKit local judo session
    public let apiSession: Session
    
    /// the theme of the current judoKitSession
    public var theme: Theme = Theme()
    
    
    /**
     designated initializer of JudoKit
     
     - Parameter token:                  a string object representing the token
     - Parameter secret:                 a string object representing the secret
     - parameter allowJailbrokenDevices: boolean that indicates whether jailbroken devices are restricted
     
     - Throws JailbrokenDeviceDisallowedError: In case jailbroken devices are not allowed, this method will throw an exception if it is run on a jailbroken device
     
     - returns: a new instance of JudoKit
     */
    public init(token: String, secret: String, allowJailbrokenDevices: Bool) throws {
        // Check if device is jailbroken and SDK was set to restrict access
        if !allowJailbrokenDevices && isCurrentDeviceJailbroken() {
            throw JudoError(.JailbrokenDeviceDisallowedError)
        }
        
        self.setToken(token, secret: secret)
    }
    
    
    /**
     convenience initializer of JudoKit
     
     - Parameter token:  a string object representing the token
     - Parameter secret: a string object representing the secret
     
     - returns: a new instance of JudoKit
     */
    convenience public init(token: String, secret: String) {
        try! self.init(token: token, secret: secret, allowJailbrokenDevices: true)
    }
    
    
    // MARK: Configuration
    
    /**
     Set the app to sandboxed mode
     
     - parameter enabled: true to set the SDK to sandboxed mode
     */
    public func sandboxed(enabled: Bool) {
        self.apiSession.sandboxed = enabled
    }
    
    
    /**
     A mandatory function that sets the token and secret for making payments with judo
     
     - Parameter token:  a string object representing the token
     - Parameter secret: a string object representing the secret
     */
    public func setToken(token: String, secret: String) {
        let plainString = token + ":" + secret
        let plainData = plainString.dataUsingEncoding(NSISOLatin1StringEncoding)
        let base64String = plainData!.base64EncodedStringWithOptions(NSDataBase64EncodingOptions.init(rawValue: 0))
        
        self.apiSession.authorizationHeader = "Basic " + base64String
    }
    
    
    /**
     A function to check whether a token and secret has been set
     
     - Returns: a Boolean indicating whether the parameters have been set
     */
    public func didSetTokenAndSecret() -> Bool {
        return self.apiSession.authorizationHeader != nil
    }
    
    // MARK: Transactions
    
    
    /**
    Main payment method
    
    - parameter judoID:       The judoID of the merchant to receive the payment
    - parameter amount:       The amount and currency of the payment (default is GBP)
    - parameter reference:    Reference object that holds consumer and payment reference and a meta data dictionary which can hold any kind of JSON formatted information
    - parameter completion:   The completion handler which will respond with a Response Object or an NSError
    */
    public func payment(judoID: String, amount: Amount, reference: Reference, cardDetails: CardDetails? = nil, completion: (Response?, JudoError?) -> ()) {
        let judoPayViewController = JudoPayViewController(judoID: judoID, amount: amount, reference: reference, completion: completion, currentSession: self)
        self.initiateAndShow(judoPayViewController, cardDetails: cardDetails)
    }
    
    
    /**
    Make a pre-auth using this method
    
    - parameter judoID:       The judoID of the merchant to receive the pre-auth
    - parameter amount:       The amount and currency of the payment (default is GBP)
    - parameter reference:    Reference object that holds consumer and payment reference and a meta data dictionary which can hold any kind of JSON formatted information
    - parameter completion:   The completion handler which will respond with a Response Object or an NSError
    */
    public func preAuth(judoID: String, amount: Amount, reference: Reference, cardDetails: CardDetails? = nil, completion: (Response?, JudoError?) -> ()) {
        let judoPayViewController = JudoPayViewController(judoID: judoID, amount: amount, reference: reference, transactionType: .PreAuth, completion: completion, currentSession: self)
        self.initiateAndShow(judoPayViewController, cardDetails: cardDetails)
    }
    
    
    // MARK: Register Card
    
    
    
    /**
    Initiates a card registration
    
    - parameter judoID:       The judoID of the merchant to receive the pre-auth
    - parameter amount:       The amount and currency of the payment (default is GBP)
    - parameter reference:    Reference object that holds consumer and payment reference and a meta data dictionary which can hold any kind of JSON formatted information
    - parameter completion:   The completion handler which will respond with a Response Object or an NSError
    */
    public func registerCard(judoID: String, amount: Amount, reference: Reference, cardDetails: CardDetails? = nil, completion: (Response?, JudoError?) -> ()) {
        let judoPayViewController = JudoPayViewController(judoID: judoID, amount: amount, reference: reference, transactionType: .RegisterCard, completion: completion, currentSession: self)
        self.initiateAndShow(judoPayViewController, cardDetails: cardDetails)
    }
    
    
    // MARK: Token Transactions
    
    /**
    Initiates the token payment process
    
    - parameter judoID:       The judoID of the merchant to receive the payment
    - parameter amount:       The amount and currency of the payment (default is GBP)
    - parameter reference:    Reference object that holds consumer and payment reference and a meta data dictionary which can hold any kind of JSON formatted information
    - parameter cardDetails:  The card details to present in the input fields
    - parameter paymentToken: The consumer and card token to make a token payment with
    - parameter completion:   The completion handler which will respond with a Response Object or an NSError
    */
    public func tokenPayment(judoID: String, amount: Amount, reference: Reference, cardDetails: CardDetails, paymentToken: PaymentToken, completion: (Response?, JudoError?) -> ()) {
        let vc = UINavigationController(rootViewController: JudoPayViewController(judoID: judoID, amount: amount, reference: reference, transactionType: .Payment, completion: completion, currentSession: self, cardDetails: cardDetails, paymentToken: paymentToken))
        self.showViewController(vc)
    }
    
    
    /**
    Initiates the token pre-auth process
    
    - parameter judoID:       The judoID of the merchant to receive the pre-auth
    - parameter amount:       The amount and currency of the payment (default is GBP)
    - parameter reference:    Reference object that holds consumer and payment reference and a meta data dictionary which can hold any kind of JSON formatted information
    - parameter cardDetails:  The card details to present in the input fields
    - parameter paymentToken: The consumer and card token to make a token payment with
    - parameter completion:   The completion handler which will respond with a Response Object or an NSError
    */
    public func tokenPreAuth(judoID: String, amount: Amount, reference: Reference, cardDetails: CardDetails, paymentToken: PaymentToken, completion: (Response?, JudoError?) -> ()) {
        let vc = UINavigationController(rootViewController: JudoPayViewController(judoID: judoID, amount: amount, reference: reference, transactionType: .PreAuth, completion: completion, currentSession: self, cardDetails: cardDetails, paymentToken: paymentToken))
        self.showViewController(vc)
    }
    
    
    /**
    Executes an Apple Pay payment transaction
    
    - parameter judoID:     The judoID of the merchant to receive the payment
    - parameter amount:     The amount and currency of the payment (default is GBP)
    - parameter reference:  Reference object that holds consumer and payment reference and a meta data dictionary which can hold any kind of JSON formatted information
    - parameter payment:    The PKPayment object that is generated during an ApplePay process
    */
    public func applePayPayment(judoID: String, amount: Amount, reference: Reference, payment: PKPayment, completion: (Response?, JudoError?) -> ()) {
        do {
            try self.payment(judoID, amount: amount, reference: reference).pkPayment(payment).completion(completion)
        } catch {
            completion(nil, JudoError(.ParameterError))
        }
    }
    
    
    /**
    Executes an Apple Pay pre-auth transaction
    
    - parameter judoID:     The judoID of the merchant to receive the pre-auth
    - parameter amount:     The amount and currency of the payment (default is GBP)
    - parameter reference:  Reference object that holds consumer and payment reference and a meta data dictionary which can hold any kind of JSON formatted information
    - parameter payment:    The PKPayment object that is generated during an ApplePay process
    */
    public func applePayPreAuth(judoID: String, amount: Amount, reference: Reference, payment: PKPayment, completion: (Response?, JudoError?) -> ()) {
        do {
            try self.preAuth(judoID, amount: amount, reference: reference).pkPayment(payment).completion(completion)
        } catch {
            completion(nil, JudoError(.ParameterError))
        }
    }
    
    // MARK: Helper methods
    
    
    /**
    Helper method to initiate, pass information and show a JudoPay ViewController
    
    - parameter viewController: the viewController to initiate and show
    - parameter cardDetails:    optional dictionary that contains card info
    */
    func initiateAndShow(viewController: JudoPayViewController, cardDetails: CardDetails? = nil) {
        viewController.myView.cardInputField.textField.text = cardDetails?.cardNumber
        viewController.myView.expiryDateInputField.textField.text = cardDetails?.formattedEndDate()
        self.showViewController(UINavigationController(rootViewController: viewController))
    }
    
    
    /**
     Helper method to show a given ViewController on the top most view
     
     - parameter vc: the viewController to show
     */
    func showViewController(vc: UIViewController) {
        vc.modalPresentationStyle = .FormSheet
        UIApplication.sharedApplication().keyWindow?.rootViewController?.presentViewController(vc, animated: true, completion: nil)
    }
    
    
}
