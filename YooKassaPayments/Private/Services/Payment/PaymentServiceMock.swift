import FunctionalSwift
import YooKassaPaymentsApi

final class PaymentServiceMock {

    // MARK: - Init data

    private let paymentMethodHandlerService: PaymentMethodHandlerService
    private let testModeSettings: TestModeSettings
    private let keyValueStoring: KeyValueStoring

    // MARK: - Init

    init(
        paymentMethodHandlerService: PaymentMethodHandlerService,
        testModeSettings: TestModeSettings,
        keyValueStoring: KeyValueStoring
    ) {
        self.paymentMethodHandlerService = paymentMethodHandlerService
        self.testModeSettings = testModeSettings
        self.keyValueStoring = keyValueStoring
    }
}

// MARK: - PaymentService

extension PaymentServiceMock: PaymentService {
    func tokenizeCardInstrument(
        clientApplicationKey: String,
        amount: MonetaryAmount,
        tmxSessionId: String,
        confirmation: Confirmation,
        savePaymentMethod: Bool,
        instrumentId: String,
        csc: String?,
        completion: @escaping (Swift.Result<Tokens, Error>) -> Void
    ) {
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
            if Bool.random() {
                completion(.failure(MockError.default))
            } else {
                self.makeTokensPromise(completion: completion)
            }
        }
    }

    func unbind(authToken: String, id: String, completion: @escaping (Swift.Result<Void, Error>) -> Void) {
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
            if Bool.random() { completion(.failure(MockError.default)) } else { completion(.success(())) }
        }
    }

    func fetchPaymentOptions(
        clientApplicationKey: String,
        authorizationToken: String?,
        gatewayId: String?,
        amount: String?,
        currency: String?,
        getSavePaymentMethod: Bool?,
        customerId: String?,
        completion: @escaping (Swift.Result<Shop, Error>) -> Void
    ) {
        let authorized = keyValueStoring.getString(
            for: KeyValueStoringKeys.moneyCenterAuthToken
        ) != nil
        let items = makePaymentOptions(
            testModeSettings,
            handler: paymentMethodHandlerService,
            authorized: authorized
        )
        let properties = ShopProperties(
            isSafeDeal: true,
            isMarketplace: true,
            agentSchemeData: nil
        )

        DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
            if items.isEmpty {
                completion(.failure(PaymentProcessingError.emptyList))
            } else {
                completion(.success(Shop(options: items, properties: properties)))
            }
        }
    }

    func fetchPaymentMethod(
        clientApplicationKey: String,
        paymentMethodId: String,
        completion: @escaping (Swift.Result<PaymentMethod, Error>) -> Void
    ) {
//        let error = PaymentsApiError(
//            id: "id_value",
//            type: .error,
//            description: "description",
//            parameter: "parameter",
//            retryAfter: nil,
//            errorCode: .invalidRequest
//        )

        let response = PaymentMethod(
            type: .bankCard,
            id: "id_value",
            saved: false,
            title: "title_value",
            cscRequired: true,
            card: .some(.init(
                first6: "123456",
                last4: "0987",
                expiryYear: "2020",
                expiryMonth: "11",
                cardType: .masterCard
            ))
        )

        DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
//            completion(.failure(error))
            completion(.success(response))
        }
    }

    func tokenizeBankCard(
        clientApplicationKey: String,
        bankCard: BankCard,
        confirmation: Confirmation,
        savePaymentMethod: Bool,
        amount: MonetaryAmount?,
        tmxSessionId: String,
        customerId: String?,
        savePaymentInstrument: Bool?,
        completion: @escaping (Swift.Result<Tokens, Error>) -> Void
    ) {
        makeTokensPromise(completion: completion)
    }

    func tokenizeWallet(
        clientApplicationKey: String,
        walletAuthorization: String,
        confirmation: Confirmation,
        savePaymentMethod: Bool,
        paymentMethodType: PaymentMethodType,
        amount: MonetaryAmount?,
        tmxSessionId: String,
        customerId: String?,
        completion: @escaping (Swift.Result<Tokens, Error>) -> Void
    ) {
        makeTokensPromise(completion: completion)
    }

    func tokenizeLinkedBankCard(
        clientApplicationKey: String,
        walletAuthorization: String,
        cardId: String,
        csc: String,
        confirmation: Confirmation,
        savePaymentMethod: Bool,
        paymentMethodType: PaymentMethodType,
        amount: MonetaryAmount?,
        tmxSessionId: String,
        customerId: String?,
        completion: @escaping (Swift.Result<Tokens, Error>) -> Void
    ) {
        makeTokensPromise(completion: completion)
    }

    func tokenizeSberbank(
        clientApplicationKey: String,
        phoneNumber: String,
        confirmation: Confirmation,
        savePaymentMethod: Bool,
        amount: MonetaryAmount?,
        tmxSessionId: String,
        customerId: String?,
        completion: @escaping (Swift.Result<Tokens, Error>) -> Void
    ) {
        makeTokensPromise(completion: completion)
    }

    func tokenizeSberpay(
        clientApplicationKey: String,
        confirmation: Confirmation,
        savePaymentMethod: Bool,
        amount: MonetaryAmount?,
        tmxSessionId: String,
        customerId: String?,
        completion: @escaping (Swift.Result<Tokens, Error>) -> Void
    ) {
        makeTokensPromise(completion: completion)
    }

    func tokenizeRepeatBankCard(
        clientApplicationKey: String,
        amount: MonetaryAmount,
        tmxSessionId: String,
        confirmation: Confirmation,
        savePaymentMethod: Bool,
        paymentMethodId: String,
        csc: String,
        completion: @escaping (Swift.Result<Tokens, Error>) -> Void
    ) {
        makeTokensPromise(completion: completion)
    }

    func tokenizeSbp(
        clientApplicationKey: String,
        confirmation: Confirmation,
        savePaymentMethod: Bool,
        amount: MonetaryAmount?,
        tmxSessionId: String,
        customerId: String?,
        completion: @escaping (Swift.Result<Tokens, Error>) -> Void
    ) {
        makeTokensPromise(completion: completion)
    }

    private func makeTokensPromise(
        completion: @escaping (Swift.Result<Tokens, Error>) -> Void
    ) {
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { [weak self] in
            guard let self = self else { return }
            if self.testModeSettings.enablePaymentError {
                completion(.failure(mockError))
            } else {
                completion(.success(mockTokens))
            }
        }
    }

    func fetchConfirmationDetails(
        clientApplicationKey: String,
        confirmationData: String
    ) -> Promise<Error, (String, ConfirmationData)> {
        guard let url = URL(string: "https://qr.nspk.ru/50563b2d54929c52a2cedd5aec9a0777?type=02&bank=100000000022&sum=30000&cur=RUB&crc=C08B")
        else { return .canceling }
        return .right(("2bed8dc7-000f-5000-a000-140493f5e463", .sbp(url)))
    }

    func fetchPayment(
        clientApplicationKey: String,
        paymentId: String
    ) -> Promise<Error, SbpPayment> {
        .right(SbpPayment(
            paymentId: "2bf9767a-000f-5000-a000-1207c6b7cfd7",
            sbpPaymentStatus: .pending,
            sbpUserPaymentProcessStatus: .inProgress
        ))
    }

    func fetchApiKey(clientApplicationKey: String) -> Promise<Error, String> {
        .right("")
    }
}

