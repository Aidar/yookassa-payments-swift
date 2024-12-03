import UIKit
@_implementationOnly import YooMoneyUI

final class YooMoneyViewController: UIViewController, PlaceholderProvider {

    // MARK: - VIPER

    var output: YooMoneyViewOutput!

    // MARK: - Touches, Presses, and Gestures

    private lazy var viewTapGestureRecognizer: UITapGestureRecognizer = {
        $0.delegate = self
        return $0
    }(UITapGestureRecognizer(
        target: self,
        action: #selector(viewTapGestureRecognizerHandle)
    ))

    // MARK: - UI properties

    private lazy var scrollView: UIScrollView = {
        $0.setStyles(UIView.Styles.YKSdk.defaultBackground)
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.keyboardDismissMode = .interactive
        return $0
    }(UIScrollView())

    private lazy var contentView: UIView = {
        $0.setStyles(UIView.Styles.YKSdk.defaultBackground)
        $0.translatesAutoresizingMaskIntoConstraints = false
        return $0
    }(UIView())

    private lazy var contentStackView: UIStackView = {
        $0.setStyles(UIView.Styles.YKSdk.defaultBackground)
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.axis = .vertical
        return $0
    }(UIStackView())

    private lazy var orderView: OrderView = {
        $0.setStyles(UIView.Styles.YKSdk.defaultBackground)
        return $0
    }(OrderView())

    private lazy var paymentMethodView: LargeIconButtonItemView = {
        $0.tintColor = CustomizationStorage.shared.mainScheme
        $0.setStyles(
            UIView.Styles.YKSdk.defaultBackground,
            LargeIconButtonItemView.Styles.secondary
        )
        return $0
    }(LargeIconButtonItemView())

    private lazy var actionButtonStackView: UIStackView = {
        $0.setStyles(UIView.Styles.YKSdk.defaultBackground)
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.axis = .vertical
        $0.spacing = Space.single
        return $0
    }(UIStackView())

    private lazy var submitButton: Button = {
        $0.tintColor = CustomizationStorage.shared.mainScheme
        $0.setStyles(
            UIButton.DynamicStyle.primary,
            UIView.Styles.heightAsContent
        )
        $0.setStyledTitle(CommonLocalized.Contract.next, for: .normal)
        $0.addTarget(
            self,
            action: #selector(didPressActionButton),
            for: .touchUpInside
        )
        return $0
    }(Button(type: .custom))

    private lazy var submitButtonContainer: UIView = {
        let view = UIView(frame: .zero)
        view.translatesAutoresizingMaskIntoConstraints = false
        submitButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(submitButton)
        let defaultHeight = submitButton.heightAnchor.constraint(equalToConstant: Space.triple * 2)
        NSLayoutConstraint.activate([
            submitButton.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            submitButton.topAnchor.constraint(equalTo: view.topAnchor),
            view.trailingAnchor.constraint(equalTo: submitButton.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: submitButton.bottomAnchor, constant: Space.single),
            defaultHeight,
        ])

        return view
    }()

    private let termsOfServiceLinkedTextView: LinkedTextView = {
        let view = LinkedTextView()
        view.setContentCompressionResistancePriority(.required, for: .vertical)
        view.tintColor = CustomizationStorage.shared.mainScheme
        view.setStyles(
            UIView.Styles.YKSdk.defaultBackground,
            UITextView.Styles.YKSdk.linked
        )
        return view
    }()

    private let safeDealLinkedTextView: LinkedTextView = {
        let view = LinkedTextView()
        view.setContentCompressionResistancePriority(.required, for: .vertical)
        view.tintColor = CustomizationStorage.shared.mainScheme
        view.setStyles(
            UIView.Styles.YKSdk.defaultBackground,
            UITextView.Styles.YKSdk.linked
        )
        return view
    }()

    // MARK: - PlaceholderProvider

    lazy var placeholderView: PlaceholderView = {
        $0.setStyles(UIView.Styles.YKSdk.defaultBackground)
        $0.contentView = self.actionTitleTextDialog
        return $0
    }(PlaceholderView())

    lazy var actionTitleTextDialog: ActionTitleTextDialog = {
        $0.tintColor = CustomizationStorage.shared.mainScheme
        $0.setStyles(ActionTitleTextDialog.Styles.fail)
        $0.buttonTitle = CommonLocalized.PlaceholderView.buttonTitle
        $0.text = CommonLocalized.PlaceholderView.text
        $0.delegate = output
        return $0
    }(ActionTitleTextDialog())

    // MARK: - Separator

    private lazy var separator: UIView = {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.setStyles(UIView.Styles.YKSdk.separator)
        return $0
    }(UIView())

