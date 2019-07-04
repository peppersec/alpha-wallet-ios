// Copyright SIX DAY LLC. All rights reserved.

import BigInt
import Foundation
import Result
import KeychainSwift

enum EtherKeystoreError: LocalizedError {
    case protectionDisabled
}

open class EtherKeystore: Keystore {
    private struct Keys {
        static let recentlyUsedAddress: String = "recentlyUsedAddress"
        static let watchAddresses = "watchAddresses"
        static let ethereumAddressesWithPrivateKeys = "ethereumAddressesWithPrivateKeys"
        static let ethereumRawPrivateKeyPrefix = "ethereumRawPrivateKey-"
    }

    private let keychain: KeychainSwift
    private let defaultKeychainAccess: KeychainSwiftAccessOptions = .accessibleWhenUnlockedThisDeviceOnly
    private let userDefaults: UserDefaults

    private var watchAddresses: [String] {
        set {
            let data = NSKeyedArchiver.archivedData(withRootObject: newValue)
            return userDefaults.set(data, forKey: Keys.watchAddresses)
        }
        get {
            guard let data = userDefaults.data(forKey: Keys.watchAddresses) else { return [] }
            return NSKeyedUnarchiver.unarchiveObject(with: data) as? [String] ?? []
        }
    }

    private var ethereumAddressesWithPrivateKeys: [String] {
        set {
            let data = NSKeyedArchiver.archivedData(withRootObject: newValue)
            return userDefaults.set(data, forKey: Keys.ethereumAddressesWithPrivateKeys)
        }
        get {
            guard let data = userDefaults.data(forKey: Keys.ethereumAddressesWithPrivateKeys) else { return [] }
            return NSKeyedUnarchiver.unarchiveObject(with: data) as? [String] ?? []
        }
    }

    var hasWallets: Bool {
        return !wallets.isEmpty
    }

    var wallets: [Wallet] {
        let watchAddresses = self.watchAddresses.compactMap { AlphaWallet.Address(string: $0) }.map { Wallet(type: .watch($0)) }
        let ownedAddresses = self.ethereumAddressesWithPrivateKeys.compactMap { AlphaWallet.Address(string: $0) }.map { Wallet(type: .real(.init(address: $0))) }
        return ownedAddresses + watchAddresses
    }

    var hasMigratedFromKeystoreFiles: Bool {
        return userDefaults.data(forKey: Keys.ethereumAddressesWithPrivateKeys) != nil
    }

    var recentlyUsedWallet: Wallet? {
        set {
            keychain.set(newValue?.address.eip55String ?? "", forKey: Keys.recentlyUsedAddress, withAccess: defaultKeychainAccess)
        }
        get {
            guard let address = keychain.get(Keys.recentlyUsedAddress) else { return nil }
            return wallets.filter { $0.address.sameContract(as: address) }.first
        }
    }

    //TODO improve
    static var current: Wallet? {
        do {
            return try EtherKeystore().recentlyUsedWallet
        } catch {
            return .none
        }
    }

    public init(
            keychain: KeychainSwift = KeychainSwift(keyPrefix: Constants.keychainKeyPrefix),
            userDefaults: UserDefaults = UserDefaults.standard
    ) throws {
        if !UIApplication.shared.isProtectedDataAvailable {
            throw EtherKeystoreError.protectionDisabled
        }
        self.keychain = keychain
        self.keychain.synchronizable = false
        self.userDefaults = userDefaults
    }

    // Async
    func createAccount(completion: @escaping (Result<EthereumAccount, KeystoreError>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let strongSelf = self else { return }
            let account = strongSelf.createAccount()
            DispatchQueue.main.async {
                completion(.success(account))
            }
        }
    }

