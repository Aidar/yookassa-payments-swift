@_implementationOnly import MoneyAuth
import PassKit
import SPaySdk
import YooKassaPaymentsApi

final class PaymentMethodsPresenter: NSObject {

    private enum App2AppState {
        case idle
        case yoomoney
    }

    private enum Sberpay {
        case spay
        case sms
    }

    // MARK: - VIPER

    var interactor: PaymentMethodsInteractorInput!
    var router: PaymentMethodsRouterInput!
    weak var view: PaymentMethodsViewInput?
    weak var tokenizationModuleOutput: TokenizationModuleOutput?

    weak var bankCardModuleInput: BankCardModuleInput?
    weak var linkedCardModuleInput: LinkedCardModuleInput?
    weak var sbpModuleInput: SbpModuleInput?
    weak var sberpayModuleInput: SberpayModuleInput?

    // MARK: - Init data

    private let isLogoVisible: Bool
    private let paymentMethodViewModelFactory: PaymentMethodViewModelFactory
    private let priceViewModelFactory: PriceViewModelFactory

    private let applicationScheme: String?
    private let clientApplicationKey: String
    private let testModeSettings: TestModeSettings?
    private let isLoggingEnabled: Bool
    private let moneyAuthClientId: String?
    private let tokenizationSettings: TokenizationSettings

    private let moneyAuthConfig: MoneyAuth.Config
    private let moneyAuthCustomization: MoneyAuth.Customization

    private let shopName: String
    private let shopId: String
    private let purchaseDescription: String
    private let returnUrl: String
    private let savePaymentMethod: SavePaymentMethod
    private let userPhoneNumber: String?
    private let cardScanning: CardScanning?
    private let customerId: String?
    private let config: Config
    private var scheme: String?

    // MARK: - Init

    init(
        isLogoVisible: Bool,
        paymentMethodViewModelFactory: PaymentMethodViewModelFactory,
        applicationScheme: String?,
        priceViewModelFactory: PriceViewModelFactory,
        clientApplicationKey: String,
        testModeSettings: TestModeSettings?,
        isLoggingEnabled: Bool,
        moneyAuthClientId: String?,
        tokenizationSettings: TokenizationSettings,
        moneyAuthConfig: MoneyAuth.Config,
        moneyAuthCustomization: MoneyAuth.Customization,
        shopName: String,
        shopId: String,
        purchaseDescription: String,
        returnUrl: String?,
        savePaymentMethod: SavePaymentMethod,
        userPhoneNumber: String?,
        cardScanning: CardScanning?,
        customerId: String?,
        config: Config
    ) {
        self.isLogoVisible = isLogoVisible
        self.paymentMethodViewModelFactory = paymentMethodViewModelFactory
        self.priceViewModelFactory = priceViewModelFactory

        self.applicationScheme = applicationScheme
        self.clientApplicationKey = clientApplicationKey
        self.testModeSettings = testModeSettings
        self.isLoggingEnabled = isLoggingEnabled
        self.moneyAuthClientId = moneyAuthClientId
        self.tokenizationSettings = tokenizationSettings

        self.moneyAuthConfig = moneyAuthConfig
        self.moneyAuthCustomization = moneyAuthCustomization

        self.shopName = shopName
        self.shopId = shopId
        self.purchaseDescription = purchaseDescription
        self.returnUrl = returnUrl ?? GlobalConstants.returnUrl
        self.savePaymentMethod = savePaymentMethod
        self.userPhoneNumber = userPhoneNumber
        self.cardScanning = cardScanning
        self.customerId = customerId
        self.config = config
    }

    // MARK: - Stored properties

    private var moneyAuthCoordinator: MoneyAuth.AuthorizationCoordinator?

    private var shop: Shop?
    private var viewModel: (models: [PaymentMethodViewModel], indexMap: ([Int: Int])) = ([], [:])

    private lazy var termsOfService: NSAttributedString = {
        let html = ServiceTermsFactory.makeTermsOfService(properties: shop?.properties)
        return HTMLUtils.highlightHyperlinks(html: html)
    }()

    private var shouldReloadOnViewDidAppear = false
    private var moneyCenterAuthToken: String?
    private var app2AppState: App2AppState = .idle

    private var unbindCompletion: ((Bool) -> Void)?

    private var isInitializedSberSdk: Bool = false
}

// MARK: - PaymentMethodsViewOutput

extension PaymentMethodsPresenter: PaymentMethodsViewOutput {
    func setupView() {
        guard let view = view else { return }
        view.showActivity()
        let logo = paymentMethodViewModelFactory.yooLogoImage()
        view.setLogoVisible(image: logo, isVisible: isLogoVisible)

        DispatchQueue.global().async { [weak self] in
            self?.interactor.fetchShop()
        }
    }

    func viewDidAppear() {
        guard shouldReloadOnViewDidAppear else { return }
        shouldReloadOnViewDidAppear = false
        DispatchQueue.global().async { [weak self] in
            guard let interactor = self?.interactor else { return }
            interactor.fetchShop()
        }
    }

    func applicationDidBecomeActive() {
        if app2AppState == .idle,
           shop?.options.count == 1,
           shop?.options.first?.paymentMethodType == .yooMoney {
            didFinish(module: self, error: nil)
        }
    }

    func numberOfRows() -> Int {
        viewModel.models.count
    }

