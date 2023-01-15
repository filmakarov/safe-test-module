// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@std/Test.sol";
import "../src/TestModule.sol";
import "@safe/GnosisSafe.sol";
import "@safe/proxies/GnosisSafeProxy.sol";
import "@safe/proxies/GnosisSafeProxyFactory.sol";

contract CounterTest is Test {
    GnosisSafe public masterCopy;
    GnosisSafe public safe;
    GnosisSafeProxy public safeProxy;
    GnosisSafeProxyFactory public proxyFactory;

    uint256 internal alicePrivateKey;
    address internal alice;

    uint256 internal bobPrivateKey;
    address internal bob;

    function setUp() public {
        
        alicePrivateKey = 0xA11CE;
        alice = vm.addr(alicePrivateKey);

        bobPrivateKey = 0xB0B;
        bob = vm.addr(bobPrivateKey);
        
        masterCopy = new GnosisSafe();
        proxyFactory = new GnosisSafeProxyFactory();

        bytes memory setupData = abi.encodeWithSignature(
                "setup(address[],uint256,address,bytes,address,address,uint256,address", 
                [alice], 1, ADDRESS_0, "0x", ADDRESS_0, ADDRESS_0, 0, ADDRESS_0);
        
        safeProxy = proxyFactory.createProxy(address(masterCopy), setupData);

        // deploy erc20 token

        // write balance to safe

        // deploy module

        // register module

    }

    function testCanExecuteTransactionFromModule() public {   
        
        // transfer token

        // assert balance
    }

    function writeTokenBalance(address who, address token, uint256 amt) internal {
        stdstore
            .target(token)
            .sig(IERC20(token).balanceOf.selector)
            .with_key(who)
            .checked_write(amt);
    }



}
