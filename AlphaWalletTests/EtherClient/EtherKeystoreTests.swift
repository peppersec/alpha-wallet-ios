// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet
import TrustKeystore
import KeychainSwift
import BigInt

class EtherKeystoreTests: XCTestCase {
    
    func testInitialization() {
        let keystore = FakeEtherKeystore()

        XCTAssertNotNil(keystore)
        XCTAssertEqual(false, keystore.hasWallets)
    }

//    func testCreateWallet() {
//        let keystore = FakeEtherKeystore()
//        let account = keystore.createAccount()
//        XCTAssertEqual(1, keystore.wallets.count)
//    }

    func testEmptyPassword() {
        let keystore = try! LegacyFileBasedKeystore()
        let password = keystore.getPassword(for: .make())
        XCTAssertNil(password)
    }

    func testImport() {
        let keystore = FakeEtherKeystore()
        let expectation = self.expectation(description: "completion block called")
        keystore.importWallet(type: .keystore(string: TestKeyStore.keystore, password: TestKeyStore.password)) { result in
            expectation.fulfill()
            switch result {
            case .success(let wallet):
                XCTAssertEqual("0x5E9c27156a612a2D516C74c7a80af107856F8539", wallet.address.eip55String)
                XCTAssertEqual(1, keystore.wallets.count)
            case .failure:
                XCTFail()
            }
            return
        }
        wait(for: [expectation], timeout: 0.01)
    }

    func testImportDuplicate() {
        let keystore = FakeEtherKeystore()
        var address: AlphaWallet.Address? = nil
        let expectation1 = self.expectation(description: "completion block called")
        let expectation2 = self.expectation(description: "completion block called")
        let expectations = [expectation1, expectation2]
        keystore.importWallet(type: .keystore(string: TestKeyStore.keystore, password: TestKeyStore.password)) { result in
            expectation1.fulfill()
            switch result {
            case .success(let wallet):
                address = wallet.address
            case .failure:
                break
            }
        }
        keystore.importWallet(type: .keystore(string: TestKeyStore.keystore, password: TestKeyStore.password)) { result in
            expectation2.fulfill()
            switch result {
            case .success:
                return XCTFail()
            case .failure(let error):
                if case KeystoreError.duplicateAccount = error {
                    XCTAssertEqual("0x5E9c27156a612a2D516C74c7a80af107856F8539", address?.eip55String)
                    XCTAssertEqual(1, keystore.wallets.count)
                } else {
                    XCTFail()
                }
            }
            return
        }
        wait(for: expectations, timeout: 0.01)
    }

    func testImportFailInvalidPassword() {
        let keystore = FakeEtherKeystore()
        keystore.importWallet(type: .keystore(string: TestKeyStore.keystore, password: "invalidPassword")) { result in
            switch result {
            case .success:
                XCTFail()
            case .failure:
                XCTAssertTrue(true)
            }
        }
        XCTAssertEqual(0, keystore.wallets.count)
    }


//    func testExport() {
//        let keystore = FakeEtherKeystore()
//        let password = "test"

//        let account = keystore.createAccount()

//        keystore.export(account: account, newPassword: password) { result in
//            switch result {
//            case .success:
//                return XCTAssertTrue(true)
//            case .failure:
//                return XCTFail()
//            }
//        }
//        XCTFail()
//    }

//    func testRecentlyUsedAccount() {
//        let keystore = FakeEtherKeystore()

//        XCTAssertNil(keystore.recentlyUsedWallet)

//        let account = Wallet(type: .real(keystore.createAccount()))

//        keystore.recentlyUsedWallet = account

//        XCTAssertEqual(account, keystore.recentlyUsedWallet)

//        keystore.recentlyUsedWallet = nil

//        XCTAssertNil(keystore.recentlyUsedWallet)
//    }

//    func testDeleteAccount() {
//        let keystore = FakeEtherKeystore()
//        let wallet = Wallet(type: .real(keystore.createAccount()))

//        XCTAssertEqual(1, keystore.wallets.count)

//        let result = keystore.delete(wallet: wallet)

//        guard case .success = result else {
//            return XCTFail()
//        }

//        XCTAssertEqual(0, keystore.wallets.count)
//    }

//    func testConvertPrivateKeyToKeyStore() {
//        let passphrase = "MyHardPassword!"
//        let keystore = FakeEtherKeystore()
//        let result = (try! LegacyFileBasedKeystore()).convertPrivateKeyToKeystoreFile(privateKey: Data(hexString: TestKeyStore.testPrivateKey)!, passphrase: passphrase)
//        switch result {
//        case .success(let dict):
//            keystore.importWallet(type: .keystore(string: dict.jsonString!, password: passphrase)) { result in
//                switch result {
//                case .success(let wallet):
//                    XCTAssertTrue(wallet.address.sameContract(as: "0x95fc7381950Db9d7ab116099c4E84AFD686e3e9C"))
//                    XCTAssertEqual(1, keystore.wallets.count)
//                case .failure:
//                    XCTFail()
//                }
//            }
//        case .failure:
//            XCTFail()
//        }
//    }