    func viewModelForRow(
        at indexPath: IndexPath
    ) -> PaymentMethodViewModel? {
        guard viewModel.models.indices.contains(indexPath.row) else {
            assertionFailure("ViewModel at index \(indexPath.row) should be")
            return nil
        }

        return viewModel.models[indexPath.row]
    }

    func didSelect(at indexPath: IndexPath) {
        guard
            let shop = shop,
            let optionIndex = viewModel.indexMap[indexPath.row]
        else {
            return assertionFailure("ViewModel at index \(indexPath.row) should be")
        }

        let method = shop.options[optionIndex]
        if
            viewModel.models[indexPath.row].isShopLinkedCard,
            let cardOption = method as? PaymentOptionBankCard
        {
            guard
                let id = viewModel.models[indexPath.row].id,
                let card = cardOption.paymentInstruments?.first(where: { $0.paymentInstrumentId == id })
            else { return assertionFailure("Couldn't match cardInstrument for indexPath: \(indexPath)") }

            openBankCardModule(
                paymentOption: method,
                instrument: card,
                isSafeDeal: shop.isSafeDeal,
                needReplace: false
            )
        } else {
            openPaymentMethod(method, isSafeDeal: shop.isSafeDeal, needReplace: false)
        }
    }

    func didPressSettings(at indexPath: IndexPath) {
        guard
            let optionIndex = viewModel.indexMap[indexPath.row],
            let method = shop?.options[optionIndex]
        else {
            assertionFailure("ViewModel at index \(indexPath.row) should be")
            return
        }

        let filtered = viewModel.indexMap.filter { $0.value == optionIndex }.values.sorted()

        switch method {
        case let cardOption as PaymentOptionBankCard:
            guard
                let instrumentIndex = filtered.firstIndex(of: optionIndex),
                let card = cardOption.paymentInstruments?[instrumentIndex]
            else { return assertionFailure("Couldn't match cardInstrument for indexPath: \(indexPath)") }

            router?.openCardSettingsModule(
                data: CardSettingsModuleInputData(
                    cardLogo: viewModel.models[indexPath.row].image,
                    cardMask: (card.first6 ?? "") + "••••••" + card.last4,
                    infoText: CommonLocalized.CardSettingsDetails.autopaymentPersists,
                    card: .card(name: viewModel.models[indexPath.row].title, id: card.paymentInstrumentId),
                    testModeSettings: testModeSettings,
                    tokenizationSettings: tokenizationSettings,
                    isLoggingEnabled: isLoggingEnabled,
                    clientId: clientApplicationKey,
                    config: config
                ),
                output: self
            )
        case let option as PaymentInstrumentYooMoneyLinkedBankCard:
            router?.openCardSettingsModule(
                data: CardSettingsModuleInputData(
                    cardLogo: viewModel.models[indexPath.row].image,
                    cardMask: option.cardMask,
                    infoText: CommonLocalized.CardSettingsDetails.yoocardUnbindDetails,
                    card: .yoomoney(name: viewModel.models[indexPath.row].title),
                    testModeSettings: testModeSettings,
                    tokenizationSettings: tokenizationSettings,
                    isLoggingEnabled: isLoggingEnabled,
                    clientId: clientApplicationKey,
                    config: config
                ),
                output: self
            )
        default:
            assertionFailure("Only card and yoocard are supported \(indexPath.row)")
        }
    }

    private func openPaymentMethod(
        _ paymentOption: PaymentOption,
        isSafeDeal: Bool,
        needReplace: Bool
    ) {
        switch paymentOption {
        case let paymentOption as PaymentInstrumentYooMoneyLinkedBankCard:
            openLinkedCard(paymentOption: paymentOption, isSafeDeal: isSafeDeal, needReplace: needReplace)

        case let paymentOption as PaymentInstrumentYooMoneyWallet:
            openYooMoneyWallet(paymentOption: paymentOption, isSafeDeal: isSafeDeal, needReplace: needReplace)

        case let paymentOption where paymentOption.paymentMethodType == .yooMoney:
            openYooMoneyAuthorization()

        case let paymentOption where paymentOption.paymentMethodType == .sberbank:
            switch shouldOpenSberpay(paymentOption) {
            case .spay:
                openSberpayModule(
                    paymentOption: paymentOption,
                    clientSavePaymentMethod: savePaymentMethod,
                    isSafeDeal: isSafeDeal,
                    needReplace: needReplace
                )
            case .sms:
                openSberbankModule(
                    paymentOption: paymentOption,
                    isSafeDeal: isSafeDeal,
                    needReplace: needReplace
                )
            }

        case let paymentOption where paymentOption.paymentMethodType == .bankCard:
            openBankCardModule(paymentOption: paymentOption, isSafeDeal: isSafeDeal, needReplace: needReplace)

        case let paymentOption where paymentOption.paymentMethodType == .sbp:
            openSbpModule(paymentOption: paymentOption, isSafeDeal: isSafeDeal, needReplace: needReplace)

        default:
            break
        }
    }

    private func handleOpenPaymentMethodInstrument(
        _ instrument: PaymentInstrumentBankCard
    ) {
        // TODO: Handle instrument payment MOC-2060
        print("\(#function) in \(self)")
    }