// MARK: - Promise helper

private let timeout: Double = 1

// MARK: - Data for Error

private struct MockError: Error { static let `default` = MockError() }

private let mockError = MockError()

// MARK: - Mock responses

private let mockTokens = Tokens(
    paymentToken: "mock_token",
    profilingData: .init(publicCardId: "mockCardHash-4c70-4266-a117-fe64b0498f65")
)

private func makePaymentOptions(
    _ settings: TestModeSettings,
    handler: PaymentMethodHandlerService,
    authorized: Bool
) -> [PaymentOption] {
    let service = Service(charge: MonetaryAmount(value: 3.14, currency: settings.charge.currency.rawValue))
    let fee = Fee(service: service, counterparty: nil)

    let charge = makeCharge(charge: settings.charge, fee: fee)

    let linkedCards = authorized
        ? makeLinkedCards(count: settings.cardsCount, charge: charge, fee: fee)
        : []

    let paymentOptions = makeDefaultPaymentOptions(
        charge,
        fee: fee,
        authorized: authorized,
        yooMoneyLinkedCards: linkedCards
    )

    let filteredPaymentOptions = handler.filterPaymentMethods(paymentOptions)

    return filteredPaymentOptions
}

private func makeCharge(
    charge: Amount, fee: Fee?
) -> Amount {
    guard let fee = fee, let service = fee.service else { return charge }
    return Amount(value: charge.value + service.charge.value, currency: charge.currency)
}

