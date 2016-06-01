//
//  ViewController.swift
//  JudoPayDemoSwift
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

import UIKit
import PassKit
import JudoKit

enum TableViewContent : Int {
    case Payment = 0, PreAuth, CreateCardToken, RepeatPayment, TokenPreAuth, ApplePayPayment, ApplePayPreAuth
    
    static func count() -> Int {
        return 7
    }
    
    func title() -> String {
        switch self {
        case .Payment:
            return "Payment"
        case .PreAuth:
            return "PreAuth"
        case .CreateCardToken:
            return "Add card"
        case .RepeatPayment:
            return "Token payment"
        case .TokenPreAuth:
            return "Token preAuth"
        case .ApplePayPayment:
            return "ApplePay payment"
        case .ApplePayPreAuth:
            return "ApplePay preAuth"
        }
    }
    
    func subtitle() -> String {
        switch self {
        case .Payment:
            return "with default settings"
        case .PreAuth:
            return "to reserve funds on a card"
        case .CreateCardToken:
            return "to be stored for future transactions"
        case .RepeatPayment:
            return "with a stored card token"
        case .TokenPreAuth:
            return "with a stored card token"
        case .ApplePayPayment:
            return "make a payment using ApplePay"
        case .ApplePayPreAuth:
            return "make a preAuth using ApplePay"
        }
    }
    
}

let token               = "<#YOUR TOKEN#>"
let secret              = "<#YOUR SECRET#>"

let judoId              = "<#YOUR JUDO-ID#>"
let tokenPayReference   = "<#YOUR REFERENCE#>"


class ViewController: UIViewController, PKPaymentAuthorizationViewControllerDelegate, UITableViewDelegate, UITableViewDataSource {
    
    static let kCellIdentifier = "com.judo.judopaysample.tableviewcellidentifier"
    
    @IBOutlet var tableView: UITableView!
    @IBOutlet var settingsViewBottomConstraint: NSLayoutConstraint!
    
    var cardDetails: CardDetails?
    var paymentToken: PaymentToken?
    
    var alertController: UIAlertController?
    
    var currentCurrency: Currency = .GBP
    
    var isTransactingApplePayPreAuth = false
    
    var judoKitSession = JudoKit(token: token, secret: secret)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.judoKitSession.theme.acceptedCardNetworks = [Card.Configuration(.Visa, 16), Card.Configuration(.MasterCard, 16), Card.Configuration(.Maestro, 16), Card.Configuration(.AMEX, 15)]
        
        self.judoKitSession.sandboxed(true)
        
        
        self.judoKitSession.theme.showSecurityMessage = true
        
        self.tableView.backgroundColor = UIColor.clearColor()
        
        self.tableView.tableFooterView = {
            let view = UIView(frame: CGRectMake(0, 0, self.view.bounds.size.width, 50))
            let label = UILabel(frame: CGRectMake(15, 15, self.view.bounds.size.width - 30, 50))
            label.numberOfLines = 2
            label.text = "To view test card details:\nSign in to judo and go to Developer/Tools."
            label.font = UIFont.systemFontOfSize(12.0)
            label.textColor = UIColor.grayColor()
            view.addSubview(label)
            return view
            }()
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        if let alertController = self.alertController {
            self.presentViewController(alertController, animated: true, completion: nil)
            self.alertController = nil
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: Actions
    
    @IBAction func settingsButtonHandler(sender: AnyObject) {
        if self.settingsViewBottomConstraint.constant != 0 {
            self.view.layoutIfNeeded()
            self.settingsViewBottomConstraint.constant = 0.0
            UIView.animateWithDuration(0.5, animations: { () -> Void in
                self.tableView.alpha = 0.2
                self.view.layoutIfNeeded()
            })
        }
    }
    
    @IBAction func settingsButtonDismissHandler(sender: AnyObject) {
        if self.settingsViewBottomConstraint.constant == 0 {
            self.view.layoutIfNeeded()
            self.settingsViewBottomConstraint.constant = -190
            UIView.animateWithDuration(0.5, animations: { () -> Void in
                self.tableView.alpha = 1.0
                self.view.layoutIfNeeded()
            })
        }
    }
    
    @IBAction func segmentedControlValueChange(segmentedControl: UISegmentedControl) {
        if let selectedIndexTitle = segmentedControl.titleForSegmentAtIndex(segmentedControl.selectedSegmentIndex) {
            self.currentCurrency = Currency(selectedIndexTitle)
        }
    }
    
    @IBAction func AVSValueChanged(theSwitch: UISwitch) {
        self.judoKitSession.theme.avsEnabled = theSwitch.on
    }
    
    // TODO: need to think of a way to add or remove certain card type acceptance as samples
    
    // MARK: UITableViewDataSource
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return TableViewContent.count()
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(ViewController.kCellIdentifier, forIndexPath: indexPath)
        cell.textLabel?.text = TableViewContent(rawValue: indexPath.row)?.title()
        cell.detailTextLabel?.text = TableViewContent(rawValue: indexPath.row)?.subtitle()
        return cell
    }
    
    
    // MARK: UITableViewDelegate
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
        
