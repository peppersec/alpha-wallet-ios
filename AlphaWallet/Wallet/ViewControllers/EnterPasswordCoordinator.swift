// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit

protocol EnterPasswordCoordinatorDelegate: class {
    func didEnterPassword(password: String, account: EthereumAccount, in coordinator: EnterPasswordCoordinator)
    func didCancel(in coordinator: EnterPasswordCoordinator)
}

class EnterPasswordCoordinator: Coordinator {
    private lazy var enterPasswordController: EnterPasswordViewController = {
        let controller = EnterPasswordViewController(account: account)
        controller.navigationItem.leftBarButtonItem = UIBarButtonItem(title: R.string.localizable.cancel(), style: .plain, target: self, action: #selector(dismiss))
        controller.delegate = self
        return controller
    }()
    private let account: EthereumAccount

    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []
    weak var delegate: EnterPasswordCoordinatorDelegate?

    init(
        navigationController: UINavigationController = UINavigationController(),
        account: EthereumAccount
    ) {
        self.navigationController = navigationController
        self.account = account
    }

    func start() {
        navigationController.viewControllers = [enterPasswordController]
    }

    @objc func dismiss() {
        delegate?.didCancel(in: self)
    }
}

extension EnterPasswordCoordinator: EnterPasswordViewControllerDelegate {
    func didEnterPassword(password: String, for account: EthereumAccount, in viewController: EnterPasswordViewController) {
        delegate?.didEnterPassword(password: password, account: account, in: self)
    }
}
