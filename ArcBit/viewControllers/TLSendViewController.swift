//
//  TLSendViewController.swift
//  ArcBit
//
//  Created by Timothy Lee on 3/14/15.
//  Copyright (c) 2015 Timothy Lee <stequald01@gmail.com>
//
//   This library is free software; you can redistribute it and/or
//   modify it under the terms of the GNU Lesser General Public
//   License as published by the Free Software Foundation; either
//   version 2.1 of the License, or (at your option) any later version.
//
//   This library is distributed in the hope that it will be useful,
//   but WITHOUT ANY WARRANTY; without even the implied warranty of
//   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
//   Lesser General Public License for more details.
//
//   You should have received a copy of the GNU Lesser General Public
//   License along with this library; if not, write to the Free Software
//   Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
//   MA 02110-1301  USA

import UIKit
import StoreKit

@objc(TLSendViewController) class TLSendViewController: UIViewController, UITextFieldDelegate, UITabBarDelegate {
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    @IBOutlet fileprivate var currencySymbolButton: UIButton?
    @IBOutlet fileprivate var toAddressTextField: UITextField?
    @IBOutlet fileprivate var amountTextField: UITextField?
    @IBOutlet fileprivate var qrCodeImageView: UIImageView?
    @IBOutlet fileprivate var selectAccountImageView: UIImageView?
    @IBOutlet fileprivate var bitcoinDisplayLabel: UILabel?
    @IBOutlet fileprivate var fiatCurrencyDisplayLabel: UILabel?
    @IBOutlet fileprivate var scanQRButton: UIButton?
    @IBOutlet fileprivate var reviewPaymentButton: UIButton?
    @IBOutlet fileprivate var addressBookButton: UIButton?
    @IBOutlet fileprivate var fiatAmountTextField: UITextField?
    @IBOutlet fileprivate var topView: UIView?
    @IBOutlet fileprivate var bottomView: UIView?
    @IBOutlet fileprivate var accountNameLabel: UILabel?
    @IBOutlet fileprivate var accountBalanceLabel: UILabel?
    @IBOutlet fileprivate var balanceActivityIndicatorView: UIActivityIndicatorView?
    @IBOutlet fileprivate var fromViewContainer: UIView?
    @IBOutlet fileprivate var fromLabel: UILabel!
    @IBOutlet fileprivate var toLabel: UILabel!
    @IBOutlet fileprivate var amountLabel: UILabel!

    @IBOutlet fileprivate var tabBar: UITabBar?
    fileprivate var tapGesture: UITapGestureRecognizer?

    fileprivate func setAmountFromUrlHandler() -> () {
        let dict = AppDelegate.instance().bitcoinURIOptionsDict
        if (dict != nil) {
            let addr = dict!.object(forKey: "address") as! String
            let amount = dict!.object(forKey: "amount") as! String
            guard let godSend = AppDelegate.instance().coinWalletsManager!.godSend else {
                TLPrompts.promptErrorMessage(TLDisplayStrings.ERROR_STRING(), message: "You need to select an account first.")
                return
            }
            self.setAmountFromUrlHandler(TLCurrencyFormat.coinAmountStringToCoin(amount, coinType: godSend.getSelectedObjectCoinType()), address: addr)
            AppDelegate.instance().bitcoinURIOptionsDict = nil
        }
    }
    
    fileprivate func setAmountFromUrlHandler(_ amount: TLCoin, address: String) {
        guard let godSend = AppDelegate.instance().coinWalletsManager!.godSend else {
            TLPrompts.promptErrorMessage(TLDisplayStrings.ERROR_STRING(), message: "You need to select an account first.")
            return
        }
        self.toAddressTextField!.text = address
        let amountString = TLCurrencyFormat.coinToProperBitcoinAmountString(amount, coinType: godSend.getSelectedObjectCoinType())
        self.amountTextField!.text = amountString
        
        TLSendFormData.instance().setAddress(address)
        TLSendFormData.instance().setAmount(amountString)
        
        self.updateFiatAmountTextFieldExchangeRate(nil)
    }
    
