// Copyright SIX DAY LLC. All rights reserved.

import Foundation
@testable import AlphaWallet
import TrustKeystore
import Result

struct FakeKeystore: Keystore {
    static var current: Wallet?
    var hasWallets: Bool {
        return !wallets.isEmpty
    }
    var wallets: [Wallet]
    var recentlyUsedWallet: Wallet?

    init(wallets: [Wallet] = [], recentlyUsedWallet: Wallet? = .none) {
        self.wallets = wallets
        self.recentlyUsedWallet = recentlyUsedWallet
    }

    func importWallet(type: ImportType, completion: @escaping (Result<Wallet, KeystoreError>) -> Void) {
    }

    func delete(wallet: Wallet, completion: @escaping (Result<Void, KeystoreError>) -> Void) {
        completion(.failure(KeystoreError.failedToSignTransaction))
    }

    func signHash(_ data: Data, for account: EthereumAccount) -> Result<Data, KeystoreError> {
        return .failure(KeystoreError.failedToSignMessage)
    }

    func signPersonalMessage(_ data: Data, for account: EthereumAccount) -> Result<Data, KeystoreError> {
        return .failure(KeystoreError.failedToSignTransaction)
    }

    func signMessage(_ data: Data, for account: EthereumAccount) -> Result<Data, KeystoreError> {
        return .failure(KeystoreError.failedToSignMessage)
    }

    func signTransaction(_ signTransaction: UnsignedTransaction) -> Result<Data, KeystoreError> {
        return .failure(KeystoreError.failedToSignTransaction)
    }

    func signTypedMessage(_ datas: [EthTypedData], for account: EthereumAccount) -> Result<Data, KeystoreError> {
        return .failure(KeystoreError.failedToSignMessage)
    }

    func createAccount(completion: @escaping (Result<EthereumAccount, KeystoreError>) -> Void) {
    }

    func createAccount() -> EthereumAccount {
        return .make()
    }

    func export(account: EthereumAccount, newPassword: String, completion: @escaping (Result<String, KeystoreError>) -> Void) {
    }
}

extension FakeKeystore {
    static func make(
        wallets: [Wallet] = [],
        recentlyUsedWallet: Wallet? = .none
    ) -> FakeKeystore {
        return FakeKeystore(
            wallets: wallets,
            recentlyUsedWallet: recentlyUsedWallet
        )
    }
}