    private lazy var separatorView: UIView = {
        $0.translatesAutoresizingMaskIntoConstraints = false
        return $0
    }(UIView())

    // MARK: - Switcher save auth in app

    private lazy var saveAuthInAppSwitchItemView: SwitchItemView = {
        $0.tintColor = CustomizationStorage.shared.mainScheme
        $0.layoutMargins = UIEdgeInsets(
            top: Space.double,
            left: Space.double,
            bottom: Space.double,
            right: Space.double
        )
        $0.state = true
        $0.setStyles(SwitchItemView.Styles.primary)
        $0.title = CommonLocalized.SaveAuthInApp.title
        $0.delegate = self
        return $0
    }(SwitchItemView())

    private lazy var saveAuthInAppSectionHeaderView: SectionHeaderView = {
        $0.layoutMargins = UIEdgeInsets(
            top: Space.single / 2,
            left: Space.double,
            bottom: Space.double,
            right: Space.double
        )
        $0.title = CommonLocalized.SaveAuthInApp.text
        $0.setStyles(SectionHeaderView.Styles.footer)
        return $0
    }(SectionHeaderView())

    // MARK: - Switch save payment method UI Properties

    private lazy var savePaymentMethodSwitchItemView: SwitchItemView = {
        $0.tintColor = CustomizationStorage.shared.mainScheme
        $0.layoutMargins = UIEdgeInsets(
            top: Space.double,
            left: Space.double,
            bottom: Space.double,
            right: Space.double
        )
        $0.setStyles(SwitchItemView.Styles.primary)
        $0.title = Localized.savePaymentMethodTitle
        $0.delegate = self
        return $0
    }(SwitchItemView())

    private lazy var savePaymentMethodSwitchLinkedItemView: LinkedItemView = {
        $0.tintColor = CustomizationStorage.shared.mainScheme
        $0.layoutMargins = UIEdgeInsets(
            top: Space.single / 2,
            left: Space.double,
            bottom: Space.double,
            right: Space.double
        )
        $0.setStyles(LinkedItemView.Styles.linked)
        $0.delegate = self
        return $0
    }(LinkedItemView())

    // MARK: - Strict save payment method UI Properties

    private lazy var savePaymentMethodStrictSectionHeaderView: SectionHeaderView = {
        $0.layoutMargins = UIEdgeInsets(
            top: Space.double,
            left: Space.double,
            bottom: 0,
            right: Space.double
        )
        $0.title = Localized.savePaymentMethodTitle
        $0.setStyles(SectionHeaderView.Styles.primary)
        return $0
    }(SectionHeaderView())

    private lazy var savePaymentMethodStrictLinkedItemView: LinkedItemView = {
        $0.tintColor = CustomizationStorage.shared.mainScheme
        $0.layoutMargins = UIEdgeInsets(
            top: Space.single / 4,
            left: Space.double,
            bottom: Space.double,
            right: Space.double
        )
        $0.setStyles(LinkedItemView.Styles.linked)
        $0.delegate = self
        return $0
    }(LinkedItemView())

    // MARK: - Constraints

    private lazy var scrollViewHeightConstraint: NSLayoutConstraint = {
        let constraint = scrollView.heightAnchor.constraint(equalToConstant: 0)
        constraint.priority = .defaultHigh + 1
        return constraint
    }()

    // MARK: - Managing the View

    override func loadView() {
        view = UIView()
        view.setStyles(UIView.Styles.YKSdk.defaultBackground)
        view.addGestureRecognizer(viewTapGestureRecognizer)
        navigationItem.title = Localized.title

        termsOfServiceLinkedTextView.delegate = self
        safeDealLinkedTextView.delegate = self
        safeDealLinkedTextView.isHidden = true
        setupView()
        setupConstraints()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.setupView()
    }

    // MARK: - Setup

    private func setupView() {
        [
            scrollView,
            actionButtonStackView,
        ].forEach(view.addSubview)

        scrollView.addSubview(contentView)

        [
            contentStackView,
        ].forEach(contentView.addSubview)

        [
            orderView,
            paymentMethodView,
        ].forEach(contentStackView.addArrangedSubview)

        [
            submitButtonContainer,
            termsOfServiceLinkedTextView,
            safeDealLinkedTextView,
        ].forEach(actionButtonStackView.addArrangedSubview)

        [
            separator,
        ].forEach(separatorView.addSubview)
    }

    private func setupConstraints() {
        let bottomConstraint = view.safeAreaLayoutGuide.bottomAnchor.constraint(
            equalTo: actionButtonStackView.bottomAnchor,
            constant: Space.double
        )
        let topConstraint = scrollView.topAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.topAnchor
        )