    fileprivate func setAllCoinsBarButton() {
        let allBarButtonItem = UIBarButtonItem(title: TLDisplayStrings.USE_ALL_FUNDS_STRING(), style: UIBarButtonItemStyle.plain, target: self, action: #selector(TLSendViewController.checkToFetchUTXOsAndDynamicFeesAndFillAmountFieldWithWholeBalance))
        navigationItem.rightBarButtonItem = allBarButtonItem
    }
    
    fileprivate func clearRightBarButton() {
        let allBarButtonItem = UIBarButtonItem(title: "", style: UIBarButtonItemStyle.plain, target: self, action: nil)
        navigationItem.rightBarButtonItem = allBarButtonItem
    }
    
    func checkToFetchUTXOsAndDynamicFeesAndFillAmountFieldWithWholeBalance() {
        guard let godSend = AppDelegate.instance().coinWalletsManager!.godSend else {
            TLPrompts.promptErrorMessage(TLDisplayStrings.ERROR_STRING(), message: "You need to select an account first.")
            return
        }
        let coinType = godSend.getSelectedObjectCoinType()
        if TLPreferences.enabledInAppSettingsKitDynamicFee(coinType) {
            if !godSend.haveUpDatedUnspentOutputs() {
                godSend.getAndSetUnspentOutputs({
                    self.checkToFetchDynamicFeesAndFillAmountFieldWithWholeBalance()
                    }, failure: {
                        TLPrompts.promptErrorMessage(TLDisplayStrings.ERROR_STRING(), message: TLDisplayStrings.ERROR_FETCHING_UNSPENT_OUTPUTS_TRY_AGAIN_LATER_STRING())
                })
            } else {
                self.checkToFetchDynamicFeesAndFillAmountFieldWithWholeBalance()
            }
        } else {
            self.fillAmountFieldWithWholeBalance(false)
        }
    }

    func checkToFetchDynamicFeesAndFillAmountFieldWithWholeBalance() {
        guard let godSend = AppDelegate.instance().coinWalletsManager!.godSend else {
            TLPrompts.promptErrorMessage(TLDisplayStrings.ERROR_STRING(), message: "You need to select an account first.")
            return
        }
        let coinType = godSend.getSelectedObjectCoinType()
        if !AppDelegate.instance().txFeeAPI.haveUpdatedCachedDynamicFees(coinType) {
            AppDelegate.instance().txFeeAPI.getDynamicTxFee(coinType, success: {
                (_jsonData) in
                self.fillAmountFieldWithWholeBalance(true)
                }, failure: {
                    (code, status) in
                    TLPrompts.promptErrorMessage(TLDisplayStrings.ERROR_STRING(), message: TLDisplayStrings.UNABLE_TO_GET_DYNAMIC_FEES_STRING())
                    self.fillAmountFieldWithWholeBalance(false)
            })
        } else {
            self.fillAmountFieldWithWholeBalance(true)
        }
    }

    
    func fillAmountFieldWithWholeBalance(_ useDynamicFees: Bool) {
        guard let godSend = AppDelegate.instance().coinWalletsManager!.godSend else {
            TLPrompts.promptErrorMessage(TLDisplayStrings.ERROR_STRING(), message: "You need to select an account first.")
            return
        }
        let fee:TLCoin
        let txSizeBytes:UInt64
        if useDynamicFees {
            if godSend.getSelectedObjectType() == .account {
                let accountObject = godSend as! TLAccountObject
                let inputCount = accountObject.unspentOutputsCount
                txSizeBytes = TLSpaghettiGodSend.getEstimatedTxSize(inputCount, outputCount: 1)
                DLog("fillAmountFieldWithWholeBalance TLAccountObject useDynamicFees inputCount txSizeBytes: \(inputCount) \(txSizeBytes)")
            } else {
                let importedAddress = godSend as! TLImportedAddress
                txSizeBytes = TLSpaghettiGodSend.getEstimatedTxSize(importedAddress.unspentOutputsCount, outputCount: 1)
                DLog("fillAmountFieldWithWholeBalance importedAddress useDynamicFees inputCount txSizeBytes: \(importedAddress.unspentOutputsCount) \(txSizeBytes)")
            }
            
            let coinType = godSend.getSelectedObjectCoinType()
            if let dynamicFeeSatoshis:NSNumber = AppDelegate.instance().txFeeAPI.getCachedDynamicFee(coinType) {
                fee = TLCoin(uint64: txSizeBytes*dynamicFeeSatoshis.uint64Value)
                DLog("fillAmountFieldWithWholeBalance coinFeeAmount dynamicFeeSatoshis: \(txSizeBytes*dynamicFeeSatoshis.uint64Value)")
            } else {
                fee = TLCurrencyFormat.coinAmountStringToCoin(TLPreferences.getInAppSettingsKitTransactionFee(coinType)!, coinType: coinType)
            }
            
        } else {
            let coinType = godSend.getSelectedObjectCoinType()
            let feeAmount = TLPreferences.getInAppSettingsKitTransactionFee(coinType)
            fee = TLCurrencyFormat.coinAmountStringToCoin(feeAmount!, coinType: godSend.getSelectedObjectCoinType())
        }

        let accountBalance = godSend.getCurrentFromBalance()
        let sendAmount = accountBalance.subtract(fee)
        DLog("fillAmountFieldWithWholeBalance accountBalance: \(accountBalance.toUInt64())")
        DLog("fillAmountFieldWithWholeBalance sendAmount: \(sendAmount.toUInt64())")
        DLog("fillAmountFieldWithWholeBalance fee: \(fee.toUInt64())")
        TLSendFormData.instance().feeAmount = fee
        TLSendFormData.instance().useAllFunds = true
        if accountBalance.greater(fee) && sendAmount.greater(TLCoin.zero()) {
            TLSendFormData.instance().setAmount(TLCurrencyFormat.coinToProperBitcoinAmountString(sendAmount, coinType: godSend.getSelectedObjectCoinType()))
        } else {
            TLSendFormData.instance().setAmount(nil)
        }
        TLSendFormData.instance().setFiatAmount(nil)
        self.updateSendForm()
    }
    
    func setupLabels() {
        let sendTabBarItem = self.tabBar?.items?[0]
        sendTabBarItem?.title = TLDisplayStrings.SEND_STRING()
        let receiveTabBarItem = self.tabBar?.items?[1]
        receiveTabBarItem?.title = TLDisplayStrings.RECEIVE_STRING()
        self.toAddressTextField?.placeholder = TLDisplayStrings.ADDRESS_STRING()

        self.toLabel.text = TLDisplayStrings.TO_COLON_STRING()
        self.fromLabel.text = TLDisplayStrings.FROM_COLON_STRING()
        self.amountLabel.text = TLDisplayStrings.AMOUNT_COLON_STRING()
        self.scanQRButton?.setTitle(TLDisplayStrings.SCAN_QR_STRING(), for: .normal)
        self.addressBookButton?.setTitle(TLDisplayStrings.CONTACTS_STRING(), for: .normal)
        self.reviewPaymentButton?.setTitle(TLDisplayStrings.REVIEW_PAYMENT_STRING(), for: .normal)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setColors()
        
        self.setLogoImageView()
        self.setupLabels()
        
        self.bottomView!.backgroundColor = TLColors.mainAppColor()
        
        self.fromViewContainer!.backgroundColor = TLColors.mainAppColor()
        self.accountNameLabel!.textColor = TLColors.mainAppOppositeColor()
        self.accountBalanceLabel!.textColor = TLColors.mainAppOppositeColor()
        self.balanceActivityIndicatorView!.color = TLColors.mainAppOppositeColor()
        
        self.scanQRButton!.backgroundColor = TLColors.mainAppColor()
        self.reviewPaymentButton!.backgroundColor = TLColors.mainAppColor()
        self.addressBookButton!.backgroundColor = TLColors.mainAppColor()
        self.scanQRButton!.setTitleColor(TLColors.mainAppOppositeColor(), for: UIControlState())
        self.reviewPaymentButton!.setTitleColor(TLColors.mainAppOppositeColor(), for: UIControlState())
        self.addressBookButton!.setTitleColor(TLColors.mainAppOppositeColor(), for: UIControlState())
        self.updateViewForEnabledCryptoCoinsIfChanged()

        if TLUtils.isIPhone5() || TLUtils.isIPhone4() {
            let keyboardDoneButtonView = UIToolbar()
            keyboardDoneButtonView.sizeToFit()
            let item = UIBarButtonItem(title: TLDisplayStrings.DONE_STRING(), style: UIBarButtonItemStyle.plain, target: self, action: #selector(TLSendViewController.dismissKeyboard) )
            let toolbarButtons = [item]
            keyboardDoneButtonView.setItems(toolbarButtons, animated: false)
            self.amountTextField!.inputAccessoryView = keyboardDoneButtonView
            self.fiatAmountTextField!.inputAccessoryView = keyboardDoneButtonView
        }

        NotificationCenter.default.post(name: Notification.Name(rawValue: TLNotificationEvents.EVENT_SEND_SCREEN_LOADING()),
            object: nil)
        

        self.tabBar!.selectedItem = ((self.tabBar!.items as NSArray!).object(at: 0)) as? UITabBarItem
        if UIScreen.main.bounds.size.height <= 480.0 { // is 3.5 inch screen
            self.tabBar!.isHidden = true
        }
        
        
        NotificationCenter.default.addObserver(self
            ,selector:#selector(TLSendViewController.dismissTextFieldsAndScrollDown(_:)),
            name:NSNotification.Name(rawValue: TLNotificationEvents.EVENT_HAMBURGER_MENU_OPENED()), object:nil)
        NotificationCenter.default.addObserver(self
            ,selector:#selector(TLSendViewController.clearSendForm(_:)),
            name:NSNotification.Name(rawValue: TLNotificationEvents.EVENT_PREFERENCES_FIAT_DISPLAY_CHANGED()), object:nil)
        NotificationCenter.default.addObserver(self
            ,selector:#selector(TLSendViewController.clearSendForm(_:)),
            name:NSNotification.Name(rawValue: TLNotificationEvents.EVENT_PREFERENCES_COIN_UNIT_DISPLAY_CHANGED()), object:nil)
        NotificationCenter.default.addObserver(self
            ,selector:#selector(TLSendViewController.updateCurrencyView(_:)),
            name:NSNotification.Name(rawValue: TLNotificationEvents.EVENT_PREFERENCES_FIAT_DISPLAY_CHANGED()), object:nil)
        NotificationCenter.default.addObserver(self
            ,selector:#selector(TLSendViewController.updateBitcoinDisplayView(_:)),
            name:NSNotification.Name(rawValue: TLNotificationEvents.EVENT_PREFERENCES_COIN_UNIT_DISPLAY_CHANGED()), object:nil)
        NotificationCenter.default.addObserver(self
            ,selector:#selector(TLSendViewController.updateAccountBalanceView(_:)),
            name:NSNotification.Name(rawValue: TLNotificationEvents.EVENT_PREFERENCES_FIAT_DISPLAY_CHANGED()), object:nil)
        NotificationCenter.default.addObserver(self
            ,selector:#selector(TLSendViewController.updateAccountBalanceView(_:)),
            name:NSNotification.Name(rawValue: TLNotificationEvents.EVENT_PREFERENCES_COIN_UNIT_DISPLAY_CHANGED()), object:nil)
        NotificationCenter.default.addObserver(self
            ,selector:#selector(TLSendViewController.updateAccountBalanceView(_:)),
            name:NSNotification.Name(rawValue: TLNotificationEvents.EVENT_DISPLAY_LOCAL_CURRENCY_TOGGLED()), object:nil)
        NotificationCenter.default.addObserver(self
            ,selector:#selector(TLSendViewController.updateAccountBalanceView(_:)),
            name:NSNotification.Name(rawValue: TLNotificationEvents.EVENT_FETCHED_ADDRESSES_DATA()), object:nil)
        NotificationCenter.default.addObserver(self
            ,selector:#selector(TLSendViewController.hideHUDAndUpdateBalanceView),
            name:NSNotification.Name(rawValue: TLNotificationEvents.EVENT_MODEL_UPDATED_NEW_UNCONFIRMED_TRANSACTION()), object:nil)
        NotificationCenter.default.addObserver(self
            ,selector:#selector(TLSendViewController.clearSendForm(_:)),
             name:NSNotification.Name(rawValue: TLNotificationEvents.EVENT_SEND_PAYMENT()), object:nil)
        NotificationCenter.default.addObserver(self
            ,selector:#selector(TLSendViewController.updateAccountBalanceView(_:)),
             name:NSNotification.Name(rawValue: TLNotificationEvents.EVENT_EXCHANGE_RATE_UPDATED()), object:nil)

        
        self.updateSendForm()
        
        self.amountTextField!.keyboardType = .decimalPad
        self.amountTextField!.delegate = self
        self.fiatAmountTextField!.keyboardType = .decimalPad
        self.fiatAmountTextField!.delegate = self
        
        self.toAddressTextField!.delegate = self
        self.toAddressTextField!.clearButtonMode = UITextFieldViewMode.whileEditing
        
        self.currencySymbolButton?.setBackgroundImage(UIImage(named: "balance_bg_pressed.9.png"), for: .highlighted)
        self.currencySymbolButton?.setBackgroundImage(UIImage(named: "balance_bg_normal.9.png"), for: UIControlState())
        
        self.sendViewSetup()
        
        if self.slidingViewController() != nil {
            self.slidingViewController().topViewAnchoredGesture = [.tapping, .panning]
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        self.topView!.scrollToY(0)
    }
    
    func updateViewToNoneSelectedObject() {
        self.accountNameLabel!.text = ""
        self.accountBalanceLabel!.text = ""
        self.balanceActivityIndicatorView!.isHidden = true
        self.fiatCurrencyDisplayLabel!.text = ""
        self.bitcoinDisplayLabel!.text = ""
    }
    
    fileprivate func sendViewSetup() -> () {
        self._updateCurrencyView()
        self._updateBitcoinDisplayView()
        
        self.updateViewToNewSelectedObject()
        guard let godSend = AppDelegate.instance().coinWalletsManager!.godSend else {
            self.updateViewToNoneSelectedObject()
            return
        }
        if godSend.hasFetchedCurrentFromData() {
            let balance = godSend.getCurrentFromBalance()
            let balanceString = TLCurrencyFormat.getProperAmount(balance, coinType: godSend.getSelectedObjectCoinType())
            self.accountBalanceLabel!.text = balanceString as String
            self.accountBalanceLabel!.isHidden = false
            self.balanceActivityIndicatorView!.stopAnimating()
            self.balanceActivityIndicatorView!.isHidden = true
        } else {
            self.refreshAccountDataAndSetBalanceView()
        }
        if (AppDelegate.instance().justSetupHDWallet) {
            self.showReceiveView()
        }
    }
    
    func refreshAccountDataAndSetBalanceView(_ fetchDataAgain: Bool = false) -> () {
        guard let godSend = AppDelegate.instance().coinWalletsManager!.godSend else {
            self.updateViewToNoneSelectedObject()
            return
        }
        if godSend.getSelectedObjectType() == .account {
            let accountObject = godSend as! TLAccountObject
            self.balanceActivityIndicatorView!.isHidden = false
            self.accountBalanceLabel!.isHidden = true
            self.balanceActivityIndicatorView!.startAnimating()
            AppDelegate.instance().pendingOperations.addSetUpAccountOperation(accountObject, fetchDataAgain: fetchDataAgain, success: {
                if accountObject.downloadState == .downloaded {
                    self.accountBalanceLabel!.isHidden = false
                    self.balanceActivityIndicatorView!.stopAnimating()
                    self.balanceActivityIndicatorView!.isHidden = true
                    self._updateAccountBalanceView()
                }
            })
            
        } else if godSend.getSelectedObjectType() == .address {
            let importedAddress = godSend as! TLImportedAddress
            self.balanceActivityIndicatorView!.isHidden = false
            self.accountBalanceLabel!.isHidden = true
            self.balanceActivityIndicatorView!.startAnimating()
            AppDelegate.instance().pendingOperations.addSetUpImportedAddressOperation(importedAddress, fetchDataAgain: fetchDataAgain, success: {
                if importedAddress.downloadState == .downloaded {
                    self.accountBalanceLabel!.isHidden = false
                    self.balanceActivityIndicatorView!.stopAnimating()
                    self.balanceActivityIndicatorView!.isHidden = true
                    self._updateAccountBalanceView()
                }
            })
        }
    }
    
    fileprivate func showReceiveView() -> () {
        self.slidingViewController().topViewController = self.storyboard!.instantiateViewController(withIdentifier: "ReceiveNav") 
    }
    
    fileprivate func updateViewToNewSelectedObject() -> () {
        guard let godSend = AppDelegate.instance().coinWalletsManager!.godSend else {
            self.updateViewToNoneSelectedObject()
            return
        }
        let label = godSend.getCurrentFromLabel()
        self.accountNameLabel!.text = label
        self._updateAccountBalanceView()
        self._updateCurrencyView()
        self._updateBitcoinDisplayView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.updateViewToNewSelectedObject()
    
        // TODO: better way
        if AppDelegate.instance().scannedEncryptedPrivateKey != nil {
            guard let godSend = AppDelegate.instance().coinWalletsManager!.godSend else {
                return
            }
            let coinType = godSend.getSelectedObjectCoinType()
            TLPrompts.promptForEncryptedPrivKeyPassword(self, view:self.slidingViewController().topViewController.view,
                                                        coinType: coinType, encryptedPrivKey:AppDelegate.instance().scannedEncryptedPrivateKey!,
                success:{(privKey: String!) in
                    if AppDelegate.instance().scannedEncryptedPrivateKey == nil {
                        return
                    }

                    let coinType = godSend.getSelectedObjectCoinType()
                    if (!TLCoreBitcoinWrapper.isValidPrivateKey(coinType, privateKey: privKey, isTestnet: AppDelegate.instance().appWallet.walletConfig.isTestnet)) {
                        TLPrompts.promptErrorMessage(TLDisplayStrings.ERROR_STRING(), message: TLDisplayStrings.INVALID_PRIVATE_KEY_STRING())
                    } else {
                        let importedAddress = godSend as! TLImportedAddress
                        let success = importedAddress.setPrivateKeyInMemory(privKey)
                        if (!success) {
                            TLPrompts.promptSuccessMessage(TLDisplayStrings.ERROR_STRING(), message: TLDisplayStrings.PRIVATE_KEY_DOES_NOT_MATCH_ADDRESS_STRING())
                        } else {
                            self._reviewPaymentClicked()
                        }
                        AppDelegate.instance().scannedEncryptedPrivateKey = nil
                    }
                }, failure:{(isCanceled: Bool) in
                    AppDelegate.instance().scannedEncryptedPrivateKey = nil
            })
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        NotificationCenter.default.post(name: Notification.Name(rawValue: TLNotificationEvents.EVENT_VIEW_SEND_SCREEN()),
            object: nil, userInfo: nil)
        
        self.setAmountFromUrlHandler()
        
        if (!TLPreferences.getInAppSettingsKitEnablePinCode() && TLSuggestions.instance().conditionToPromptToSuggestEnablePinSatisfied()) {
            TLSuggestions.instance().promptToSuggestEnablePin(self)
        } else if TLSuggestions.instance().conditionToPromptRateAppSatisfied() {
            if  #available(iOS 10.3, *) {
                SKStoreReviewController.requestReview()
            } else {
                TLPrompts.promptAlertController(self, title: TLDisplayStrings.LIKE_USING_ARCBIT_STRING(),
                                                message: TLDisplayStrings.RATE_US_IN_THE_APP_STORE_STRING(), okText: TLDisplayStrings.RATE_STRING(), cancelTx: TLDisplayStrings.NOT_NOW_STRING(),
                                                success: { () -> () in
                                                    let url = URL(string: "https://itunes.apple.com/app/id999487888");
                                                    if (UIApplication.shared.canOpenURL(url!)) {
                                                        UIApplication.shared.openURL(url!);
                                                    }
                                                    TLPreferences.setDisabledPromptRateApp(true)
                                                    if !TLPreferences.hasRatedOnce() {
                                                        TLPreferences.setHasRatedOnce()
                                                    }
                }, failure: { (Bool) -> () in
                })
            }
        } else if TLSuggestions.instance().conditionToPromptShowWebWallet() {
            TLPrompts.promptAlertController(self, title: TLDisplayStrings.CHECK_OUT_THE_ARCBIT_WEB_WALLET_EXCLAMATION_STRING(),
                message: TLDisplayStrings.CHECK_OUT_THE_ARCBIT_WEB_WALLET_DESC_STRING(), okText: TLDisplayStrings.GO_STRING(), cancelTx: TLDisplayStrings.NOT_NOW_STRING(),
                success: { () -> () in
                    let url = URL(string: "https://chrome.google.com/webstore/detail/arcbit-bitcoin-wallet/dkceiphcnbfahjbomhpdgjmphnpgogfk");
                    if (UIApplication.shared.canOpenURL(url!)) {
                        UIApplication.shared.openURL(url!);
                    }
                    TLPreferences.setDisabledPromptShowWebWallet(true)
                }, failure: { (Bool) -> () in
            })
        } else if TLSuggestions.instance().conditionToPromptTryColdWallet() {
            TLPreferences.setEnableColdWallet(true)
            TLPreferences.setEnableInAppSettingsKitColdWallet(true)
               let msg = TLDisplayStrings.TRY_OUR_NEW_COLD_WALLET_FEATURE_DESC_STRING()
            TLPrompts.promtForOK(self, title:TLDisplayStrings.TRY_OUR_NEW_COLD_WALLET_FEATURE_STRING(), message:msg, success: {
                () in
                TLPreferences.setDisabledPromptShowTryColdWallet(true)
            })
        } else if let balance = AppDelegate.instance().coinWalletsManager!.receiveSelectedObject?.getBalanceForSelectedObject(), balance.greater(TLCoin.zero()) && !TLPreferences.hasShownBackupPassphrase() {
            self.showPromptThenPassphraseViewController()
        }
        if TLPreferences.getEnableBackupWithiCloud() {
            TLPreferences.setEnableBackupWithiCloud(false)
            TLPreferences.setInAppSettingsKitEnableBackupWithiCloud(false)
            TLPrompts.promptWithOneButton(self, title: TLDisplayStrings.ICLOUD_SUPPORT_DISCONTINUED(), message: TLDisplayStrings.ICLOUD_SUPPORT_DISCONTINUED_DESCRIPTION(), buttonText: TLDisplayStrings.I_UNDERSTAND(), success: {
            })
        }
        self.navigationController!.view.addGestureRecognizer(self.slidingViewController().panGesture)
    }
    
    func showPromptThenPassphraseViewController() {
        TLPrompts.promptWithOneButton(self, title: TLDisplayStrings.WALLET_BACKUP_PASSPHRASE_WILL_BE_SHOWN(), message: TLDisplayStrings.PLEASE_WRITE_DOWN_OR_MEMORIZE_YOUR_WALLET_BACKUP_PASSPHRASE(), buttonText: TLDisplayStrings.I_UNDERSTAND(), success: {
            let vc = self.storyboard!.instantiateViewController(withIdentifier: "Passphrase")
            self.slidingViewController().present(vc, animated: true, completion: nil)
        })
    }
    
    func _clearSendForm() {
        TLSendFormData.instance().setAddress(nil)
        TLSendFormData.instance().setAmount(nil)
        self.updateSendForm()
    }
    
    func clearSendForm(_ notification: Notification) {
        _clearSendForm()
    }
    
    fileprivate func updateSendForm() {
        self.toAddressTextField!.text = TLSendFormData.instance().getAddress()
        
        if (TLSendFormData.instance().getAmount() != nil) {
            self.amountTextField!.text = TLSendFormData.instance().getAmount()!
            self.updateFiatAmountTextFieldExchangeRate(nil)
        } else if (TLSendFormData.instance().getFiatAmount() != nil) {
            self.fiatAmountTextField!.text = TLSendFormData.instance().getFiatAmount()!
            self.updateAmountTextFieldExchangeRate(nil)
        } else {
            self.amountTextField!.text = nil
            self.fiatAmountTextField!.text = nil
        }
    }
    
    func _updateCurrencyView() {
        let currency = TLCurrencyFormat.getFiatCurrency()
        self.fiatCurrencyDisplayLabel!.text = currency
        
        self.updateSendForm()
        
        self.updateAmountTextFieldExchangeRate(nil)
    }
    
    func updateCurrencyView(_ notification: Notification) {
        _updateCurrencyView()
    }
    
    func _updateBitcoinDisplayView() {
        guard let godSend = AppDelegate.instance().coinWalletsManager!.godSend else {
            self.updateViewToNoneSelectedObject()
            return
        }
        let bitcoinDisplay = TLCurrencyFormat.getBitcoinDisplay(godSend.getSelectedObjectCoinType())
        self.bitcoinDisplayLabel!.text = bitcoinDisplay
        
        self.updateSendForm()
        
        self.updateFiatAmountTextFieldExchangeRate(nil)
    }
    
    func updateBitcoinDisplayView(_ notification: Notification) {
        _updateBitcoinDisplayView()
    }
    
    func dismissKeyboard() {
        self.amountTextField!.resignFirstResponder()
        self.fiatAmountTextField!.resignFirstResponder()
        self.toAddressTextField!.resignFirstResponder()
        if self.tapGesture != nil {
            self.view.removeGestureRecognizer(self.tapGesture!)
            self.tapGesture = nil
        }
        self.topView!.scrollToY(0)
    }
    
    func hideHUDAndUpdateBalanceView() {
        self.accountBalanceLabel!.isHidden = false
        self.balanceActivityIndicatorView!.stopAnimating()
        self.balanceActivityIndicatorView!.isHidden = true
        self._updateAccountBalanceView()
    }
    
    func _updateAccountBalanceView() {
        guard let godSend = AppDelegate.instance().coinWalletsManager!.godSend else {
            self.updateViewToNoneSelectedObject()
            return
        }
        let balance = godSend.getCurrentFromBalance()
        let balanceString = TLCurrencyFormat.getProperAmount(balance, coinType: godSend.getSelectedObjectCoinType())
        self.accountBalanceLabel!.text = balanceString as String
    }
    
    func updateAccountBalanceView(_ notification: Notification) {
        self._updateAccountBalanceView()
    }
        
    fileprivate func fillToAddressTextField(_ address: String) -> Bool {
        guard let godSend = AppDelegate.instance().coinWalletsManager!.godSend else {
            TLPrompts.promptErrorMessage(TLDisplayStrings.ERROR_STRING(), message: "You need to select an account first.")
            return false
        }
        let coinType = godSend.getSelectedObjectCoinType()
        if (TLCoreBitcoinWrapper.isValidAddress(coinType, address: address, isTestnet: AppDelegate.instance().appWallet.walletConfig.isTestnet)) {
            self.toAddressTextField!.text = address
            TLSendFormData.instance().setAddress(address)
            return true
        } else {
            let av = UIAlertView(title: TLDisplayStrings.INVALID_ADDRESS_STRING(),
                message: "",
                delegate: nil,
                cancelButtonTitle: TLDisplayStrings.OK_STRING()
            )
            
            av.show()
            return false
        }
    }
    
    fileprivate func checkTofetchFeeThenFinalPromptReviewTx() {
        guard let godSend = AppDelegate.instance().coinWalletsManager!.godSend else {
            TLPrompts.promptErrorMessage(TLDisplayStrings.ERROR_STRING(), message: "You need to select an account first.")
            return
        }
        let coinType = godSend.getSelectedObjectCoinType()
        if TLPreferences.enabledInAppSettingsKitDynamicFee(coinType) && !AppDelegate.instance().txFeeAPI.haveUpdatedCachedDynamicFees(coinType) {
            AppDelegate.instance().txFeeAPI.getDynamicTxFee(coinType, success: {
                (_jsonData) in
                self.showFinalPromptReviewTx()
                }, failure: {
                    (code, status) in
                    self.showFinalPromptReviewTx()
            })
        } else {
            self.showFinalPromptReviewTx()
        }
    }

    fileprivate func showFinalPromptReviewTx() {
        guard let godSend = AppDelegate.instance().coinWalletsManager!.godSend else {
            TLPrompts.promptErrorMessage(TLDisplayStrings.ERROR_STRING(), message: "You need to select an account first.")
            return
        }

        let bitcoinAmount = self.amountTextField!.text
        let toAddress = self.toAddressTextField!.text
    
        let coinType = godSend.getSelectedObjectCoinType()
        if (!TLCoreBitcoinWrapper.isValidAddress(coinType, address: toAddress!, isTestnet: AppDelegate.instance().appWallet.walletConfig.isTestnet)) {
            TLPrompts.promptErrorMessage(TLDisplayStrings.ERROR_STRING(), message: TLDisplayStrings.INVALID_ADDRESS_STRING())
            return
        }

        DLog("showFinalPromptReviewTx bitcoinAmount \(bitcoinAmount!)")
        let inputtedAmount = TLCurrencyFormat.properBitcoinAmountStringToCoin(bitcoinAmount!, coinType: godSend.getSelectedObjectCoinType())
        
        if (inputtedAmount.equalTo(TLCoin.zero())) {
            TLPrompts.promptErrorMessage(TLDisplayStrings.ERROR_STRING(), message: TLDisplayStrings.INVALID_AMOUNT_STRING())
            return
        }
        

        func showReviewPaymentViewController(_ useDynamicFees: Bool) {
            let fee:TLCoin
            let txSizeBytes:UInt64
            if useDynamicFees {
                if TLSendFormData.instance().useAllFunds {
                    fee = TLSendFormData.instance().feeAmount!
                } else {
                    if godSend.getSelectedObjectType() == .account {
                        let accountObject = godSend as! TLAccountObject
                        let inputCount = accountObject.getInputsNeededToConsume(inputtedAmount)
                        //TODO account for change output, output count likely 2 (3 if have stealth payment) cause if user dont do click use all funds because will likely have change
                        // but for now dont need to be fully accurate with tx fee, for now we will underestimate tx fee, wont underestimate much because outputs contributes little to tx size
                        txSizeBytes = TLSpaghettiGodSend.getEstimatedTxSize(inputCount, outputCount: 1)
                        DLog("showPromptReviewTx TLAccountObject useDynamicFees inputCount txSizeBytes: \(inputCount) \(txSizeBytes)")
                    } else {
                        let importedAddress = godSend as! TLImportedAddress
                        // TODO same as above
                        let inputCount = importedAddress.getInputsNeededToConsume(inputtedAmount)
                        txSizeBytes = TLSpaghettiGodSend.getEstimatedTxSize(inputCount, outputCount: 1)
                        DLog("showPromptReviewTx importedAddress useDynamicFees inputCount txSizeBytes: \(importedAddress.unspentOutputsCount) \(txSizeBytes)")
                    }
                    
                    let coinType = godSend.getSelectedObjectCoinType()
                    if let dynamicFeeSatoshis:NSNumber = AppDelegate.instance().txFeeAPI.getCachedDynamicFee(coinType) {
                        fee = TLCoin(uint64: txSizeBytes*dynamicFeeSatoshis.uint64Value)
                        DLog("showPromptReviewTx coinFeeAmount dynamicFeeSatoshis: \(txSizeBytes*dynamicFeeSatoshis.uint64Value)")
                        
                    } else {
                        fee = TLCurrencyFormat.coinAmountStringToCoin(TLPreferences.getInAppSettingsKitTransactionFee(coinType)!, coinType: coinType)
                    }
                    TLSendFormData.instance().feeAmount = fee
                }
            } else {
                let coinType = godSend.getSelectedObjectCoinType()
                let feeAmount = TLPreferences.getInAppSettingsKitTransactionFee(coinType)
                fee = TLCurrencyFormat.coinAmountStringToCoin(feeAmount!, coinType: godSend.getSelectedObjectCoinType())
                TLSendFormData.instance().feeAmount = fee
            }
            
            let amountNeeded = inputtedAmount.add(fee)
            let accountBalance = godSend.getCurrentFromBalance()
            if (amountNeeded.greater(accountBalance)) {
                let coinType = godSend.getSelectedObjectCoinType()
                let msg = String(format: TLDisplayStrings.YOU_HAVE_X_Y_BUT_Z_IS_NEEDED_STRING(), "\(TLCurrencyFormat.coinToProperBitcoinAmountString(accountBalance, coinType: coinType)) \(TLCurrencyFormat.getBitcoinDisplay(godSend.getSelectedObjectCoinType()))", TLCurrencyFormat.coinToProperBitcoinAmountString(amountNeeded, coinType: coinType))
                TLPrompts.promptErrorMessage(TLDisplayStrings.INSUFFICIENT_FUNDS_STRING(), message: msg)
                return
            }
            
            DLog("showPromptReviewTx accountBalance: \(accountBalance.toUInt64())")
            DLog("showPromptReviewTx inputtedAmount: \(inputtedAmount.toUInt64())")
            DLog("showPromptReviewTx fee: \(fee.toUInt64())")
            TLSendFormData.instance().fromLabel = godSend.getCurrentFromLabel()!
            let vc = self.storyboard!.instantiateViewController(withIdentifier: "ReviewPayment") as! TLReviewPaymentViewController
            self.slidingViewController().present(vc, animated: true, completion: nil)
        }
        
        func checkToFetchDynamicFees() {
            let coinType = godSend.getSelectedObjectCoinType()
            if !AppDelegate.instance().txFeeAPI.haveUpdatedCachedDynamicFees(coinType) {
                AppDelegate.instance().txFeeAPI.getDynamicTxFee(coinType, success: {
                    (_jsonData) in
                    showReviewPaymentViewController(true)
                    }, failure: {
                        (code, status) in
                        TLPrompts.promptErrorMessage(TLDisplayStrings.ERROR_STRING(), message: TLDisplayStrings.UNABLE_TO_GET_DYNAMIC_FEES_STRING())
                        showReviewPaymentViewController(false)
                })
            } else {
                showReviewPaymentViewController(true)
            }
        }
        
        if TLPreferences.enabledInAppSettingsKitDynamicFee(coinType) {
            if !godSend.haveUpDatedUnspentOutputs() {
                godSend.getAndSetUnspentOutputs({
                    checkToFetchDynamicFees()
                    }, failure: {
                        TLPrompts.promptErrorMessage(TLDisplayStrings.ERROR_STRING(), message: TLDisplayStrings.ERROR_FETCHING_UNSPENT_OUTPUTS_TRY_AGAIN_LATER_STRING())
                })
            } else {
                checkToFetchDynamicFees()
            }
        } else {
            showReviewPaymentViewController(false)
        }
    }
    
    fileprivate func handleTempararyImportPrivateKey(_ privateKey: String) {
        guard let godSend = AppDelegate.instance().coinWalletsManager!.godSend else {
            TLPrompts.promptErrorMessage(TLDisplayStrings.ERROR_STRING(), message: "You need to select an account first.")
            return
        }
        let coinType = godSend.getSelectedObjectCoinType()
        if (!TLCoreBitcoinWrapper.isValidPrivateKey(coinType, privateKey: privateKey, isTestnet: AppDelegate.instance().appWallet.walletConfig.isTestnet)) {
            TLPrompts.promptErrorMessage(TLDisplayStrings.ERROR_STRING(), message: TLDisplayStrings.INVALID_PRIVATE_KEY_STRING())
        } else {
            let importedAddress = godSend as! TLImportedAddress
            let success = importedAddress.setPrivateKeyInMemory(privateKey)
            if (!success) {
                TLPrompts.promptSuccessMessage(TLDisplayStrings.ERROR_STRING(), message: TLDisplayStrings.PRIVATE_KEY_DOES_NOT_MATCH_ADDRESS_STRING())
            } else {
                self.checkTofetchFeeThenFinalPromptReviewTx()
            }
        }
    }
    
    fileprivate func showPromptReviewTx() {
        guard let godSend = AppDelegate.instance().coinWalletsManager!.godSend else {
            TLPrompts.promptErrorMessage(TLDisplayStrings.ERROR_STRING(), message: "You need to select an account first.")
            return
        }

        if godSend.needWatchOnlyAccountPrivateKey() {
            let accountObject = godSend as! TLAccountObject
            TLPrompts.promptForTempararyImportExtendedPrivateKey(self, success: {
                (data: String!) in
                if (!TLHDWalletWrapper.isValidExtendedPrivateKey(data)) {
                    TLPrompts.promptErrorMessage(TLDisplayStrings.ERROR_STRING(), message: TLDisplayStrings.INVALID_ACCOUNT_PRIVATE_KEY_STRING())
                } else {
                    let success = accountObject.setExtendedPrivateKeyInMemory(data)
                    if (!success) {
                        TLPrompts.promptErrorMessage(TLDisplayStrings.ERROR_STRING(), message: TLDisplayStrings.ACCOUNT_PRIVATE_KEY_DOES_NOT_MATCH_STRING())
                    } else {
                        self.checkTofetchFeeThenFinalPromptReviewTx()
                    }
                }
                

                }, error: {
                    (data: String?) in
            })
        } else if godSend.needWatchOnlyAddressPrivateKey() {
            TLPrompts.promptForTempararyImportPrivateKey(self, success: {
                (data: String!) in
                let coinType = godSend.getSelectedObjectCoinType()
                if (TLCoreBitcoinWrapper.isBIP38EncryptedKey(coinType, privateKey: data, isTestnet: AppDelegate.instance().appWallet.walletConfig.isTestnet)) {
                    let coinType = godSend.getSelectedObjectCoinType()
                    TLPrompts.promptForEncryptedPrivKeyPassword(self, view:self.slidingViewController().topViewController.view, coinType:coinType, encryptedPrivKey: data, success: {
                        (privKey: String!) in
                        self.handleTempararyImportPrivateKey(privKey)
                        }, failure: {
                            (isCanceled: Bool) in
                    })
                } else {
                    if AppDelegate.instance().scannedEncryptedPrivateKey == nil {
                        self.handleTempararyImportPrivateKey(data)
                    }
                }
                }, error: {
                    (data: String?) in
            })
            
        } else if godSend.needEncryptedPrivateKeyPassword() {
            let importedAddress = godSend as! TLImportedAddress
            guard let encryptedPrivateKey = importedAddress.getEncryptedPrivateKey() else {
                return
            }
            let coinType = importedAddress.getSelectedObjectCoinType()
            TLPrompts.promptForEncryptedPrivKeyPassword(self, view:self.slidingViewController().topViewController.view, coinType: coinType, encryptedPrivKey: encryptedPrivateKey, success: {
                (privKey: String!) in
                let importedAddress = godSend as! TLImportedAddress
                let success = importedAddress.setPrivateKeyInMemory(privKey)
                if (!success) {
                    TLPrompts.promptSuccessMessage(TLDisplayStrings.ERROR_STRING(), message: TLDisplayStrings.PRIVATE_KEY_DOES_NOT_MATCH_ADDRESS_STRING())
                } else {
                    self.checkTofetchFeeThenFinalPromptReviewTx()
                }
                }, failure: {
                    (isCanceled: Bool) in
            })
        } else {
            self.checkTofetchFeeThenFinalPromptReviewTx()
        }
    }
    
    func dismissTextFieldsAndScrollDown(_ notification: Notification) {
        self.fiatAmountTextField!.resignFirstResponder()
        self.amountTextField!.resignFirstResponder()
        self.toAddressTextField!.resignFirstResponder()
        
        self.topView!.scrollToY(0)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIApplicationDidEnterBackground,
            object: nil)
    }
    
    func onAddressSelected(_ note: Notification) {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: TLNotificationEvents.EVENT_ADDRESS_SELECTED()),
            object: nil)
        
        let address = note.object as! String
        self.toAddressTextField!.text = address
        TLSendFormData.instance().setAddress(address)
    }
    
