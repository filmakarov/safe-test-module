// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.8.0 <0.9.0;

import "@safe/common/Enum.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

interface IGnosisSafe {
    /**
    * @dev Allows a Module to execute a Safe transaction without any further confirmations.
    * @param to Destination address of module transaction.
    * @param value Ether value of module transaction.
    * @param data Data payload of module transaction.
    * @param operation Operation type of module transaction.
    */
    function execTransactionFromModule(address to, uint256 value, bytes calldata data, Enum.Operation operation)
        external
        returns (bool success);

    /**
     * @dev Checks whether the signature provided is valid for the provided data, hash. Will revert otherwise.
     * @param dataHash Hash of the data (could be either a message hash or transaction hash)
     * @param data That should be signed (this is passed to an external validator contract)
     * @param signatures Signature data that should be verified. Can be ECDSA signature, contract signature (EIP-1271) or approved hash.
     * @param requiredSignatures Amount of required valid signatures.
     */
    function checkNSignatures(bytes32 dataHash, bytes memory data, bytes memory signatures, uint256 requiredSignatures) 
    external 
    view;
}

/// @title Test Module - A test module that allows accounts that are not related to the Safe to withdraw
///        a predetermined amount of a specific token using EIP-712 signature issued by the Safe owner.
/// @author Filipp Makarov - <filippvmakarov@gmail.com>
/// @dev This design is unsafe! In the "Solidity Challenge" document I received via email it is stated, that
///      "Now they can generate a signature which allows ANYONE to withdraw Unicorn tokens from their Safe."
///      To allow ANYONE use the signature, there should be no `spender` address in the Allowance.
///      With this design the signature can be picked up from mempool and the transaction can be frontrunned.
///      Better way to implement this module would be with specifiyng the `spender` for each Allowance, 
///      so the allowance can only be used by a `spender` specified by a Safe owner when signing the data hash. 
///      Thus frontrunning will not be an issue. 

contract TestModule is EIP712 {

    bytes32 private constant ALLOWANCE_TYPEHASH = keccak256(bytes("Allowance(uint256 nonce,uint256 amount,uint256 deadline)"));

    uint256 private nonce;
    address public managedToken;
    IGnosisSafe public safe;

    struct Allowance {
        uint256 nonce;
        uint256 amount;
        uint256 deadline;
    }

    /**
     * @dev Generates data hash, that owner will sign
     * @param _managedToken token to be transferred with this Module
     * @param _safeAddress Safe that this module is working with
     */
    constructor(address _managedToken, address _safeAddress) EIP712("Test Module", "1") {
        managedToken = _managedToken;
        safe = IGnosisSafe(_safeAddress);
    }

    /**
     * @dev Generates data hash, that owner will sign
     * @param amount amount of token to be allowed for withdrawal
     * @param deadline timestamp, after which the signature will be expired and won't allow to withdraw tokens
     * @return bytes32 typed data hash, signed according to EIP-712
     */
    function generateAllowanceDataHash(uint256 amount, uint256 deadline) public view returns (bytes32) {
        bytes32 allowanceHash = keccak256(abi.encode(
            ALLOWANCE_TYPEHASH,
            nonce,
            amount,
            deadline
        ));
        return _hashTypedDataV4(allowanceHash);
    }

     /**
     * @dev Withdraws tokens from Safe and sends to the caller.
     * @param amount amount of token to be allowed for withdrawal
     * @param deadline timestamp, after which the signature will be expired and won't allow to withdraw tokens
     * @param to beneficiary. This address will receive tokens.
     * @param r part of an ECDSA signature (x-coordinate of a random point)
     * @param s part of an ECDSA signature (signature proof)
     * @param v part of an ECDSA signature (recovery id)
     */
    function withdrawToken(uint256 amount, uint256 deadline, address to, bytes32 r, bytes32 s, uint8 v) public {
        require(block.timestamp <= deadline, "Signature expired");
        safe.checkNSignatures(generateAllowanceDataHash(amount, deadline), "", abi.encodePacked(r,s,v), 1);
        nonce++;
        bytes memory data = abi.encodeWithSignature("transfer(address,uint256)", to, amount);
        require(safe.execTransactionFromModule(managedToken, 0, data, Enum.Operation.Call), "Could not execute token transfer");
    }

}