    private func openYooMoneyAuthorization() {
        if testModeSettings != nil {
            view?.showActivity()
            DispatchQueue.global().async {
                self.interactor.fetchYooMoneyPaymentMethods(
                    moneyCenterAuthToken: "MOCK_TOKEN"
                )
            }
        } else {
            if shouldOpenYooMoneyApp2App() {
                openYooMoneyApp2App()
            } else {
                openMoneyAuth()
            }
        }
    }

    private func openMoneyAuth() {
        do {
            moneyAuthCoordinator = try router.presentYooMoneyAuthorizationModule(
                config: moneyAuthConfig,
                customization: moneyAuthCustomization,
                output: self
            )
            interactor.track(event: .userStartAuthorization)
        } catch {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.view?.showActivity()
                DispatchQueue.global().async { [weak self] in
                    self?.interactor.fetchShop()
                }
            }
            interactor.track(event: .userCancelAuthorization)
        }
    }

    private func openYooMoneyWallet(
        paymentOption: PaymentInstrumentYooMoneyWallet,
        isSafeDeal: Bool,
        needReplace: Bool
    ) {
        let walletDisplayName = interactor.getWalletDisplayName()
        let paymentMethod = paymentMethodViewModelFactory.makePaymentMethodViewModel(
            paymentOption: paymentOption,
            walletDisplayName: walletDisplayName
        )
        let initialSavePaymentMethod = makeInitialSavePaymentMethod(savePaymentMethod)
        let savePaymentMethodViewModel = SavePaymentMethodViewModelFactory.makeSavePaymentMethodViewModel(
            paymentOption,
            savePaymentMethod,
            initialState: initialSavePaymentMethod
        )
        let priceViewModel = priceViewModelFactory.makeAmountPriceViewModel(paymentOption)
        let feeViewModel = priceViewModelFactory.makeFeePriceViewModel(paymentOption)
        let inputData = YooMoneyModuleInputData(
            clientApplicationKey: clientApplicationKey,
            testModeSettings: testModeSettings,
            isLoggingEnabled: isLoggingEnabled,
            moneyAuthClientId: moneyAuthClientId,
            tokenizationSettings: tokenizationSettings,
            shopName: shopName,
            purchaseDescription: purchaseDescription,
            price: priceViewModel,
            fee: feeViewModel,
            paymentMethod: paymentMethod,
            paymentOption: paymentOption,
            termsOfService: termsOfService,
            returnUrl: returnUrl,
            savePaymentMethodViewModel: savePaymentMethodViewModel,
            initialSavePaymentMethod: initialSavePaymentMethod,
            isBackBarButtonHidden: needReplace,
            customerId: customerId,
            isSafeDeal: isSafeDeal,
            paymentOptionTitle: config.paymentMethods.first { $0.kind == .yoomoney }?.title
        )
        router?.presentYooMoney(
            inputData: inputData,
            moduleOutput: self
        )
    }

    private func openLinkedCard(
        paymentOption: PaymentInstrumentYooMoneyLinkedBankCard,
        isSafeDeal: Bool,
        needReplace: Bool
    ) {
        let initialSavePaymentMethod = makeInitialSavePaymentMethod(savePaymentMethod)
        let priceViewModel = priceViewModelFactory.makeAmountPriceViewModel(paymentOption)
        let feeViewModel = priceViewModelFactory.makeFeePriceViewModel(paymentOption)
        let inputData = LinkedCardModuleInputData(
            clientApplicationKey: clientApplicationKey,
            testModeSettings: testModeSettings,
            isLoggingEnabled: isLoggingEnabled,
            moneyAuthClientId: moneyAuthClientId,
            tokenizationSettings: tokenizationSettings,
            shopName: shopName,
            purchaseDescription: purchaseDescription,
            price: priceViewModel,
            fee: feeViewModel,
            paymentOption: paymentOption,
            termsOfService: termsOfService,
            returnUrl: returnUrl,
            initialSavePaymentMethod: initialSavePaymentMethod,
            isBackBarButtonHidden: needReplace,
            customerId: customerId,
            isSafeDeal: isSafeDeal
        )
        router?.presentLinkedCard(
            inputData: inputData,
            moduleOutput: self
        )
    }

    private func openSbpModule(
        paymentOption: PaymentOption,
        isSafeDeal: Bool,
        needReplace: Bool
    ) {
        let priceViewModel = priceViewModelFactory.makeAmountPriceViewModel(paymentOption)
        let feeViewModel = priceViewModelFactory.makeFeePriceViewModel(paymentOption)
        let inputData = SbpModuleInputData(
            applicationScheme: applicationScheme,
            paymentOption: paymentOption,
            clientApplicationKey: clientApplicationKey,
            customerId: customerId,
            isLoggingEnabled: isLoggingEnabled,
            testModeSettings: testModeSettings,
            tokenizationSettings: tokenizationSettings,
            shopName: shopName,
            isSafeDeal: isSafeDeal,
            purchaseDescription: purchaseDescription,
            priceViewModel: priceViewModel,
            feeViewModel: feeViewModel,
            termsOfService: termsOfService,
            isBackBarButtonHidden: needReplace,
            clientSavePaymentMethod: savePaymentMethod,
            config: config
        )

        router.openSbpModule(inputData: inputData, moduleOutput: self)
    }

    private func openSberbankModule(
        paymentOption: PaymentOption,
        isSafeDeal: Bool,
        needReplace: Bool
    ) {
        let priceViewModel = priceViewModelFactory.makeAmountPriceViewModel(paymentOption)
        let feeViewModel = priceViewModelFactory.makeFeePriceViewModel(paymentOption)
        let inputData = SberbankModuleInputData(
            paymentOption: paymentOption,
            clientApplicationKey: clientApplicationKey,
            tokenizationSettings: tokenizationSettings,
            testModeSettings: testModeSettings,
            isLoggingEnabled: isLoggingEnabled,
            shopName: shopName,
            purchaseDescription: purchaseDescription,
            priceViewModel: priceViewModel,
            feeViewModel: feeViewModel,
            termsOfService: termsOfService,
            userPhoneNumber: userPhoneNumber,
            isBackBarButtonHidden: needReplace,
            customerId: customerId,
            isSafeDeal: isSafeDeal,
            clientSavePaymentMethod: savePaymentMethod,
            config: config
        )
        router.openSberbankModule(
            inputData: inputData,
            moduleOutput: self
        )
    }

    private func openSberpayModule(
        paymentOption: PaymentOption,
        clientSavePaymentMethod: SavePaymentMethod,
        isSafeDeal: Bool,
        needReplace: Bool
    ) {
        let priceViewModel = priceViewModelFactory.makeAmountPriceViewModel(paymentOption)
        let feeViewModel = priceViewModelFactory.makeFeePriceViewModel(paymentOption)
        let inputData = SberpayModuleInputData(
            applicationScheme: applicationScheme,
            paymentOption: paymentOption,
            clientSavePaymentMethod: clientSavePaymentMethod,
            clientApplicationKey: clientApplicationKey,
            tokenizationSettings: tokenizationSettings,
            testModeSettings: testModeSettings,
            isLoggingEnabled: isLoggingEnabled,
            shopName: shopName,
            shopId: shopId,
            purchaseDescription: purchaseDescription,
            priceViewModel: priceViewModel,
            feeViewModel: feeViewModel,
            termsOfService: termsOfService,
            isBackBarButtonHidden: needReplace,
            customerId: customerId,
            isSafeDeal: isSafeDeal,
            config: config
        )
        router.openSberpayModule(
            inputData: inputData,
            moduleOutput: self
        )
    }

    private func openBankCardModule(
        paymentOption: PaymentOption,
        instrument: PaymentInstrumentBankCard? = nil,
        isSafeDeal: Bool,
        needReplace: Bool
    ) {
        let priceViewModel = priceViewModelFactory.makeAmountPriceViewModel(paymentOption)
        let feeViewModel = priceViewModelFactory.makeFeePriceViewModel(paymentOption)

        if let instrument = instrument, !isSafeDeal {
            let hasService = paymentOption.fee?.service.map { $0.charge.value > 0.00 } ?? false
            let hasCounterparty = paymentOption.fee?.counterparty.map { $0.charge.value > 0.00 } ?? false
            let hasFee = hasService || hasCounterparty

            if savePaymentMethod == .off, !hasFee, !instrument.cscRequired {
                DispatchQueue.main.async {
                    self.view?.showActivity()
                }

                DispatchQueue.global().async {
                    self.interactor.tokenizeInstrument(
                        instrument: instrument,
                        savePaymentMethod: false,
                        returnUrl: self.returnUrl,
                        amount: paymentOption.charge.plain
                    )
                }
                return
            }
        }

        let inputData = BankCardModuleInputData(
            clientApplicationKey: clientApplicationKey,
            testModeSettings: testModeSettings,
            isLoggingEnabled: isLoggingEnabled,
            tokenizationSettings: tokenizationSettings,
            shopName: shopName,
            purchaseDescription: purchaseDescription,
            priceViewModel: priceViewModel,
            feeViewModel: feeViewModel,
            paymentOption: paymentOption,
            termsOfService: termsOfService,
            cardScanning: cardScanning,
            returnUrl: returnUrl,
            savePaymentMethod: savePaymentMethod,
            canSaveInstrument: paymentOption.savePaymentInstrument ?? false,
            apiSavePaymentMethod: paymentOption.savePaymentMethod,
            isBackBarButtonHidden: needReplace,
            customerId: customerId,
            instrument: instrument,
            isSafeDeal: isSafeDeal,
            config: config
        )
        router.openBankCardModule(
            inputData: inputData,
            moduleOutput: self
        )
    }

    private func shouldOpenSberpay(
        _ paymentOption: PaymentOption
    ) -> Sberpay {
        guard let confirmationTypes = paymentOption.confirmationTypes,
              confirmationTypes.contains(.mobileApplication)
        else { return .sms }

        var shouldOpen: Sberpay = .sms

        if SPay.isReadyForSPay {
            shouldOpen = .spay
        }

        return shouldOpen
    }

    private func shouldOpenYooMoneyApp2App() -> Bool {
        guard let url = URL(string: Constants.YooMoneyApp2App.scheme) else {
            return false
        }

        return UIApplication.shared.canOpenURL(url)
    }

    private func openYooMoneyApp2App() {
        guard let clientId = moneyAuthClientId,
              let redirectUri = makeYooMoneyExchangeRedirectUri() else {
            return
        }

        let scope = makeYooMoneyApp2AppScope()
        let fullPathUrl = Constants.YooMoneyApp2App.scheme
        + "\(Constants.YooMoneyApp2App.host)/"
        + "\(Constants.YooMoneyApp2App.firstPath)?"
        + "\(Constants.YooMoneyApp2App.clientId)=\(clientId)&"
        + "\(Constants.YooMoneyApp2App.scope)=\(scope)&"
        + "\(Constants.YooMoneyApp2App.redirectUri)=\(redirectUri)"

        guard let url = URL(string: fullPathUrl) else {
            return
        }

        DispatchQueue.main.async {
            UIApplication.shared.open(
                url,
                options: [:],
                completionHandler: nil
            )
        }
    }

    private func makeYooMoneyExchangeRedirectUri() -> String? {
        guard let applicationScheme = applicationScheme else {
            assertionFailure("Application scheme should be")
            return nil
        }

        return applicationScheme
        + DeepLinkFactory.YooMoney.host
        + "/"
        + DeepLinkFactory.YooMoney.Exchange.firstPath
        + "?"
        + DeepLinkFactory.YooMoney.Exchange.cryptogram
        + "="
    }

    private func makeYooMoneyApp2AppScope() -> String {
        return [
            Constants.YooMoneyApp2App.Scope.accountInfo,
            Constants.YooMoneyApp2App.Scope.balance,
        ].joined(separator: ",")
    }
}