    func _reviewPaymentClicked() {
        self.showPromptReviewTx()
    }
    
    fileprivate func handleScannedAddress(_ data: String) {
        if (data.hasPrefix("bitcoin:")) {
            let parsedBitcoinURI = TLWalletUtils.parseBitcoinURI(data)
            if parsedBitcoinURI == nil {
                TLPrompts.promptErrorMessage(TLDisplayStrings.ERROR_STRING(), message: TLDisplayStrings.URL_DOES_NOT_CONTAIN_AN_ADDRESS_STRING())
                return
            }
            let address = parsedBitcoinURI!.object(forKey: "address") as! String?
            if (address == nil) {
                TLPrompts.promptErrorMessage(TLDisplayStrings.ERROR_STRING(), message: TLDisplayStrings.URL_DOES_NOT_CONTAIN_AN_ADDRESS_STRING())
                return
            }
            
            let success = self.fillToAddressTextField(address!)
            if (success) {
                let parsedBitcoinURIAmount = parsedBitcoinURI!.object(forKey: "amount") as! String?
                if (parsedBitcoinURIAmount != nil) {
                    guard let godSend = AppDelegate.instance().coinWalletsManager!.godSend else {
                        TLPrompts.promptErrorMessage(TLDisplayStrings.ERROR_STRING(), message: "You need to select an account first.")
                        return
                    }
                    let coinType = godSend.getSelectedObjectCoinType()
                    let coinAmount = TLCurrencyFormat.coinAmountStringToCoin(parsedBitcoinURIAmount!, coinType: coinType, locale: Locale(identifier: "en_US"))
                    let amountString = TLCurrencyFormat.coinToProperBitcoinAmountString(coinAmount, coinType: coinType)
                    self.amountTextField!.text = amountString
                    self.updateFiatAmountTextFieldExchangeRate(nil)
                    TLSendFormData.instance().setAmount(amountString)
                    TLSendFormData.instance().setFiatAmount(nil)
                }
            }
        } else {
            self.fillToAddressTextField(data)
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any!) -> () {
        if (segue.identifier == "selectAccount") {
            if let vc = segue.destination as? TLAccountsViewController {
                vc.navigationItem.title = TLDisplayStrings.SELECT_ACCOUNT_STRING()
                vc.currentCoinType = AppDelegate.instance().coinWalletsManager!.getSendObjectSelectedCoinType()
                vc.parentViewIsSendVC = true
                vc.delegate = self
            }
        } else if (segue.identifier == "selectAccount") {
        }
    }
    
    func preFetchUTXOsAndDynamicFees() {
        guard let godSend = AppDelegate.instance().coinWalletsManager!.godSend else {
            return
        }
        DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.background).async {
            DLog("preFetchUTXOsAndDynamicFees")
            let coinType = godSend.getSelectedObjectCoinType()
            if TLPreferences.enabledInAppSettingsKitDynamicFee(coinType) {
                DLog("preFetchUTXOsAndDynamicFees enabledInAppSettingsKitDynamicFee")
                
                let coinType = godSend.getSelectedObjectCoinType()
                if !AppDelegate.instance().txFeeAPI.haveUpdatedCachedDynamicFees(coinType) {
                    AppDelegate.instance().txFeeAPI.getDynamicTxFee(coinType, success: {
                        (_jsonData) in
                        DLog("preFetchUTXOsAndDynamicFees getDynamicTxFee success")
                        }, failure: {
                            (code, status) in
                            DLog("preFetchUTXOsAndDynamicFees getDynamicTxFee failure")
                    })
                }
                
                if !godSend.haveUpDatedUnspentOutputs() {
                    godSend.getAndSetUnspentOutputs({
                        DLog("preFetchUTXOsAndDynamicFees getAndSetUnspentOutputs success")
                        }, failure: {
                            DLog("preFetchUTXOsAndDynamicFees getAndSetUnspentOutputs failure")
                    })
                }
            }
        }
    }
    
