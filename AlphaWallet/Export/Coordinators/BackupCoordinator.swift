// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit
import Result

protocol BackupCoordinatorDelegate: class {
    func didCancel(coordinator: BackupCoordinator)
    func didFinish(account: EthereumAccount, in coordinator: BackupCoordinator)
}

class BackupCoordinator: Coordinator {
    private let keystore: Keystore
    private let account: EthereumAccount

    let navigationController: UINavigationController
    weak var delegate: BackupCoordinatorDelegate?
    var coordinators: [Coordinator] = []

    init(
        navigationController: UINavigationController,
        keystore: Keystore,
        account: EthereumAccount
    ) {
        self.navigationController = navigationController
        self.keystore = keystore
        self.account = account
    }

    func start() {
        export(for: account)
    }

    func finish(result: Result<Bool, AnyError>) {
        switch result {
        case .success:
            delegate?.didFinish(account: account, in: self)
        case .failure:
            delegate?.didCancel(coordinator: self)
        }
    }

    func presentActivityViewController(for account: EthereumAccount, newPassword: String, completion: @escaping (Result<Bool, AnyError>) -> Void) {
        navigationController.displayLoading(
            text: R.string.localizable.exportPresentBackupOptionsLabelTitle()
        )
        keystore.export(account: account, newPassword: newPassword) { [weak self] result in
            guard let strongSelf = self else { return }
            strongSelf.handleExport(result: result, completion: completion)
        }
    }

    private func handleExport(result: (Result<String, KeystoreError>), completion: @escaping (Result<Bool, AnyError>) -> Void) {
        switch result {
        case .success(let value):
            let url = URL(fileURLWithPath: NSTemporaryDirectory().appending("alphawallet_backup_\(account.address.eip55String).json"))
            do {
                try value.data(using: .utf8)!.write(to: url)
            } catch {
                return completion(.failure(AnyError(error)))
            }

            let activityViewController = UIActivityViewController(
                activityItems: [url],
                applicationActivities: nil
            )
            activityViewController.completionWithItemsHandler = { _, result, _, error in
                do { try FileManager.default.removeItem(at: url)
            } catch { }
                completion(.success(result))
            }
            activityViewController.popoverPresentationController?.sourceView = navigationController.view
            activityViewController.popoverPresentationController?.sourceRect = navigationController.view.centerRect
            navigationController.present(activityViewController, animated: true) { [unowned self] in
                self.navigationController.hideLoading()
            }
        case .failure(let error):
            navigationController.hideLoading()
            navigationController.displayError(error: error)
        }
    }

    func presentShareActivity(for account: EthereumAccount, newPassword: String) {
        presentActivityViewController(for: account, newPassword: newPassword) { [weak self] result in
            guard let strongSelf = self else { return }
            strongSelf.finish(result: result)
        }
    }

    func export(for account: EthereumAccount) {
        let coordinator = EnterPasswordCoordinator(account: account)
        coordinator.delegate = self
        coordinator.start()
        navigationController.present(coordinator.navigationController, animated: true, completion: nil)
        addCoordinator(coordinator)
    }
}

extension BackupCoordinator: EnterPasswordCoordinatorDelegate {
    func didCancel(in coordinator: EnterPasswordCoordinator) {
        coordinator.navigationController.dismiss(animated: true, completion: nil)
        removeCoordinator(coordinator)
    }

    func didEnterPassword(password: String, account: EthereumAccount, in coordinator: EnterPasswordCoordinator) {
        coordinator.navigationController.dismiss(animated: true) { [unowned self] in
            self.presentShareActivity(for: account, newPassword: password)
        }
        removeCoordinator(coordinator)
    }
}
