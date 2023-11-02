protocol ApplePayContractRouterInput: AnyObject {
    func showBrowser(_ url: URL)
    func presentSafeDealInfo(title: String, body: String)
    func presentSavePaymentMethodInfo(inputData: SavePaymentMethodInfoModuleInputData)
    func presentApplePay(inputData: ApplePayModuleInputData, moduleOutput: ApplePayModuleOutput)
    func closeApplePay(completion: (() -> Void)?)
}