    @IBAction fileprivate func updateFiatAmountTextFieldExchangeRate(_ sender: AnyObject?) {
        guard let godSend = AppDelegate.instance().coinWalletsManager!.godSend else {
            return
        }
        let currency = TLCurrencyFormat.getFiatCurrency()
        let coinType = godSend.getSelectedObjectCoinType()
        let amount = TLCurrencyFormat.properBitcoinAmountStringToCoin(self.amountTextField!.text!, coinType: coinType)

        if (amount.greater(TLCoin.zero())) {
            self.fiatAmountTextField!.text = TLExchangeRate.instance().fiatAmountStringFromBitcoin(currency,
                amount: amount, coinType: coinType)
            TLSendFormData.instance().toAmount = amount
        } else {
            self.fiatAmountTextField!.text = nil
            TLSendFormData.instance().toAmount = nil
        }
    }
    
    @IBAction fileprivate func updateAmountTextFieldExchangeRate(_ sender: AnyObject?) {
        guard let godSend = AppDelegate.instance().coinWalletsManager!.godSend else {
            return
        }
        let currency = TLCurrencyFormat.getFiatCurrency()
        let fiatFormatter = NumberFormatter()
        fiatFormatter.numberStyle = .decimal
        fiatFormatter.maximumFractionDigits = 2
        let fiatAmount = fiatFormatter.number(from: self.fiatAmountTextField!.text!)
        if fiatAmount != nil && fiatAmount! != 0 {
            let coinType = godSend.getSelectedObjectCoinType()
            let bitcoinAmount = TLExchangeRate.instance().bitcoinAmountFromFiat(currency, fiatAmount: fiatAmount!.doubleValue, coinType: coinType)
            self.amountTextField!.text = TLCurrencyFormat.coinToProperBitcoinAmountString(bitcoinAmount, coinType: coinType)
            TLSendFormData.instance().toAmount = bitcoinAmount
        } else {
            self.amountTextField!.text = nil
            TLSendFormData.instance().toAmount = nil
        }
    }
    