// MARK: - ActionTitleTextDialogDelegate

extension PaymentMethodsPresenter: ActionTitleTextDialogDelegate {
    func didPressButton(
        in actionTitleTextDialog: ActionTitleTextDialog
    ) {
        guard let view = view else { return }
        view.hidePlaceholder()
        view.showActivity()

        DispatchQueue.global().async { [weak self] in
            guard let self = self else { return }
            self.interactor.fetchShop()
        }
    }
}

// MARK: - PaymentMethodsModuleInput

extension PaymentMethodsPresenter: PaymentMethodsModuleInput {
    func authorizeInYooMoney(
        with cryptogram: String
    ) {
        guard !cryptogram.isEmpty else {
            return
        }
        app2AppState = .yoomoney

        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  let view = self.view else { return }
            view.showActivity()

            DispatchQueue.global().async { [weak self] in
                guard let self = self else { return }
                self.interactor.decryptCryptogram(cryptogram)
            }
        }
    }

    func didFinish(
        on module: TokenizationModuleInput,
        with error: YooKassaPaymentsError?
    ) {
        didFinish(module: module, error: error)
    }
}

// MARK: - PaymentMethodsInteractorOutput

extension PaymentMethodsPresenter: PaymentMethodsInteractorOutput {
    func didUnbindCard(id: String) {
        interactor.fetchShop()
        DispatchQueue.main.async {
            self.unbindCompletion?(true)
            self.unbindCompletion = nil
        }
    }

