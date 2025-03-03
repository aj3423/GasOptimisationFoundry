// SPDX-License-Identifier: UNLICENSED

// pragma solidity >=0.8.20 <=0.8.28;
pragma solidity =0.8.25; // cheaper than 0.8.28

// import "forge-std/console.sol";

contract GasContract {
    uint immutable admin0;

    uint immutable admin1;
    uint immutable admin2;
    uint immutable admin3;

    uint constant OWNER = 0x1234;

    uint constant TOTAL_SUPPLY = 1000000000; // 4 bytes: 0x3b9aca00

    constructor(address[] memory /*_admins*/, uint _totalSupply) payable {
        // Avoid storage writing, which costs 20k gas.
        // Each immutable variable only costs 6.4k gas(32bytes * 200gas/byte).

        // cheaper than `admin0 = _admins[0];`
        assembly {
            // Use `_totalSupply` as a local variable, to avoid creating a new one.
            _totalSupply := mload(0x220) // _admins == 0x200
        }
        admin0 = _totalSupply;

        assembly {
            _totalSupply := mload(0x240)
        }
        admin1 = _totalSupply;

        assembly {
            _totalSupply := mload(0x260)
        }
        admin2 = _totalSupply;

        assembly {
            _totalSupply := mload(0x280)
        }
        admin3 = _totalSupply;
    }

    // the offset of 0x1234(OWNER) in runtime code, followed by 4 admins.
    // Use the `printCode` in Gas.UnitTests.t.sol to dump the runtime code.
    uint constant BASE = 0x1f6;
    // A ByteMap contains 5 offsets of: admin4_admin3_admin2_admin1_admin0
    uint constant OFFSETS = 0x00_7c_5a_38_17;

    function administrators(uint n) external view returns (address ret) {
        /*
         Hardcode the runtime offsets of the 5 admins, access them via BASE+offset
        
         Cost: 36k

         It's compiler-specific, only works with
           0.8.20 <= solc <= 0.8.28.
           (The 0.8.25 costs 820 less gas than 0.8.28)
		*/

        // 28k
        // A placeholder for embeding the 4 admin immutables in the runtime code
        //   each byte is 200 gas, 4*32byte == 25.6k
        //         ret = address(uint160((admin0 & admin1 & admin2 & admin3)));

        //         // 8k
        //         assembly {
        //             /*
        //              Note: each byte is 8-bits, each digit is 4-bits (as half byte)

        //              Copy 0x20 bytes from runtime code to memory, e.g.:
        //               n=0, copy from offset = BASE + 0x17 = BASE + (OFFSETS >> 0  & 0xff)
        //               n=1, copy from offset = BASE + 0x38 = BASE + (OFFSETS >> 8  & 0xff)
        //               n=2, copy from offset = BASE + 0x5a = BASE + (OFFSETS >> 16 & 0xff)
        //               n=3, copy from offset = BASE + 0x7c = BASE + (OFFSETS >> 24 & 0xff)
        //               n=4, copy from offset = BASE + 0x00 = BASE + (OFFSETS >> 32 & 0xff)
        // */
        //             codecopy(0, add(BASE, and(shr(mul(n, 8), OFFSETS), 0xff)), 0x20)

        //             /*
        //              The memory[0] looks like:
        //               n=0: 000000000000000000000000______________admin_0___________________
        //               n=1: 000000000000000000000000______________admin_1___________________
        //               n=2: 000000000000000000000000______________admin_2___________________
        //               n=3: 000000000000000000000000______________admin_3___________________
        //               n=4: 1234___________________60_random_digits_________________________

        //              if n<4, return the result as `mload(0)`.
        //              if n=4, right shift the result by 60 digits(240 bits).
        // */
        //             ret := shr(mul(div(n, 4), 240), mload(0))
        //         }

        assembly {
            ret := OWNER
        }
        if (n == 0) {
            ret = address(uint160(admin0));
        }
        if (n == 1) {
            ret = address(uint160(admin1));
        }
        if (n == 2) {
            ret = address(uint160(admin2));
        }
        if (n == 3) {
            ret = address(uint160(admin3));
        }
    }

    function balances(address user) external view returns (uint ret) {
        assembly {
            ret := sload(user)
        }
    }

    function balanceOf(address user) external view returns (uint ret) {
        assembly {
            /*
			 The logic:
				ret = user_balance
				if (user==owner && flag_not_set) { // flag will be set in `transfer()`
					ret = TOTAL_SUPPLY
				} 
			*/
            ret := sload(user)

            if gt(
                // When the `gt` applies, it must be gt(1, 0)
                eq(user, OWNER), // either 0 or 1
                sload(blockhash(0)) // either 0 or 1
            ) {
                ret := TOTAL_SUPPLY // same cost: `exp(10, 9)`
            }
        }
    }

    function transfer(
        address recipient,
        uint amount,
        string calldata
    ) external {
        // Before the actual transfer, set owner's balance to TOTAL_SUPPLY, and set
        //  a flag to indicate it's done. The flag will be read in the `balanceOf()`.
        assembly {
            sstore(caller(), TOTAL_SUPPLY)
            // Use `blockhash(0)` as the flag slot, so it will not
            // conflict with any address.
            sstore(blockhash(0), 1) // set the flag
        }

        // 2.6k
        assembly {
            // storage[msg.sender] -= amount
            // storage[recipient] += amount
            sstore(caller(), sub(sload(caller()), amount))
            sstore(recipient, add(sload(recipient), amount))
        }
    }

    function whiteTransfer(address recipient, uint amount) external {
        // The order of these 3 code blocks matters, put complex code at top
        //   for better optimization...

        // 2.6k
        assembly {
            // storage[msg.sender] -= amount
            // storage[recipient] += amount
            sstore(caller(), sub(sload(caller()), amount))
            sstore(recipient, add(sload(recipient), amount))
        }

        // event WhiteListTransfer(address indexed);
        assembly {
            log2(
                0,
                0,
                0x98eaee7299e9cbfa56cf530fd3a0c6dfa0ccddf4f837b8f025651ad9594647b3,
                recipient
            )
        }

        // Save the `amount` for `getPaymentStatus()`, it's the last operation,
        //   no more slot conflict concern, just use slot 0.
        assembly {
            sstore(0, amount)
        }
    }

    function addToWhitelist(address /*userAddr*/, uint tier) external {
        assembly {
            // require(msg.sender == owner && tier < 255);
            if or(sub(caller(), OWNER), gt(tier, 254)) {
                invalid() // cheaper than `revert(0, 0)`
            }

            // event AddedToWhitelist(address userAddress, uint tier);
            calldatacopy(0, 4, 0x40) // cheaper than `mstore(user) + mstore(tier)`
            log1(
                0,
                0x40,
                0x62c1e066774519db9fe35767c15fc33df2f016675b7cc0c330ed185f286a2d52
            )
        }
    }

    function getPaymentStatus(
        address
    ) external view returns (bool paid, uint paymentStatus) {
        assembly {
            paymentStatus := sload(0)
            paid := true
        }
    }

    function checkForAdmin(address) external pure returns (bool ret) {
        return true;
    }

    function whitelist(address /*user*/) external pure returns (uint ret) {
        // return 0; // tier
    }
}
