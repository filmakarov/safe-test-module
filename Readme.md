# Safe Test Module
Test Module - A test module that allows accounts that are not related to the Safe to withdraw a predetermined amount of a specific token using EIP-712 signature issued by the Safe owner.

## Safety considerations
This design is unsafe! In the "Solidity Challenge" document I received via email it is stated, that "Now they can generate a signature which allows _ANYONE_ to withdraw Unicorn tokens from their Safe."

To allow _ANYONE_ use the signature, there should be no `spender` address in the Allowance.
With this design the signature can be picked up from mempool and the transaction can be frontrunned.

Better way to implement this module would be with specifiyng the `spender` for each Allowance, 
so the allowance can only be used by a `spender` specified by a Safe owner when signing the data hash. 
Thus frontrunning will not be an issue. 