    func didFailUnbindCard(id: String, error: Error) {
        DispatchQueue.main.async {
            self.view?.hideActivity()
            self.view?.presentError(with: Localized.Error.unbindCardFailed)
            self.unbindCompletion?(false)
            self.unbindCompletion = nil
        }
    }

    func didFetchShop(_ shop: Shop) {
        interactor.track(event: .screenPaymentOptions(currentAuthType: interactor.analyticsAuthType()))

        if shop.isSupportSberbankOption {
            SPay.setup()
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self, let view = self.view else { return }

            self.shop = shop

            func showOptions() {
                let walletDisplayName = self.interactor.getWalletDisplayName()
                self.viewModel = self.paymentMethodViewModelFactory.makePaymentMethodViewModels(
                    shop.options,
                    walletDisplayName: walletDisplayName
                )
                view.hideActivity()
                view.reloadData()
            }

            if shop.options.count == 1, let first = shop.options.first {
                switch first {
                case let paymentMethod as PaymentOptionBankCard:
                    if (paymentMethod.paymentInstruments?.count ?? 0) > 0 {
                        showOptions()
                    } else {
                        self.openPaymentMethod(
                            paymentMethod,
                            isSafeDeal: shop.isSafeDeal,
                            needReplace: true
                        )
                    }
                default:
                    self.openPaymentMethod(first, isSafeDeal: shop.isSafeDeal, needReplace: true)
                }
            } else {
                showOptions()
            }
        }
    }

    func didFailFetchShop(_ error: Error) {
        presentError(error, savePaymentMethod: nil)
    }