    @IBAction fileprivate func reviewPaymentClicked(_ sender: AnyObject) {
        self.dismissKeyboard()
        
        let toAddress = self.toAddressTextField!.text
        if toAddress != nil && TLStealthAddress.isStealthAddress(toAddress!, isTestnet: false) {
            if !TLWalletUtils.ENABLE_STEALTH_ADDRESS() {
                TLPrompts.promptWithOneButton(self, title: "", message: TLDisplayStrings.REUSABLE_ADDRESS_DISABLED(), buttonText: TLDisplayStrings.OK_STRING(), success: {
                })
                return
            }
            func checkToShowStealthPaymentDelayInfo() {
                guard let godSend = AppDelegate.instance().coinWalletsManager!.godSend else {
                    TLPrompts.promptErrorMessage(TLDisplayStrings.ERROR_STRING(), message: "You need to select an account first.")
                    return
                }
                let sendObjectCurrentCoinType = godSend.getSelectedObjectCoinType()
                if TLSuggestions.instance().enabledShowStealthPaymentDelayInfo() && sendObjectCurrentCoinType == TLCoinType.BTC && TLPreferences.getBlockExplorerAPI(sendObjectCurrentCoinType) == .bitcoin_blockchain {
                    let msg = TLDisplayStrings.REUSABLE_ADDRESS_BLOCKCHAIN_API_WARNING_STRING()
                    TLPrompts.promtForOK(self, title:TLDisplayStrings.WARNING_STRING(), message:msg, success: {
                        () in
                        TLSuggestions.instance().setEnableShowStealthPaymentDelayInfo(false)
                    })
                } else {
                    self._reviewPaymentClicked()
                }
            }
            
            if TLSuggestions.instance().enabledShowStealthPaymentNote() {
                let msg = TLDisplayStrings.STEALTH_PAYMENT_NOTE_STRING()
                TLPrompts.promtForOK(self, title:TLDisplayStrings.WARNING_STRING(), message:msg, success: {
                    () in
                    self._reviewPaymentClicked()
                    TLSuggestions.instance().setEnableShowStealthPaymentNote(false)
                    checkToShowStealthPaymentDelayInfo()
                })
            } else {
                checkToShowStealthPaymentDelayInfo();
            }
            
        } else {
            self._reviewPaymentClicked()
        }
    }
    