    func importWallet(type: ImportType, completion: @escaping (Result<Wallet, KeystoreError>) -> Void) {
        switch type {
        case .keystore(let json, let password):
            guard let keystore = try? LegacyFileBasedKeystore() else { return completion(.failure(.failedToExportPrivateKey)) }
            keystore.getPrivateKeyFromKeystoreFile(json: json, password: password) { result in
                switch result {
                case .success(let privateKey):
                    self.importWallet(type: .privateKey(privateKey: privateKey), completion: completion)
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        case .privateKey(let privateKey):
            let address = AlphaWallet.Address(fromPrivateKey: privateKey)
            let hasEthereumAddressAlready = wallets.map({ $0.address }).contains { $0.sameContract(as: address) }
            guard !hasEthereumAddressAlready else { return completion(.failure(.duplicateAccount)) }
            keychain.set(privateKey.hex(), forKey: "\(Keys.ethereumRawPrivateKeyPrefix)\(address.eip55String)", withAccess: defaultKeychainAccess)
            addToListOfOwnedEthereumAddresses(address)
            completion(.success(Wallet(type: .real(.init(address: address)))))
        case .mnemonic:
            break
        case .watch(let address):
            guard !watchAddresses.contains(where: { address.sameContract(as: $0) }) else { return completion(.failure(.duplicateAccount)) }
            watchAddresses = [watchAddresses, [address.eip55String]].flatMap { $0 }
            completion(.success(Wallet(type: .watch(address))))
        }
    }

    private func addToListOfOwnedEthereumAddresses(_ address: AlphaWallet.Address) {
        let updatedOwnedAddresses = Array(Set(ethereumAddressesWithPrivateKeys + [address.eip55String]))
        ethereumAddressesWithPrivateKeys = updatedOwnedAddresses
    }

    func createAccount() -> EthereumAccount {
        return EthereumAccount(address: AlphaWallet.Address(string: "0x1")!)
    }

    func export(account: EthereumAccount, newPassword: String, completion: @escaping (Result<String, KeystoreError>) -> Void) {
        guard let key = getPrivateKey(forAccount: account) else { return completion(.failure(.failedToDecryptKey)) }
        (try? LegacyFileBasedKeystore())?.export(privateKey: key, newPassword: newPassword, completion: completion)
    }

    @discardableResult func delete(wallet: Wallet) -> Result<Void, KeystoreError> {
        switch wallet.type {
        case .real(let account):
            keychain.delete("\(Keys.ethereumRawPrivateKeyPrefix)\(wallet.address.eip55String)")
            ethereumAddressesWithPrivateKeys = ethereumAddressesWithPrivateKeys.filter { $0 != account.address.eip55String }
        case .watch(let address):
            watchAddresses = watchAddresses.filter { $0 != address.eip55String }
        }
        (try? LegacyFileBasedKeystore())?.delete(wallet: wallet)
        return .success(())
    }

    func delete(wallet: Wallet, completion: @escaping (Result<Void, KeystoreError>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let strongSelf = self else { return }
            let result = strongSelf.delete(wallet: wallet)
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    func signPersonalMessage(_ message: Data, for account: EthereumAccount) -> Result<Data, KeystoreError> {
        let prefix = "\u{19}Ethereum Signed Message:\n\(message.count)".data(using: .utf8)!
        return signMessage(prefix + message, for: account)
    }

    func signHash(_ hash: Data, for account: EthereumAccount) -> Result<Data, KeystoreError> {
        guard let key = getPrivateKey(forAccount: account) else { return .failure(.accountNotFound) }
        do {
            var data = try EthereumSigner().sign(hash: hash, withPrivateKey: key)
            // TODO: Make it configurable, instead of overriding last byte.
            data[64] += 27
            return .success(data)
        } catch {
            return .failure(KeystoreError.failedToSignMessage)
        }
    }

    func signTypedMessage(_ datas: [EthTypedData], for account: EthereumAccount) -> Result<Data, KeystoreError> {
        let schemas = datas.map { $0.schemaData }.reduce(Data(), { $0 + $1 }).sha3(.keccak256)
        let values = datas.map { $0.typedData }.reduce(Data(), { $0 + $1 }).sha3(.keccak256)
        let combined = (schemas + values).sha3(.keccak256)
        return signHash(combined, for: account)
    }

    func signMessage(_ message: Data, for account: EthereumAccount) -> Result<Data, KeystoreError> {
        return signHash(message.sha3(.keccak256), for: account)
    }

    func signMessageBulk(_ data: [Data], for account: EthereumAccount) -> Result<[Data], KeystoreError> {
        guard let key = getPrivateKey(forAccount: account) else { return .failure(.accountNotFound) }

        do {
            var messageHashes = [Data]()
            for i in 0...data.count - 1 {
                let hash = data[i].sha3(.keccak256)
                messageHashes.append(hash)
            }
            var data = try EthereumSigner().signHashes(messageHashes, withPrivateKey: key)
            // TODO: Make it configurable, instead of overriding last byte.
            for i in 0...data.count - 1 {
                data[i][64] += 27
            }
            return .success(data)
        } catch {
            return .failure(KeystoreError.failedToSignMessage)
        }
    }

    func signMessageData(_ message: Data?, for account: EthereumAccount) -> Result<Data, KeystoreError> {
        guard let hash = message?.sha3(.keccak256) else { return .failure(KeystoreError.failedToSignMessage) }
        guard let key = getPrivateKey(forAccount: account) else { return .failure(.accountNotFound) }
        do {
            var data = try EthereumSigner().sign(hash: hash, withPrivateKey: key)
            data[64] += 27
            return .success(data)
        } catch {
            return .failure(KeystoreError.failedToSignMessage)
        }
    }

    func signTransaction(_ transaction: UnsignedTransaction) -> Result<Data, KeystoreError> {
        let signer: Signer
        if transaction.server.chainID == 0 {
            signer = HomesteadSigner()
        } else {
            signer = EIP155Signer(server: transaction.server)
        }

        do {
            let hash = signer.hash(transaction: transaction)
            guard let key = getPrivateKey(forAccount: transaction.account) else { return .failure(.accountNotFound) }
            let signature = try EthereumSigner().sign(hash: hash, withPrivateKey: key)
            let (r, s, v) = signer.values(transaction: transaction, signature: signature)
            let data = RLP.encode([
                transaction.nonce,
                transaction.gasPrice,
                transaction.gasLimit,
                transaction.to?.data ?? Data(),
                transaction.value,
                transaction.data,
                v, r, s,
            ])!
            return .success(data)
        } catch {
            return .failure(.failedToSignTransaction)
        }
    }

    func getAccount(for address: AlphaWallet.Address) -> EthereumAccount? {
        return .init(address: address)
    }

    private func getPrivateKey(forAccount account: EthereumAccount) -> Data? {
        return keychain.get("\(Keys.ethereumRawPrivateKeyPrefix)\(account.address.eip55String)").flatMap { Data(hexString: $0) }
    }
}