    func didFetchYooMoneyPaymentMethods(_ paymentMethods: [PaymentOption], shopProperties: ShopProperties) {
        let condition: (PaymentOption) -> Bool = { $0 is PaymentInstrumentYooMoneyWallet }

        if let paymentOption = paymentMethods.first as? PaymentInstrumentYooMoneyWallet, paymentMethods.count == 1 {
            let needReplace = self.shop?.options.count == 1
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.openYooMoneyWallet(
                    paymentOption: paymentOption,
                    isSafeDeal: shopProperties.isSafeDeal || shopProperties.isMarketplace,
                    needReplace: needReplace
                )
                self.shouldReloadOnViewDidAppear = true
            }
        } else if paymentMethods.contains(where: condition) == false {
            interactor.track(event: .actionAuthWithoutWallet)
            interactor.fetchShop()
            DispatchQueue.main.async { [weak self] in
                guard let view = self?.view else { return }
                view.presentError(with: Localized.Error.noWalletTitle)
            }
        } else {
            interactor.fetchShop()
        }
    }

    func didFetchYooMoneyPaymentMethods(_ error: Error) {
        presentError(error, savePaymentMethod: nil)
    }

    func didFetchAccount(_ account: UserAccount) {
        guard let moneyCenterAuthToken = moneyCenterAuthToken else {
            return
        }
        interactor.setAccount(account)
        interactor.fetchYooMoneyPaymentMethods(moneyCenterAuthToken: moneyCenterAuthToken)
    }

    func didFailFetchAccount(_ error: Error) {
        guard let moneyCenterAuthToken = moneyCenterAuthToken else {
            return
        }
        interactor.fetchYooMoneyPaymentMethods(
            moneyCenterAuthToken: moneyCenterAuthToken
        )
    }

    func didDecryptCryptogram(_ token: String) {
        moneyCenterAuthToken = token
        DispatchQueue.global().async { [weak self] in
            guard let self = self else { return }
            self.interactor.track(event: .actionMoneyAuthLogin(scheme: .yoomoneyApp, status: .success))
            self.interactor.fetchAccount(oauthToken: token)
        }
    }

    func didFailDecryptCryptogram(_ error: Error) {
        interactor.track(event: .actionMoneyAuthLogin(scheme: .yoomoneyApp, status: .fail(error)))
        DispatchQueue.main.async { [weak self] in
            guard let view = self?.view else { return }
            view.hideActivity()
            view.presentError(with: CommonLocalized.Error.unknown)
        }
    }

    private func presentError(_ error: Error, savePaymentMethod: Bool?) {
        let message: String

        switch error {
        case let error as PresentableError:
            message = error.message
        default:
            message = CommonLocalized.Error.unknown
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self, let view = self.view else { return }
            view.hideActivity()
            view.showPlaceholder(message: message)

            self.trackScreenErrorAnalytics(scheme: nil, savePaymentMethod: savePaymentMethod)
        }
    }

    private func trackScreenErrorAnalytics(
        scheme: AnalyticsEvent.TokenizeScheme?,
        savePaymentMethod: Bool?
    ) {
        DispatchQueue.global().async { [weak self] in
            guard let interactor = self?.interactor else { return }
            interactor.track(event:
                    .screenError(
                        scheme: scheme,
                        currentAuthType: interactor.analyticsAuthType()
                    )
            )
        }
    }

    private func trackScreenPaymentAnalytics(
        scheme: AnalyticsEvent.TokenizeScheme,
        savePaymentMethod: Bool?
    ) {
        DispatchQueue.global().async { [weak self] in
            guard let interactor = self?.interactor else { return }
            interactor.track(event:
                    .screenPaymentContract(
                        scheme: scheme,
                        currentAuthType: interactor.analyticsAuthType()
                    )
            )
        }
    }

    func didTokenizeInstrument(instrument: PaymentInstrumentBankCard, tokens: Tokens) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.view?.hideActivity()

            let scheme: AnalyticsEvent.TokenizeScheme = instrument.cscRequired
            ? .customerIdLinkedCardCvc
            : .customerIdLinkedCard

            self.didTokenize(tokens: tokens, paymentMethodType: .bankCard, scheme: scheme)

            DispatchQueue.global().async { [weak self] in
                guard let self = self else { return }
                self.interactor.track(event:
                        .actionTokenize(
                            scheme: scheme,
                            currentAuthType: self.interactor.analyticsAuthType())
                )
            }
        }
    }

    func didFailTokenizeInstrument(error: Error) {
        interactor.track(
            event: .screenError(
                scheme: .bankCard,
                currentAuthType: interactor.analyticsAuthType()
            )
        )

        let message: String
        switch error {
        case let error as PresentableError:
            message = error.message
        default:
            message = CommonLocalized.Error.unknown
        }

        DispatchQueue.main.async { [weak self] in
            guard let view = self?.view else { return }
            view.hideActivity()
            view.presentError(with: message)
        }
    }
}

// MARK: - ProcessCoordinatorDelegate

extension PaymentMethodsPresenter: AuthorizationCoordinatorDelegate {
    func authorizationCoordinatorDidRequestSupport(_ coordinator: MoneyAuth.AuthorizationCoordinator) {}


    func authorizationCoordinatorDidCancel(_ coordinator: AuthorizationCoordinator) {
        self.moneyAuthCoordinator = nil
        interactor.track(event: .userCancelAuthorization)

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.router.shouldDismissAuthorizationModule() {
                self.router.closeAuthorizationModule()
            }
            if self.shop?.options.count == 1 {
                self.didFinish(module: self, error: nil)
            }
        }
    }

    func authorizationCoordinator(_ coordinator: AuthorizationCoordinator, didFailureWith error: Error) {
        self.moneyAuthCoordinator = nil
        interactor.track(event: .actionMoneyAuthLogin(scheme: .moneyAuthSdk, status: .fail(error)))

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.router.closeAuthorizationModule()
            self.view?.showActivity()
            DispatchQueue.global().async { [weak self] in
                self?.interactor.fetchShop()
            }
        }
    }

    func authorizationCoordinatorDidPrepareProcess(_ coordinator: AuthorizationCoordinator) {}

    func authorizationCoordinator(
        _ coordinator: AuthorizationCoordinator,
        didFailPrepareProcessWithError error: Error
    ) {}

    func authorizationCoordinatorDidRecoverPassword(_ coordinator: AuthorizationCoordinator) {}

    func authorizationCoordinator(
        _ coordinator: AuthorizationCoordinator,
        didAcquireAuthorizationToken token: String,
        account: UserAccount?,
        authorizationProcess: AuthorizationProcess?,
        profiledSessionId: String?,
        phoneOffersAccepted: Bool,
        emailOffersAccepted: Bool,
        userAgreementAccepted: Bool,
        bindSocialAccountResult: BindSocialAccountResult?
    ) {
        self.moneyAuthCoordinator = nil

        DispatchQueue.main.async { [weak self] in
            guard
                let self = self,
                let view = self.view
            else { return }
            self.router.closeAuthorizationModule()
            view.showActivity()

            DispatchQueue.global().async { [weak self] in
                guard let self = self else { return }
                account.map(self.interactor.setAccount)
                self.interactor.fetchYooMoneyPaymentMethods(
                    moneyCenterAuthToken: token
                )

                self.interactor.track(event: .actionMoneyAuthLogin(scheme: .moneyAuthSdk, status: .success))
            }
        }
    }

    func authorizationCoordinator(
        _ coordinator: AuthorizationCoordinator,
        requestSberAuthForClient id: String,
        nonce: String,
        scope: String,
        state: String,
        completion: @escaping (Bool) -> Void
    ) {
        completion(false)
    }

    func authorizationCoordinator(
        _ coordinator: AuthorizationCoordinator,
        requestVkAuthForClient id: String,
        state: String
    ) { }
}