private func makeLinkedCards(
    count: Int,
    charge: Amount,
    fee: Fee?
) -> [PaymentInstrumentYooMoneyLinkedBankCard] {
    return (0..<count).map { index in
        makeLinkedCard(
            charge: charge, fee: fee, named: index.isMultiple(of: 2)
        )
    }
}

private func makeLinkedCard(
    charge: Amount,
    fee: Fee?,
    named: Bool
) -> PaymentInstrumentYooMoneyLinkedBankCard {
    let cardName = named ? "Зарплатная карта" : nil
    return PaymentInstrumentYooMoneyLinkedBankCard(
        paymentMethodType: .yooMoney,
        confirmationTypes: nil,
        charge: MonetaryAmountFactory.makePaymentsMonetaryAmount(charge),
        instrumentType: .linkedBankCard,
        cardId: "123456789",
        cardName: cardName,
        cardMask: makeRandomCardMask(),
        cardType: .masterCard,
        identificationRequirement: .simplified,
        fee: fee?.paymentsModel,
        savePaymentMethod: .allowed,
        savePaymentInstrument: true
    )
}

private func makeRandomCardMask() -> String {
    let firstPart = Int.random(in: 100000..<1000000)
    let secondPart = Int.random(in: 1000..<10000)
    return "\(firstPart)******\(secondPart)"
}

private func makeDefaultPaymentOptions(
    _ charge: Amount,
    fee: Fee?,
    authorized: Bool,
    yooMoneyLinkedCards: [PaymentInstrumentYooMoneyLinkedBankCard]
) -> [PaymentOption] {
    let charge = MonetaryAmountFactory.makePaymentsMonetaryAmount(charge)

    var response: [PaymentOption] = [
        PaymentOption(
            paymentMethodType: .sberbank,
            confirmationTypes: [],
            charge: charge,
            identificationRequirement: nil,
            fee: fee?.paymentsModel,
            savePaymentMethod: .forbidden,
            savePaymentInstrument: true
        ),
        makeYooMoney(
            authorized: authorized,
            charge: charge.plain,
            fee: fee
        ),
        PaymentOption(
            paymentMethodType: .sbp,
            confirmationTypes: [],
            charge: charge,
            identificationRequirement: nil,
            fee: fee?.paymentsModel,
            savePaymentMethod: .forbidden,
            savePaymentInstrument: true
        ),
    ]

    response += yooMoneyLinkedCards

    response += [
        PaymentOptionBankCard(
            paymentMethodType: .bankCard,
            confirmationTypes: [],
            charge: charge,
            identificationRequirement: nil,
            fee: fee?.paymentsModel,
            savePaymentMethod: .allowed,
            savePaymentInstrument: true,
            paymentInstruments: [
                .init(
                    paymentInstrumentId: "522188_id",
                    first6: "522188",
                    last4: "3352",
                    cscRequired: true,
                    cardType: .masterCard
                ),
                .init(
                    paymentInstrumentId: "547805_id",
                    first6: "547805",
                    last4: "1405",
                    cscRequired: false,
                    cardType: .masterCard
                ),
            ]
        ),
    ]

    return response
}

private func makeYooMoney(
    authorized: Bool,
    charge: MonetaryAmount,
    fee: Fee?
) -> PaymentOption {
    if authorized {
        return PaymentInstrumentYooMoneyWallet(
            paymentMethodType: .yooMoney,
            confirmationTypes: [],
            charge: charge.paymentsModel,
            instrumentType: .wallet,
            accountId: "2736482364872",
            balance: YooKassaPaymentsApi.MonetaryAmount(
                value: 40_000,
                currency: charge.currency
            ),
            identificationRequirement: .simplified,
            fee: fee?.paymentsModel,
            savePaymentMethod: .allowed,
            savePaymentInstrument: true
        )

    } else {
        return PaymentOption(
            paymentMethodType: .yooMoney,
            confirmationTypes: [],
            charge: charge.paymentsModel,
            identificationRequirement: nil,
            fee: fee?.paymentsModel,
            savePaymentMethod: .allowed,
            savePaymentInstrument: true
        )
    }
}
