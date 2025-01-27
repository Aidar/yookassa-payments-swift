import UIKit

enum LinkedCardAssembly {
    static func makeModule(
        inputData: LinkedCardModuleInputData,
        moduleOutput: LinkedCardModuleOutput?
    ) -> UIViewController {
        let view = LinkedCardViewController()

        let cardService = CardService()
        let paymentMethodViewModelFactory =
            PaymentMethodViewModelFactoryAssembly.makeFactory(isLoggingEnabled: inputData.isLoggingEnabled)
        let presenter = LinkedCardPresenter(
            cardService: cardService,
            paymentMethodViewModelFactory: paymentMethodViewModelFactory,
            clientApplicationKey: inputData.clientApplicationKey,
            testModeSettings: inputData.testModeSettings,
            isLoggingEnabled: inputData.isLoggingEnabled,
            moneyAuthClientId: inputData.moneyAuthClientId,
            shopName: inputData.shopName,
            purchaseDescription: inputData.purchaseDescription,
            price: inputData.price,
            fee: inputData.fee,
            paymentOption: inputData.paymentOption,
            termsOfService: inputData.termsOfService,
            returnUrl: inputData.returnUrl,
            initialSavePaymentMethod: inputData.initialSavePaymentMethod,
            isBackBarButtonHidden: inputData.isBackBarButtonHidden,
            isSafeDeal: inputData.isSafeDeal
        )

        let authorizationService = AuthorizationServiceAssembly.makeService(
            isLoggingEnabled: inputData.isLoggingEnabled,
            testModeSettings: inputData.testModeSettings,
            moneyAuthClientId: inputData.moneyAuthClientId
        )
        let analyticsService = AnalyticsTrackingService.makeService(isLoggingEnabled: inputData.isLoggingEnabled)
        let paymentService = PaymentServiceAssembly.makeService(
            tokenizationSettings: inputData.tokenizationSettings,
            testModeSettings: inputData.testModeSettings,
            isLoggingEnabled: inputData.isLoggingEnabled
        )
        let walletMediator = WalletPaymentsMediatorFactory.makeMediator(
            authorizationService: authorizationService,
            paymentService: paymentService,
            clientApplicationKey: inputData.clientApplicationKey,
            customerId: inputData.customerId
        )
        let interactor = LinkedCardInteractor(
            authorizationService: authorizationService,
            analyticsService: analyticsService,
            walletPaymentsMediator: walletMediator,
            clientApplicationKey: inputData.clientApplicationKey,
            customerId: inputData.customerId
        )

        let router = LinkedCardRouter()

        presenter.view = view
        presenter.interactor = interactor
        presenter.router = router
        presenter.moduleOutput = moduleOutput

        interactor.output = presenter

        view.output = presenter

        router.transitionHandler = view

        return view
    }
}
