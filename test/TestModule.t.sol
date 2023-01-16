// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@std/Test.sol";
import "../src/TestModule.sol";
import "@safe/GnosisSafe.sol";
import "@safe/proxies/GnosisSafeProxy.sol";
import "@safe/proxies/GnosisSafeProxyFactory.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TestModuleTest is Test {

    using stdStorage for StdStorage;

    GnosisSafe public masterCopy;
    GnosisSafe public safe;
    GnosisSafeProxy public safeProxy;
    GnosisSafeProxyFactory public proxyFactory;

    TestModule public testModule;

    ERC20 public unicornToken;

    uint256 internal alicePrivateKey;
    address internal alice;

    uint256 internal bobPrivateKey;
    address internal bob;

    address[] owners;

    function setUp() public {
        
        // setup accounts

        alicePrivateKey = 0xA11CE;
        alice = vm.addr(alicePrivateKey);

        bobPrivateKey = 0xB0B;
        bob = vm.addr(bobPrivateKey);
        
        masterCopy = new GnosisSafe();
        proxyFactory = new GnosisSafeProxyFactory();

        owners.push(alice);

        // setup Safe

        safeProxy = new GnosisSafeProxy(address(masterCopy));
        safe = GnosisSafe(payable(address(safeProxy)));
        safe.setup(owners, 1, address(0), "0x", address(0), address(0), 0, payable(address(0)));

        // Deploy and mint Unicorn token

        unicornToken = new ERC20("UNICORN", "UNT");
        writeTokenBalance(address(safe), address(unicornToken), 1000 * 1e18);

        // Enable Test Module

        testModule = new TestModule(address(unicornToken), address(safe));
        bytes memory enableModuleData = abi.encodeWithSignature("enableModule(address)", address(testModule));
        executeSafeTransaction(address(safe), 0, enableModuleData, Enum.Operation.Call);

    }

    function testCanTransferUsingModule() public {   

        assertEq(unicornToken.balanceOf(bob), 0);

        uint256 amountToTransfer = 100*1e18;

        uint256 deadline = block.timestamp + 1_000;

        bytes32 allowanceDataHash = testModule.generateAllowanceDataHash(amountToTransfer, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePrivateKey, allowanceDataHash);
        
        vm.prank(bob);
        testModule.withdrawToken(amountToTransfer, deadline, bob, r, s, v);

        assertEq(unicornToken.balanceOf(bob), amountToTransfer);
    }

    function testCanNotReuseSignature() public {   

        assertEq(unicornToken.balanceOf(bob), 0);
        uint256 amountToTransfer = 100*1e18;
        uint256 deadline = block.timestamp + 1_000;

        bytes32 allowanceDataHash = testModule.generateAllowanceDataHash(amountToTransfer, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePrivateKey, allowanceDataHash);
        
        vm.prank(bob);
        testModule.withdrawToken(amountToTransfer, deadline,  bob, r, s, v);
        assertEq(unicornToken.balanceOf(bob), amountToTransfer);

        vm.startPrank(bob);
        vm.expectRevert("GS026");
        testModule.withdrawToken(amountToTransfer, deadline,  bob, r, s, v);
        vm.stopPrank();
    }

    function testCanNotSpoofAmount() public {   

        assertEq(unicornToken.balanceOf(bob), 0);
        uint256 amountToTransfer = 100*1e18;
        uint256 deadline = block.timestamp + 1_000;

        bytes32 allowanceDataHash = testModule.generateAllowanceDataHash(amountToTransfer, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePrivateKey, allowanceDataHash);

        vm.startPrank(bob);
        vm.expectRevert("GS026");
        testModule.withdrawToken(amountToTransfer+100*1e18, deadline,  bob, r, s, v);
        vm.stopPrank();

        assertEq(unicornToken.balanceOf(bob), 0);
    }

    function testCanNotSpoofDeadline() public {   

        assertEq(unicornToken.balanceOf(bob), 0);
        uint256 amountToTransfer = 100*1e18;
        uint256 deadline = block.timestamp + 10;

        bytes32 allowanceDataHash = testModule.generateAllowanceDataHash(amountToTransfer, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePrivateKey, allowanceDataHash);

        vm.startPrank(bob);
        vm.expectRevert("GS026");
        testModule.withdrawToken(amountToTransfer, deadline+1000,  bob, r, s, v);
        vm.stopPrank();

        assertEq(unicornToken.balanceOf(bob), 0);
    }

    function testCanNotUseExpiredSignature() public {   

        assertEq(unicornToken.balanceOf(bob), 0);
        uint256 amountToTransfer = 100*1e18;
        uint256 deadline = block.timestamp + 1_000;

        bytes32 allowanceDataHash = testModule.generateAllowanceDataHash(amountToTransfer, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePrivateKey, allowanceDataHash);

        vm.warp(deadline+100);

        vm.startPrank(bob);
        vm.expectRevert("Signature expired");
        testModule.withdrawToken(amountToTransfer, deadline, bob, r, s, v);
        vm.stopPrank();

        assertEq(unicornToken.balanceOf(bob), 0);
    }

    function testCanNotUseOtherPersonsSignature() public {   

        assertEq(unicornToken.balanceOf(bob), 0);
        uint256 amountToTransfer = 100*1e18;
        uint256 deadline = block.timestamp + 1_000;

        bytes32 allowanceDataHash = testModule.generateAllowanceDataHash(amountToTransfer, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bobPrivateKey, allowanceDataHash);

        vm.startPrank(bob);
        vm.expectRevert("GS026");
        testModule.withdrawToken(amountToTransfer, deadline, bob, r, s, v);
        vm.stopPrank();

        assertEq(unicornToken.balanceOf(bob), 0);
    }

    function testCanNotWithdrawMoreTokensThanSafeHas() public {   

        assertEq(unicornToken.balanceOf(bob), 0);
        uint256 amountToTransfer = unicornToken.balanceOf(address(safe)) + 100*1e18;
        uint256 deadline = block.timestamp + 1_000;

        bytes32 allowanceDataHash = testModule.generateAllowanceDataHash(amountToTransfer, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePrivateKey, allowanceDataHash);

        vm.startPrank(bob);
        vm.expectRevert("Could not execute token transfer");
        testModule.withdrawToken(amountToTransfer, deadline, bob, r, s, v);
        vm.stopPrank();

        assertEq(unicornToken.balanceOf(bob), 0);
    }

    function testCanNotUseSignatureFromOtherDomain() public { 

        ERC20 unicornToken2 = new ERC20("UNICORN2", "UNT2");
        writeTokenBalance(address(safe), address(unicornToken2), 1000 * 1e18);

        TestModule testModule2 = new TestModule(address(unicornToken2), address(safe));
        bytes memory enableModuleData2 = abi.encodeWithSignature("enableModule(address)", address(testModule2));
        executeSafeTransaction(address(safe), 0, enableModuleData2, Enum.Operation.Call);  

        assertEq(unicornToken.balanceOf(bob), 0);

        uint256 amountToTransfer = 100*1e18;
        uint256 deadline = block.timestamp + 1_000;

        bytes32 allowanceDataHash = testModule2.generateAllowanceDataHash(amountToTransfer, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePrivateKey, allowanceDataHash);

        vm.startPrank(bob);
        vm.expectRevert("GS026");
        testModule.withdrawToken(amountToTransfer, deadline, bob, r, s, v);
        vm.stopPrank();

        assertEq(unicornToken.balanceOf(bob), 0);
    }

    /*
    *   Helper functions
    */

    function writeTokenBalance(address who, address token, uint256 amt) internal {
        stdstore
            .target(token)
            .sig(IERC20(token).balanceOf.selector)
            .with_key(who)
            .checked_write(amt);
    }

    function executeSafeTransaction(address to, uint256 value, bytes memory data, Enum.Operation operation) internal {
        uint256 nonce = safe.nonce();
        bytes32 transactionHash = safe.getTransactionHash(
            to, value, data, operation, 0, 0, 0, address(0), address(0), nonce);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePrivateKey, transactionHash);
        bytes memory signature = abi.encodePacked(r,s,v);
        vm.prank(alice);
        safe.execTransaction(to, value, data, operation, 0, 0, 0, address(0), payable (address(0)), signature);
    }



}
