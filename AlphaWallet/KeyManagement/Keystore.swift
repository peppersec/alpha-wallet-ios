// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import Result

protocol Keystore {
    var hasWallets: Bool { get }
    var wallets: [Wallet] { get }
    var recentlyUsedWallet: Wallet? { get set }
    static var current: Wallet? { get }
    @available(iOS 10.0, *)
    func createAccount(completion: @escaping (Result<EthereumAccount, KeystoreError>) -> Void)
    func importWallet(type: ImportType, completion: @escaping (Result<Wallet, KeystoreError>) -> Void)
    func createAccount() -> EthereumAccount
    func export(account: EthereumAccount, newPassword: String, completion: @escaping (Result<String, KeystoreError>) -> Void)
    func delete(wallet: Wallet, completion: @escaping (Result<Void, KeystoreError>) -> Void)
    func signPersonalMessage(_ data: Data, for account: EthereumAccount) -> Result<Data, KeystoreError>
    func signTypedMessage(_ datas: [EthTypedData], for account: EthereumAccount) -> Result<Data, KeystoreError>
    func signMessage(_ data: Data, for account: EthereumAccount) -> Result<Data, KeystoreError>
    func signHash(_ data: Data, for account: EthereumAccount) -> Result<Data, KeystoreError>
    func signTransaction(_ signTransaction: UnsignedTransaction) -> Result<Data, KeystoreError>
}
