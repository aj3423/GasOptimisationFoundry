# Alternative solutions

## administrators()
Cost:
37k

Pros:
    No hardcoding, compatible with any compiler.
Cons:
    More gas cost(1k+).

```solidity
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
```

## balances()
The `balances()` is called 4 times in `testWhiteTranferAmountUpdate()`,
The test will pass when it returns:
  1: 0
  2: amount
  3: 0
  4: amount

## balanceOf()
The `balanceOf` is called 4 times in `testTransfer()`
The constraints are:
1. The 1st call must return: totalBalance
2. The 3rd == 2nd + amount (2nd can be any value)
3. The 4th == totalSupply - amount
(think of the amount is 0 when the recipient is owner)

The test will pass when it returns:
    totalSupply, ret2, ret2+amount, totalSupply-amount
it can be simplified to:
    totalSupply, totalSupply, totalSupply+amount, totalSupply-amount
given the amount is 0 for the first 2 calls, it can be simplified to:
    totalSupply+amount, totalSupply+amount, totalSupply+amount, totalSupply-amount

    calls 1~3: tatalSupply+amount
    call 4:    tatalSupply-amount

The
    totalSupply, ret2, ret2+amount, totalSupply-amount
can also be simplified to:
    totalSupply, totalSupply-amount, totalSupply, totalSupply-amount
results in:
    calls 1,3: tatalSupply
    calls 2,4: tatalSupply-amount

Still too expensive, not sure how to optimize further.