    @IBAction fileprivate func scanQRCodeClicked(_ sender: AnyObject) {
        AppDelegate.instance().showAddressReaderControllerFromViewController(self, success: {
            (data: String!) in
            self.handleScannedAddress(data)
            }, error: {
                (data: String?) in
        })
    }
    
    @IBAction fileprivate func addressBookClicked(_ sender: AnyObject) {
        NotificationCenter.default.addObserver(self, selector: #selector(TLSendViewController.onAddressSelected(_:)), name: NSNotification.Name(rawValue: TLNotificationEvents.EVENT_ADDRESS_SELECTED()), object: nil)
        let vc = self.storyboard!.instantiateViewController(withIdentifier: "AddressBook") 
        self.slidingViewController().present(vc, animated: true, completion: nil)
    }
    
    @IBAction fileprivate func menuButtonClicked(_ sender: AnyObject) {
        self.slidingViewController().anchorTopViewToRight(animated: true)
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: (NSRange), replacementString string: String) -> Bool {
        let newString = (textField.text as! NSString).replacingCharacters(in: range, with: string)
        if (textField == self.toAddressTextField) {
            TLSendFormData.instance().setAddress(newString)
        } else if (textField == self.amountTextField) {
            TLSendFormData.instance().setAmount(newString)
            TLSendFormData.instance().setFiatAmount(nil)
            TLSendFormData.instance().useAllFunds = false
        } else if (textField == self.fiatAmountTextField) {
            TLSendFormData.instance().setFiatAmount(newString)
            TLSendFormData.instance().setAmount(nil)
            TLSendFormData.instance().useAllFunds = false
        }
        return true
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        
        if (self.tapGesture == nil) {
            self.tapGesture = UITapGestureRecognizer(target: self,
                action: #selector(TLSendViewController.dismissKeyboard))
            
            self.view.addGestureRecognizer(self.tapGesture!)
        }
        
        self.setAllCoinsBarButton()
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        
        textField.resignFirstResponder()
        return true
    }
    
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        NotificationCenter.default.addObserver(self, selector: #selector(TLSendViewController.dismissTextFieldsAndScrollDown(_:)), name: NSNotification.Name.UIApplicationDidEnterBackground, object: nil)
        if TLUtils.isIPhone5() {
            if textField == self.amountTextField || textField == self.fiatAmountTextField {
                self.topView!.scrollToY(-140)
            } else {
                self.topView!.scrollToView(self.fiatAmountTextField!)
            }
        } else if TLUtils.isIPhone4() {
            if textField == self.amountTextField || textField == self.fiatAmountTextField {
                self.topView!.scrollToY(-230)
            } else {
                self.topView!.scrollToView(self.fiatAmountTextField!)
            }
        }
        if textField == self.amountTextField || textField == self.fiatAmountTextField {
            self.preFetchUTXOsAndDynamicFees()
        }
        return true
    }
    
    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        if textField != self.toAddressTextField {
            self.clearRightBarButton()
        }
        textField.resignFirstResponder()
        return true
    }
    
    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        if (textField == self.toAddressTextField) {
            TLSendFormData.instance().setAddress(nil)
        }
        
        return true
    }
    
    func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        if (item.tag == 1) {
            self.showReceiveView()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

extension TLSendViewController {
    func updateViewForEnabledCryptoCoinsIfChanged() {
        guard let godSend = AppDelegate.instance().coinWalletsManager!.godSend else {
            self.updateViewToNoneSelectedObject()
            return
        }
        let sendObjectCurrentCoinType = godSend.getSelectedObjectCoinType()
        if !TLPreferences.isCryptoCoinEnabled(sendObjectCurrentCoinType) {
            AppDelegate.instance().coinWalletsManager!.updateSelectedObjectsToEnabledCoin(TLSelectAccountObjectType.send)
            self.updateViewToNewSelectedObject()
        }
    }
}

extension TLSendViewController : TLAccountsViewControllerDelegate {
    func didSelectAccount(_ coinType: TLCoinType, sendFromType: TLSendFromType, sendFromIndex: NSInteger) {
        AppDelegate.instance().coinWalletsManager!.updateGodSend(coinType, sendFromType: sendFromType, sendFromIndex: Int(sendFromIndex))
        self.updateViewToNewSelectedObject()
    }
}