        guard let value = TableViewContent(rawValue: indexPath.row) else {
            return
        }
        
        switch value {
        case .Payment:
            paymentOperation()
        case .PreAuth:
            preAuthOperation()
        case .CreateCardToken:
            createCardTokenOperation()
        case .RepeatPayment:
            repeatPaymentOperation()
        case .TokenPreAuth:
            repeatPreAuthOperation()
        case .ApplePayPayment:
            applePayPayment()
        case .ApplePayPreAuth:
            applePayPreAuth()
        }
    }
    
    // MARK: Operations
    
    func paymentOperation() {
        guard let ref = Reference(consumerRef: "payment reference") else { return }
        try! self.judoKitSession.invokePayment(judoId, amount: Amount(decimalNumber: 35, currency: currentCurrency), reference: ref, completion: { (response, error) -> () in
            self.dismissViewControllerAnimated(true, completion: nil)
            if let error = error {
                if error.code == .UserDidCancel {
                    self.dismissViewControllerAnimated(true, completion: nil)
                    return
                }
                var errorTitle = "Error"
                if let errorCategory = error.category {
                    errorTitle = errorCategory.stringValue()
                }
                self.alertController = UIAlertController(title: errorTitle, message: error.message, preferredStyle: .Alert)
                self.alertController!.addAction(UIAlertAction(title: "OK", style: .Cancel, handler: nil))
                self.dismissViewControllerAnimated(true, completion:nil)
                return // BAIL
            }
            
            if let resp = response, transactionData = resp.first {
                self.cardDetails = transactionData.cardDetails
                self.paymentToken = transactionData.paymentToken()
            }
            let sb = UIStoryboard(name: "Main", bundle: nil)
            let viewController = sb.instantiateViewControllerWithIdentifier("detailviewcontroller") as! DetailViewController
            viewController.response = response
            self.navigationController?.pushViewController(viewController, animated: true)
            })
    }
    
    func preAuthOperation() {
        guard let ref = Reference(consumerRef: "payment reference") else { return }
        let amount: Amount = "2 GBP"
        try! self.judoKitSession.invokePreAuth(judoId, amount: amount, reference: ref, completion: { (response, error) -> () in
            self.dismissViewControllerAnimated(true, completion: nil)
            if let error = error {
                if error.code == .UserDidCancel {
                    self.dismissViewControllerAnimated(true, completion: nil)
                    return
                }
                var errorTitle = "Error"
                if let errorCategory = error.category {
                    errorTitle = errorCategory.stringValue()
                }
                self.alertController = UIAlertController(title: errorTitle, message: error.message, preferredStyle: .Alert)
                self.alertController!.addAction(UIAlertAction(title: "OK", style: .Cancel, handler: nil))
                self.dismissViewControllerAnimated(true, completion:nil)
                return // BAIL
            }
            if let resp = response, transactionData = resp.items.first {
                self.cardDetails = transactionData.cardDetails
                self.paymentToken = transactionData.paymentToken()
            }
            let sb = UIStoryboard(name: "Main", bundle: nil)
            let viewController = sb.instantiateViewControllerWithIdentifier("detailviewcontroller") as! DetailViewController
            viewController.response = response
            self.navigationController?.pushViewController(viewController, animated: true)
            })
    }
    
    func createCardTokenOperation() {
        guard let ref = Reference(consumerRef: "payment reference") else { return }
        try! self.judoKitSession.invokeRegisterCard(judoId, amount: Amount(decimalNumber: 1, currency: currentCurrency), reference: ref, completion: { (response, error) -> () in
            self.dismissViewControllerAnimated(true, completion: nil)
            if let error = error {
                if error.code == .UserDidCancel {
                    self.dismissViewControllerAnimated(true, completion: nil)
                    return
                }
                var errorTitle = "Error"
                if let errorCategory = error.category {
                    errorTitle = errorCategory.stringValue()
                }
                self.alertController = UIAlertController(title: errorTitle, message: error.message, preferredStyle: .Alert)
                self.alertController!.addAction(UIAlertAction(title: "OK", style: .Cancel, handler: nil))
                self.dismissViewControllerAnimated(true, completion:nil)
                return // BAIL
            }
            if let resp = response, transactionData = resp.items.first {
                self.cardDetails = transactionData.cardDetails
                self.paymentToken = transactionData.paymentToken()
            }
            })
    }
    
    func repeatPaymentOperation() {
        if let cardDetails = self.cardDetails, let payToken = self.paymentToken, let ref = Reference(consumerRef: "payment reference") {
            try! self.judoKitSession.invokeTokenPayment(judoId, amount: Amount(decimalNumber: 30, currency: currentCurrency), reference: ref, cardDetails: cardDetails, paymentToken: payToken, completion: { (response, error) -> () in
                self.dismissViewControllerAnimated(true, completion: nil)
                if let error = error {
                    if error.code == .UserDidCancel {
                        self.dismissViewControllerAnimated(true, completion: nil)
                        return
                    }
                    var errorTitle = "Error"
                    if let errorCategory = error.category {
                        errorTitle = errorCategory.stringValue()
                    }
                    self.alertController = UIAlertController(title: errorTitle, message: error.message, preferredStyle: .Alert)
                    self.alertController!.addAction(UIAlertAction(title: "OK", style: .Cancel, handler: nil))
                    self.dismissViewControllerAnimated(true, completion:nil)
                    return // BAIL
                }
                if let resp = response, transactionData = resp.items.first {
                    self.cardDetails = transactionData.cardDetails
                    self.paymentToken = transactionData.paymentToken()
                }
                let sb = UIStoryboard(name: "Main", bundle: nil)
                let viewController = sb.instantiateViewControllerWithIdentifier("detailviewcontroller") as! DetailViewController
                viewController.response = response
                self.navigationController?.pushViewController(viewController, animated: true)
            })
        } else {
            let alert = UIAlertController(title: "Error", message: "you need to create a card token before making a repeat payment or preauth operation", preferredStyle: .Alert)
            alert.addAction(UIAlertAction(title: "OK", style: .Cancel, handler: nil))
            self.presentViewController(alert, animated: true, completion: nil)
        }
    }
    
    func repeatPreAuthOperation() {
        if let cardDetails = self.cardDetails, let payToken = self.paymentToken, let ref = Reference(consumerRef: "payment reference") {
            try! self.judoKitSession.invokeTokenPreAuth(judoId, amount: Amount(decimalNumber: 30, currency: currentCurrency), reference: ref, cardDetails: cardDetails, paymentToken: payToken, completion: { (response, error) -> () in
                self.dismissViewControllerAnimated(true, completion: nil)
                if let error = error {
                    if error.code == .UserDidCancel {
                        self.dismissViewControllerAnimated(true, completion: nil)
                        return
                    }
                    var errorTitle = "Error"
                    if let errorCategory = error.category {
                        errorTitle = errorCategory.stringValue()
                    }
                    self.alertController = UIAlertController(title: errorTitle, message: error.message, preferredStyle: .Alert)
                    self.alertController!.addAction(UIAlertAction(title: "OK", style: .Cancel, handler: nil))
                    self.dismissViewControllerAnimated(true, completion:nil)
                    return // BAIL
                }
                if let resp = response, transactionData = resp.items.first {
                    self.cardDetails = transactionData.cardDetails
                    self.paymentToken = transactionData.paymentToken()
                }
                let sb = UIStoryboard(name: "Main", bundle: nil)
                let viewController = sb.instantiateViewControllerWithIdentifier("detailviewcontroller") as! DetailViewController
                viewController.response = response
                self.navigationController?.pushViewController(viewController, animated: true)
                })
        } else {
            let alert = UIAlertController(title: "Error", message: "you need to create a card token before making a repeat payment or preauth operation", preferredStyle: .Alert)
            alert.addAction(UIAlertAction(title: "OK", style: .Cancel, handler: nil))
            self.presentViewController(alert, animated: true, completion: nil)
        }
    }
    
    func applePayPayment() {
        self.isTransactingApplePayPreAuth = false
        self.initiateApplePay()
    }
    
    func applePayPreAuth() {
        self.isTransactingApplePayPreAuth = true
        self.initiateApplePay()
    }
    
    func initiateApplePay() {
        // Set up our payment request.
        let paymentRequest = PKPaymentRequest()
        
        /*
        Our merchant identifier needs to match what we previously set up in
        the Capabilities window (or the developer portal).
        */
        paymentRequest.merchantIdentifier = "<#YOUR-MERCHANT-ID#>"
        
        /*
        Both country code and currency code are standard ISO formats. Country
        should be the region you will process the payment in. Currency should
        be the currency you would like to charge in.
        */
        paymentRequest.countryCode = "GB"
        paymentRequest.currencyCode = "GBP"
        
        // The networks we are able to accept.
        paymentRequest.supportedNetworks = [PKPaymentNetworkAmex, PKPaymentNetworkMasterCard, PKPaymentNetworkVisa]
        
        /*
        we at Judo support 3DS
        */
        paymentRequest.merchantCapabilities = PKMerchantCapability.Capability3DS
        
        /*
        An array of `PKPaymentSummaryItems` that we'd like to display on the
        sheet.
        */
        let items = [PKPaymentSummaryItem(label: "Sub-total", amount: NSDecimalNumber(string: "30.00 £"))]
        
        paymentRequest.paymentSummaryItems = items;
        
        // Request shipping information, in this case just postal address.
        paymentRequest.requiredShippingAddressFields = .PostalAddress
        
        // Display the view controller.
        let viewController = PKPaymentAuthorizationViewController(paymentRequest: paymentRequest)
        viewController.delegate = self
        
        self.presentViewController(viewController, animated: true, completion: nil)
    }
    
    // MARK: PKPaymentAuthorizationViewControllerDelegate
    
    func paymentAuthorizationViewController(controller: PKPaymentAuthorizationViewController, didAuthorizePayment payment: PKPayment, completion: (PKPaymentAuthorizationStatus) -> Void) {
        // WARNING: this can not be properly tested with the sandbox due to restrictions from Apple- if you need to test ApplePay you have to make actual valid transaction and then void them
        let completionBlock: (Response?, JudoError?) -> () = { (response, error) -> () in
            self.dismissViewControllerAnimated(true, completion: nil)
            if let _ = error {
                let alertCont = UIAlertController(title: "Error", message: "there was an error performing the operation", preferredStyle: .Alert)
                alertCont.addAction(UIAlertAction(title: "OK", style: .Cancel, handler: nil))
                self.presentViewController(alertCont, animated: true, completion: nil)
                return // BAIL
            }
            if let resp = response, transactionData = resp.items.first {
                self.cardDetails = transactionData.cardDetails
                self.paymentToken = transactionData.paymentToken()
            }
            let sb = UIStoryboard(name: "Main", bundle: nil)
            let viewController = sb.instantiateViewControllerWithIdentifier("detailviewcontroller") as! DetailViewController
            viewController.response = response
            self.navigationController?.pushViewController(viewController, animated: true)
        }
        
        guard let ref = Reference(consumerRef: "consumer Reference") else { return }
        
        if self.isTransactingApplePayPreAuth {
            try! self.judoKitSession.preAuth(judoId, amount: Amount(decimalNumber: 30, currency: currentCurrency), reference: ref).pkPayment(payment).completion(completionBlock)
        } else {
            try! self.judoKitSession.payment(judoId, amount: Amount(decimalNumber: 30, currency: currentCurrency), reference: ref).pkPayment(payment).completion(completionBlock)
        }
    }
    
    func paymentAuthorizationViewControllerDidFinish(controller: PKPaymentAuthorizationViewController) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
}