    func testSignPersonalMessage() {
        let keystore = FakeEtherKeystore()
        let expectation = self.expectation(description: "completion block called")

        keystore.importWallet(type: .privateKey(privateKey: Data(hexString: "0x4c0883a69102937d6231471b5dbb6204fe5129617082792ae468d01a3f362318")!)) { result in
            expectation.fulfill()
            switch result {
            case .success(let wallet):
                let account = keystore.getAccount(for: wallet.address)!
                let signResult = keystore.signPersonalMessage("Some data".data(using: .utf8)!, for: account)
                switch signResult {
                case .success(let data):
                    let expected = Data(hexString: "0xb91467e570a6466aa9e9876cbcd013baba02900b8979d43fe208a4a4f339f5fd6007e74cd82e037b800186422fc2da167c747ef045e5d18a5f5d4300f8e1a0291c")
                    XCTAssertEqual(expected, data)
                case .failure:
                    XCTFail()
                }
            case .failure:
                XCTFail()
            }
            return
        }
        wait(for: [expectation], timeout: 0.01)

        // web3.eth.accounts.sign('Some data', '0x4c0883a69102937d6231471b5dbb6204fe5129617082792ae468d01a3f362318');
        // expected:
        // message: 'Some data',
        // messageHash: '0x1da44b586eb0729ff70a73c326926f6ed5a25f5b056e7f47fbc6e58d86871655',
        // v: '0x1c',
        // r: '0xb91467e570a6466aa9e9876cbcd013baba02900b8979d43fe208a4a4f339f5fd',
        // s: '0x6007e74cd82e037b800186422fc2da167c747ef045e5d18a5f5d4300f8e1a029',
        // signature: '0xb91467e570a6466aa9e9876cbcd013baba02900b8979d43fe208a4a4f339f5fd6007e74cd82e037b800186422fc2da167c747ef045e5d18a5f5d4300f8e1a0291c'
    }

    func testSignMessage() {
        let keystore = FakeEtherKeystore()

        keystore.importWallet(type: .privateKey(privateKey: Data(hexString: "0x4c0883a69102937d6231471b5dbb6204fe5129617082792ae468d01a3f362318")!)) { result in
            switch result {
            case .success(let wallet):
                let account = keystore.getAccount(for: wallet.address)!
                let signResult = keystore.signPersonalMessage("0x3f44c2dfea365f01c1ada3b7600db9e2999dfea9fe6c6017441eafcfbc06a543".data(using: .utf8)!, for: account)
                switch signResult {
                case .success(let data):
                    let expected = Data(hexString: "0x619b03743672e31ad1d7ee0e43f6802860082d161acc602030c495a12a68b791666764ca415a2b3083595aee448402874a5a376ea91855051e04c7b3e4693d201c")
                    XCTAssertEqual(expected, data)
                case .failure:
                    XCTFail()
                }
            case .failure:
                XCTFail()
            }
            return
        }
    }

    func testAddWatchAddress() {
        let keystore = FakeEtherKeystore()
        let address: AlphaWallet.Address = .make()
        keystore.importWallet(type: ImportType.watch(address: address)) { _  in }

        XCTAssertEqual(1, keystore.wallets.count)
        XCTAssertEqual(address, keystore.wallets[0].address)
    }

    func testDeleteWatchAddress() {
        let keystore = FakeEtherKeystore()
        let address: AlphaWallet.Address = .make()

        // TODO. Move this into sync calls
        keystore.importWallet(type: ImportType.watch(address: address)) { result  in
            switch result {
            case .success(let wallet):
                XCTAssertEqual(1, keystore.wallets.count)
                XCTAssertEqual(address, keystore.wallets[0].address)

                let _ = keystore.delete(wallet: wallet)

                XCTAssertEqual(0, keystore.wallets.count)
            case .failure:
                XCTFail()
            }
        }

        XCTAssertEqual(0, keystore.wallets.count)
    }
}