// MARK: - YooMoneyModuleOutput

extension PaymentMethodsPresenter: YooMoneyModuleOutput {
    func didLogout(
        _ module: YooMoneyModuleInput
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.moneyCenterAuthToken = nil
            self.app2AppState = .idle
            let condition: (PaymentOption) -> Bool = {
                return $0 is PaymentInstrumentYooMoneyLinkedBankCard
                || $0 is PaymentInstrumentYooMoneyWallet
                || $0.paymentMethodType == .yooMoney
            }
            if let paymentMethods = self.shop?.options,
               paymentMethods.allSatisfy(condition) {
                self.didFinish(module: self, error: nil)
            } else {
                self.shouldReloadOnViewDidAppear = false
                self.router.closeYooMoneyModule()
                self.view?.showActivity()
                DispatchQueue.global().async { [weak self] in
                    self?.interactor.fetchShop()
                }
            }
        }
    }

    func tokenizationModule(
        _ module: YooMoneyModuleInput,
        didTokenize token: Tokens,
        paymentMethodType: PaymentMethodType
    ) {
        didTokenize(
            tokens: token,
            paymentMethodType: paymentMethodType,
            scheme: .wallet
        )
    }
}

// MARK: - LinkedCardModuleOutput

extension PaymentMethodsPresenter: LinkedCardModuleOutput {
    func tokenizationModule(
        _ module: LinkedCardModuleInput,
        didTokenize token: Tokens,
        paymentMethodType: PaymentMethodType
    ) {
        linkedCardModuleInput = module
        didTokenize(
            tokens: token,
            paymentMethodType: paymentMethodType,
            scheme: .linkedCard
        )
    }
}

// MARK: - SberbankModuleOutput

extension PaymentMethodsPresenter: SberbankModuleOutput {
    func sberbankModule(
        _ module: SberbankModuleInput,
        didTokenize token: Tokens,
        paymentMethodType: PaymentMethodType
    ) {
        didTokenize(
            tokens: token,
            paymentMethodType: paymentMethodType,
            scheme: .smsSbol
        )
    }
}

// MARK: - SberpayModuleOutput

extension PaymentMethodsPresenter: SberpayModuleOutput {

    func didFinish(_ module: any SberpayModuleInput, with error: any Error) {
        tokenizationModuleOutput?.didFinish(on: self, with: .paymentConfirmation(error))
    }

    func sberpayModule(
        _ module: SberpayModuleInput,
        didFinishConfirmation paymentMethodType: PaymentMethodType
    ) {
        tokenizationModuleOutput?.didFinishConfirmation(paymentMethodType: paymentMethodType)
    }

    func sberpayModule(
        _ module: SberpayModuleInput,
        didTokenize token: Tokens,
        paymentMethodType: PaymentMethodType
    ) {
        sberpayModuleInput = module
        didTokenize(
            tokens: token,
            paymentMethodType: paymentMethodType,
            scheme: .sberpay
        )
    }
}

// MARK: - BankCardModuleOutput

extension PaymentMethodsPresenter: BankCardModuleOutput {
    func bankCardModule(
        _ module: BankCardModuleInput,
        didTokenize token: Tokens,
        paymentMethodType: PaymentMethodType
    ) {
        bankCardModuleInput = module
        didTokenize(
            tokens: token,
            paymentMethodType: paymentMethodType,
            scheme: .bankCard
        )
    }
}

// MARK: - SbpModuleOutput

extension PaymentMethodsPresenter: SbpModuleOutput {

    func didFinish(_ module: any SbpModuleInput, with error: any Error) {
        tokenizationModuleOutput?.didFinish(on: self, with: .paymentConfirmation(error))
    }

    func sbpModule(_ module: SbpModuleInput, didFinishConfirmation paymentMethodType: PaymentMethodType) {
        tokenizationModuleOutput?.didFinishConfirmation(paymentMethodType: .sbp)
    }

    func sbpModule(
        _ module: SbpModuleInput,
        didTokenize token: Tokens,
        paymentMethodType: PaymentMethodType
    ) {
        sbpModuleInput = module
        didTokenize(
            tokens: token,
            paymentMethodType: paymentMethodType,
            scheme: .sbp
        )
    }
}