        let constraints = [
            scrollViewHeightConstraint,

            topConstraint,
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            actionButtonStackView.topAnchor.constraint(
                equalTo: scrollView.bottomAnchor,
                constant: Space.double
            ),

            actionButtonStackView.leadingAnchor.constraint(
                equalTo: view.leadingAnchor,
                constant: Space.double
            ),
            view.trailingAnchor.constraint(
                equalTo: actionButtonStackView.trailingAnchor,
                constant: Space.double
            ),
            bottomConstraint,

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            contentStackView.topAnchor.constraint(equalTo: contentView.topAnchor),
            contentStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            contentStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            contentStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            separator.topAnchor.constraint(equalTo: separatorView.topAnchor),
            separator.leadingAnchor.constraint(equalTo: separatorView.leadingAnchor, constant: Space.double),
            separator.bottomAnchor.constraint(equalTo: separatorView.bottomAnchor),
            separatorView.trailingAnchor.constraint(equalTo: separator.trailingAnchor, constant: Space.double),
        ]
        NSLayoutConstraint.activate(constraints)
    }

    // MARK: - Configuring the View’s Layout Behavior

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        DispatchQueue.main.async {
            self.fixTableViewHeight()
        }
    }

    private func fixTableViewHeight() {
        scrollViewHeightConstraint.constant = ceil(scrollView.contentSize.height) + Space.triple * 2
    }

    // MARK: - Action

    @objc
    private func didPressActionButton(
        _ sender: UIButton
    ) {
        output?.didTapActionButton()
    }

    @objc
    private func viewTapGestureRecognizerHandle(
        _ gestureRecognizer: UITapGestureRecognizer
    ) {
        guard gestureRecognizer.state == .recognized else { return }
        view.endEditing(true)
    }
}

// MARK: - YooMoneyViewInput

extension YooMoneyViewController: YooMoneyViewInput {
    func setupViewModel(_ viewModel: YooMoneyViewModel) {
        orderView.title = viewModel.shopName
        orderView.subtitle = viewModel.description
        orderView.value = makePrice(viewModel.price)
        if let fee = viewModel.fee {
            orderView.subvalue = "\(CommonLocalized.Contract.fee) " + makePrice(fee)
        } else {
            orderView.subvalue = nil
        }

        viewModel.paymentOptionTitle.map { navigationItem.title = $0 }

        paymentMethodView.title = viewModel.paymentMethod.title
        paymentMethodView.subtitle = viewModel.paymentMethod.subtitle ?? ""
        paymentMethodView.image = UIImage.yAvatar

        paymentMethodView.rightButtonTitle = Localized.logout
        paymentMethodView.output = self

        termsOfServiceLinkedTextView.attributedText = viewModel.terms
        safeDealLinkedTextView.attributedText = viewModel.safeDealText
        safeDealLinkedTextView.isHidden = viewModel.safeDealText?.string.isEmpty ?? true
        termsOfServiceLinkedTextView.textAlignment = .center
        safeDealLinkedTextView.textAlignment = .center
    }

    func setupAvatar(_ avatar: UIImage) {
        paymentMethodView.image = avatar.rounded(cornerRadius: Space.fivefold)
    }

    func setSavePaymentMethodViewModel(_ savePaymentMethodViewModel: SavePaymentMethodViewModel) {
        if contentStackView.arrangedSubviews.contains(saveAuthInAppSwitchItemView) {
            contentStackView.addArrangedSubview(separatorView)
        }

        switch savePaymentMethodViewModel {
        case .switcher(let viewModel):
            savePaymentMethodSwitchItemView.state = viewModel.state
            savePaymentMethodSwitchLinkedItemView.attributedTitle = makeSavePaymentMethodAttributedString(
                text: viewModel.text,
                hyperText: viewModel.hyperText,
                font: UIFont.dynamicCaption1,
                foregroundColor: UIColor.YKSdk.secondary
            )
            [
                savePaymentMethodSwitchItemView,
                savePaymentMethodSwitchLinkedItemView,
            ].forEach(contentStackView.addArrangedSubview)

        case .strict(let viewModel):
            savePaymentMethodStrictLinkedItemView.attributedTitle = makeSavePaymentMethodAttributedString(
                text: viewModel.text,
                hyperText: viewModel.hyperText,
                font: UIFont.dynamicCaption1,
                foregroundColor: UIColor.YKSdk.secondary
            )
            [
                savePaymentMethodStrictSectionHeaderView,
                savePaymentMethodStrictLinkedItemView,
            ].forEach(contentStackView.addArrangedSubview)
        }
    }

    func setSaveAuthInAppSwitchItemView() {
        [
            saveAuthInAppSwitchItemView,
            saveAuthInAppSectionHeaderView,
        ].forEach(contentStackView.addArrangedSubview)
    }

    func showPlaceholder(
        with message: String
    ) {
        actionTitleTextDialog.title = message
        showPlaceholder()
    }

