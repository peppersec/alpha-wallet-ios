// Copyright SIX DAY LLC. All rights reserved.

import BigInt
import Foundation
import Result
import KeychainSwift
import CryptoSwift
import TrustKeystore

enum FileBasedKeystoreError: LocalizedError {
    case protectionDisabled
}

class LegacyFileBasedKeystore {
    private let keychain: KeychainSwift
    private let datadir = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
    private let keyStore: KeyStore
    private let defaultKeychainAccess: KeychainSwiftAccessOptions = .accessibleWhenUnlockedThisDeviceOnly
    private let userDefaults: UserDefaults

    let keystoreDirectory: URL

    public init(
        keychain: KeychainSwift = KeychainSwift(keyPrefix: Constants.keychainKeyPrefix),
        keyStoreSubfolder: String = "/keystore",
        userDefaults: UserDefaults = UserDefaults.standard
    ) throws {
        if !UIApplication.shared.isProtectedDataAvailable {
            throw FileBasedKeystoreError.protectionDisabled
        }
        self.keystoreDirectory = URL(fileURLWithPath: datadir + keyStoreSubfolder)
        self.keychain = keychain
        self.keychain.synchronizable = false
        self.keyStore = try KeyStore(keydir: keystoreDirectory)
        self.userDefaults = userDefaults
    }

    func getPrivateKeyFromKeystoreFile(json: String, password: String, completion: @escaping (Result<Data, KeystoreError>) -> Void) {
        let newPassword = PasswordGenerator.generateRandom()
        guard let data = json.data(using: .utf8) else { return completion(.failure(.failedToDecryptKey)) }
        guard let key = try? JSONDecoder().decode(KeystoreKey.self, from: data) else { return completion(.failure(.failedToImportPrivateKey)) }
        guard let privateKey = try? key.decrypt(password: password) else { return completion(.failure(.failedToDecryptKey)) }
        return completion(.success(privateKey))
    }

    func export(privateKey: Data, newPassword: String, completion: @escaping (Result<String, KeystoreError>) -> Void) {
        switch convertPrivateKeyToKeystoreFile(privateKey: privateKey, passphrase: newPassword) {
        case .success(let dict):
            if let jsonString = dict.jsonString {
                completion(.success(jsonString))
            } else {
                completion(.failure(.failedToExportPrivateKey))
            }
        case .failure(let error):
            completion(.failure(.failedToExportPrivateKey))
        }
    }

    private func exportPrivateKey(account: Account) -> Result<Data, KeystoreError> {
        guard let password = getPassword(for: account) else { return .failure(KeystoreError.accountNotFound) }
        do {
            let privateKey = try keyStore.exportPrivateKey(account: account, password: password)
            return .success(privateKey)
        } catch {
            return .failure(KeystoreError.failedToExportPrivateKey)
        }
    }

    @discardableResult func delete(wallet: Wallet) -> Result<Void, KeystoreError> {
        switch wallet.type {
        case .real(let account):
            guard let account = getAccount(for: account.address) else {
                return .failure(.accountNotFound)
            }

            guard let password = getPassword(for: account) else {
                return .failure(.failedToDeleteAccount)
            }

            do {
                try keyStore.delete(account: account, password: password)
                return .success(())
            } catch {
                return .failure(.failedToDeleteAccount)
            }
        case .watch(let address):
            return .success(())
        }
    }

    func getPassword(for account: Account) -> String? {
        return keychain.get(account.address.eip55String.lowercased())
    }

    @discardableResult private func setPassword(_ password: String, for account: Account) -> Bool {
        return keychain.set(password, forKey: account.address.eip55String.lowercased(), withAccess: defaultKeychainAccess)
    }

    func getAccount(for address: AlphaWallet.Address) -> Account? {
        return getAccount(for: .init(address: address))
    }

    func getAccount(for address: Address) -> Account? {
        return keyStore.account(for: address)
    }

    func convertPrivateKeyToKeystoreFile(privateKey: Data, passphrase: String) -> Result<[String: Any], KeystoreError> {
        do {
            let key = try KeystoreKey(password: passphrase, key: privateKey)
            let data = try JSONEncoder().encode(key)
            let dict = try JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]
            return .success(dict)
        } catch {
            return .failure(KeystoreError.failedToImportPrivateKey)
        }
    }

    func migrateKeystoreFilesToRawPrivateKeysInKeychain() {
        guard let etherKeystore = try? EtherKeystore() else { return }
        guard !etherKeystore.hasMigratedFromKeystoreFiles else { return }

        for each in keyStore.accounts {
            switch exportPrivateKey(account: each) {
            case .success(let privateKey):
                etherKeystore.importWallet(type: .privateKey(privateKey: privateKey), completion: { _ in })
            case .failure:
                break
            }
        }
    }
}