// MARK: - TokenizationModuleInput

extension PaymentMethodsPresenter: TokenizationModuleInput {
    func start3dsProcess(
        requestUrl: String
    ) {
        let inputData = CardSecModuleInputData(
            requestUrl: requestUrl,
            redirectUrl: GlobalConstants.returnUrl,
            isLoggingEnabled: isLoggingEnabled
        )
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.router.openCardSecModule(
                inputData: inputData,
                moduleOutput: self
            )
        }
    }

    func startConfirmationProcess(
        confirmationUrl: String,
        paymentMethodType: PaymentMethodType
    ) {
        switch paymentMethodType {
        case .sberbank:
            sberpayModuleInput?.confirmPayment(
                clientApplicationKey: clientApplicationKey,
                confirmationUrl: confirmationUrl
            )

        case .sbp:
            sbpModuleInput?.confirmPayment(
                clientApplicationKey: clientApplicationKey,
                confirmationUrl: confirmationUrl
            )

        default:
            let inputData = CardSecModuleInputData(
                requestUrl: confirmationUrl,
                redirectUrl: GlobalConstants.returnUrl,
                isLoggingEnabled: isLoggingEnabled
            )
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.router.openCardSecModule(
                    inputData: inputData,
                    moduleOutput: self
                )
            }
        }
    }
}

// MARK: - CardSecModuleOutput

extension PaymentMethodsPresenter: CardSecModuleOutput {

    func didSuccessfullyPassedCardSec(on module: CardSecModuleInput) {
        tokenizationModuleOutput?.didFinishConfirmation(paymentMethodType: .bankCard)
        router.closeCardSecModule()
    }

    func didPressCloseButton(
        on module: CardSecModuleInput
    ) {
        router.closeCardSecModule()
        bankCardModuleInput?.hideActivity()
        linkedCardModuleInput?.hideActivity()
        sbpModuleInput?.hideActivity()
    }

    func viewDidDisappear() {
        bankCardModuleInput?.hideActivity()
        linkedCardModuleInput?.hideActivity()
        tokenizationModuleOutput?.didFinishConfirmation(paymentMethodType: .bankCard)
    }
}

// MARK: - CardSecModuleOutput

extension PaymentMethodsPresenter: CardSettingsModuleOutput {
    func cardSettingsModuleDidCancel() {
        DispatchQueue.main.async {
            self.router.closeCardSettingsModule()
        }
    }
    func cardSettingsModuleDidUnbindCard(mask: String) {
        let notification = UIViewController.ToastAlertNotification(
            title: nil,
            message: String(format: CommonLocalized.CardSettingsDetails.unbindSuccess, mask),
            type: .success,
            style: .toast,
            actions: []
        )

        DispatchQueue.main.async {
            self.view?.present(notification)
            self.view?.showActivity()
            let logo = self.paymentMethodViewModelFactory.yooLogoImage()
            self.view?.setLogoVisible(image: logo, isVisible: self.isLogoVisible)
            self.router.closeCardSettingsModule()
        }

        DispatchQueue.global().async { [weak self] in
            self?.interactor.fetchShop()
        }
    }
}

// MARK: - Private helpers

private extension PaymentMethodsPresenter {
    func didTokenize(
        tokens: Tokens,
        paymentMethodType: PaymentMethodType,
        scheme: AnalyticsEvent.TokenizeScheme
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.tokenizationModuleOutput?.tokenizationModule(
                self,
                didTokenize: tokens,
                paymentMethodType: paymentMethodType
            )
        }
    }

    func didFinish(module: TokenizationModuleInput, error: YooKassaPaymentsError?) {
        tokenizationModuleOutput?.didFinish(on: module, with: error)
    }
}

// MARK: - Constants

private extension PaymentMethodsPresenter {
    enum Constants {
        enum YooMoneyApp2App {
            // yoomoneyauth://app2app/exchange?clientId={clientId}&scope={scope}&redirect_uri={redirect_uri}
            static let scheme = "yoomoneyauth://"
            static let host = "app2app"
            static let firstPath = "exchange"
            static let clientId = "clientId"
            static let scope = "scope"
            static let redirectUri = "redirect_uri"

            enum Scope {
                static let accountInfo = "user_auth_center:account_info"
                static let balance = "wallet:balance"
            }

        }
    }
}

// MARK: - Localized

private extension PaymentMethodsPresenter {
    enum Localized {
        enum Error {
            static let noWalletTitle = NSLocalizedString(
                "Error.noWalletTitle",
                bundle: Bundle.framework,
                value: "Оплата кошельком недоступна",
                comment: "После авторизации в кошельке при запросе доступных методов кошелёк отсутствует"
            )
            static let unbindCardFailed = NSLocalizedString(
                "Error.unbindCardFailed",
                bundle: Bundle.framework,
                value: "Не удалось отвязать карту. Попробуйте ещё раз",
                comment: "Текст ошибки при отвязке карты"
            )
        }
    }
}

// MARK: - Private global helpers

private func makeInitialSavePaymentMethod(
    _ savePaymentMethod: SavePaymentMethod
) -> Bool {
    let initialSavePaymentMethod: Bool
    switch savePaymentMethod {
    case .on:
        initialSavePaymentMethod = true
    case .off, .userSelects:
        initialSavePaymentMethod = false
    }
    return initialSavePaymentMethod
}
