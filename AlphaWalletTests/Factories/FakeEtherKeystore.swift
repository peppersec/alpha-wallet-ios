// Copyright SIX DAY LLC. All rights reserved.

import Foundation
@testable import AlphaWallet
import TrustKeystore
import KeychainSwift
import Result

class FakeEtherKeystore: EtherKeystore {
    convenience init() {
        let uniqueString = NSUUID().uuidString
        try! self.init(keychain: KeychainSwift(keyPrefix: "fake" + uniqueString), userDefaults: UserDefaults.test)
    }

    override func createAccount() -> EthereumAccount {
        return .make()
    }
}
