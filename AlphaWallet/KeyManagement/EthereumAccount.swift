// Copyright © 2019 Stormbird PTE. LTD.

import Foundation

struct EthereumAccount: Hashable {
    var address: AlphaWallet.Address

    init(address: AlphaWallet.Address) {
        self.address = address
    }

    public var hashValue: Int {
        return address.hashValue
    }

    public static func == (lhs: EthereumAccount, rhs: EthereumAccount) -> Bool {
        return lhs.address == rhs.address
    }
}
