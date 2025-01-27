import YooKassaPaymentsApi

struct PaymentMethodsModuleInputData {
    let applicationScheme: String?
    let clientApplicationKey: String
    let gatewayId: String?
    let shopName: String
    let shopId: String
    let purchaseDescription: String
    let amount: Amount
    let tokenizationSettings: TokenizationSettings
    let testModeSettings: TestModeSettings?
    let customizationSettings: CustomizationSettings?
    let isLoggingEnabled: Bool
    let getSavePaymentMethod: Bool?
    let moneyAuthClientId: String?
    let returnUrl: String?
    let savePaymentMethod: SavePaymentMethod
    let userPhoneNumber: String?
    let cardScanning: CardScanning?
    let customerId: String?
    let config: Config
}

protocol PaymentMethodsModuleInput: SheetViewModuleOutput {
    func authorizeInYooMoney(
        with cryptogram: String
    )
}