    func setBackBarButtonHidden(
        _ isHidden: Bool
    ) {
        navigationItem.hidesBackButton = isHidden
    }

    private func makePrice(
        _ price: PriceViewModel
    ) -> String {
        return price.integerPart
             + price.decimalSeparator
             + price.fractionalPart
             + price.currency
    }

    private func makeSavePaymentMethodAttributedString(
        text: String,
        hyperText: String,
        font: UIFont,
        foregroundColor: UIColor
    ) -> NSAttributedString {
        let attributedText: NSMutableAttributedString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: foregroundColor,
        ]
        attributedText = NSMutableAttributedString(string: "\(text) ", attributes: attributes)

        let linkAttributedText = NSMutableAttributedString(string: hyperText, attributes: attributes)
        let linkRange = NSRange(location: 0, length: hyperText.count)
        // swiftlint:disable force_unwrapping
        let fakeLink = URL(string: "https://yookassa.ru")!
        // swiftlint:enable force_unwrapping
        linkAttributedText.addAttribute(.link, value: fakeLink, range: linkRange)
        attributedText.append(linkAttributedText)

        return attributedText
    }
}

// MARK: - ActivityIndicatorFullViewPresenting

extension YooMoneyViewController: ActivityIndicatorFullViewPresenting {
    func showActivity() {
        showFullViewActivity(style: ActivityIndicatorView.Styles.heavyLight)
    }

    func hideActivity() {
        hideFullViewActivity()
    }
}

// MARK: - UIGestureRecognizerDelegate

extension YooMoneyViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldReceive touch: UITouch
    ) -> Bool {
        guard gestureRecognizer === viewTapGestureRecognizer,
              touch.view is UIControl else {
            return true
        }
        return false
    }
}

// MARK: - UITextViewDelegate

extension YooMoneyViewController: UITextViewDelegate {
    func textView(
        _ textView: UITextView,
        shouldInteractWith URL: URL,
        in characterRange: NSRange
    ) -> Bool {
        switch textView {
        case termsOfServiceLinkedTextView:
            output?.didTapTermsOfService(URL)
        case safeDealLinkedTextView:
            output?.didTapSafeDealInfo(URL)
        default:
            assertionFailure("Unsupported textView")
        }
        return false
    }
}

// MARK: - LinkedItemViewOutput

extension YooMoneyViewController: LinkedItemViewOutput {
    func didTapOnLinkedView(on itemView: LinkedItemViewInput) {
        switch itemView {
        case _ where itemView === savePaymentMethodSwitchLinkedItemView,
             _ where itemView === savePaymentMethodStrictLinkedItemView:
            output?.didTapOnSavePaymentMethod()
        default:
            assertionFailure("Unsupported itemView")
        }
    }
}

// MARK: - SwitchItemViewOutput

extension YooMoneyViewController: SwitchItemViewOutput {

    func didInteractOn(itemView: SwitchItemViewInput, withLink: URL) {
        output.didTapTermsOfService(withLink)
    }

    func switchItemView(
        _ itemView: SwitchItemViewInput,
        didChangeState state: Bool
    ) {
        switch itemView {
        case _ where itemView === saveAuthInAppSwitchItemView:
            output?.didChangeSaveAuthInAppState(state)
        case _ where itemView === savePaymentMethodSwitchItemView:
            output?.didChangeSavePaymentMethodState(state)
        default:
            assertionFailure("Unsupported itemView")
        }
    }
}

// MARK: - LargeIconButtonItemViewOutput

extension YooMoneyViewController: LargeIconButtonItemViewOutput {
    func didPressRightButton(in itemView: LargeIconButtonItemViewInput) {
        switch itemView {
        case _ where itemView === paymentMethodView:
            output?.didTapLogout()
        default:
            assertionFailure("Unsupported itemView")
        }
    }
}

// MARK: - Localized

private extension YooMoneyViewController {
    enum Localized {
        static let title = NSLocalizedString(
            "YooMoney.title",
            bundle: Bundle.framework,
            value: "ЮMoney",
            comment: "Текст `ЮMoney` https://yadi.sk/i/o89CnEUSmNsM7g"
        )
        static let savePaymentMethodTitle = NSLocalizedString(
            "Wallet.savePaymentMethod.title",
            bundle: Bundle.framework,
            value: "Привязать кошелек",
            comment: "Текст `Привязать кошелек` https://yadi.sk/i/o89CnEUSmNsM7g"
        )
        static let logout = NSLocalizedString(
            "Contract.logout",
            bundle: Bundle.framework,
            value: "Выйти",
            comment: "Текст `Выйти` https://yadi.sk/i/o89CnEUSmNsM7g"
        )
    }
}
