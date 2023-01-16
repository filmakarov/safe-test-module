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

contract TestModule is EIP712 {

    bytes32 private constant ALLOWANCE_TYPEHASH = keccak256(bytes("Allowance(uint256 nonce,uint256 amount,uint256 deadline)"));

    uint256 private nonce;
    address managedToken;
    IGnosisSafe safe;

    struct Allowance {
        uint256 nonce;
        uint256 amount;
        uint256 deadline;
    }

    constructor(address _managedToken, address _safeAddress) EIP712("Test Module", "1") {
        managedToken = _managedToken;
        safe = IGnosisSafe(_safeAddress);
    }

    function generateAllowanceDataHash(uint256 amount, uint256 deadline) public view returns (bytes32) {
        bytes32 allowanceHash = keccak256(abi.encode(
            ALLOWANCE_TYPEHASH,
            nonce,
            amount,
            deadline
        ));
        return _hashTypedDataV4(allowanceHash);
    }

    function withdrawToken(uint256 amount, uint256 deadline, bytes32 r, bytes32 s, uint8 v) public {
        require(block.timestamp <= deadline, "Signature expired");
        safe.checkNSignatures(generateAllowanceDataHash(amount, deadline), "", abi.encodePacked(r,s,v), 1);
        nonce++;
        bytes memory data = abi.encodeWithSignature("transfer(address,uint256)", msg.sender, amount);
        require(safe.execTransactionFromModule(managedToken, 0, data, Enum.Operation.Call), "Could not execute token transfer");
    }

}