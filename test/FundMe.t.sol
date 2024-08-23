// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../src/FundMe.sol";

import { DeployFundMe } from "../script/DeployFundMe.s.sol";

contract FundMeTest is Test {
    uint256 constant START_ETHER_VALUE = 10 ether;
    uint256 constant GAS_PRICE = 1;
    
    FundMe fundMe;
    DeployFundMe dfm;

    address alice = makeAddr("alice");

    function setUp() external {
        dfm = new DeployFundMe();
        fundMe = dfm.run();
        vm.deal(alice, START_ETHER_VALUE);
    }

    function testMinimumDollarIsFive() public view {
        assertEq(fundMe.MINIMUM_USD(), 5e18);
    }

    function testOwnerIsMsgSender() public view {
        console.log(fundMe.getOwner());
        console.log(msg.sender);
        console.log(address(this));
        assertEq(fundMe.getOwner(), msg.sender);
    }

    function testPriceFeedVersionIsAccurate() public view {
        uint256 version = fundMe.getVersion();
        assertEq(version, 4);
    }

    function testFundFailsWithoutEnoughETH() public {
        vm.expectRevert();
        fundMe.fund();
    }

    function testFundUpdatesFundDataStructure() public {
        vm.prank(alice);
        fundMe.fund{value: START_ETHER_VALUE}();
        uint256 amountFunded = fundMe.getAddressToAmountFunded(alice);
        assertEq(amountFunded, START_ETHER_VALUE);
    }

    function testAddsFunderToArrayOfFunders() public {
        vm.startPrank(alice);
        fundMe.fund{value: START_ETHER_VALUE}();
        vm.stopPrank();
        address funder = fundMe.getFunder(0);
        assertEq(funder, alice);
    }

    function testOnlyOwnerCanWithdraw() public funded{
        
        vm.expectRevert();
        vm.prank(alice);
        fundMe.withdraw();
    }

    modifier funded(){
        vm.prank(alice);
        fundMe.fund{value: START_ETHER_VALUE}();
        assert(address(fundMe).balance > 0);
        _;
    }

    function testWithdrawFromASingleFunder() public funded () {
        // Arrange
        uint256 startingFundMeBalance = address(fundMe).balance;
        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        vm.txGasPrice(GAS_PRICE);
        uint256 gasStart = gasleft();
    
        // Act 
        vm.startPrank(fundMe.getOwner());
        fundMe.withdraw();
        vm.stopPrank();

        uint256 gasEnd = gasleft();
        uint256 gasUsed = (gasStart - gasEnd) * tx.gasprice;

        console.log("Withdraw consummed: %d gas", gasUsed);
        // Assert
        uint256 endingFundMeBalance = address(fundMe).balance;
        uint256 endingOwnerBalance = fundMe.getOwner().balance;
        assertEq(endingFundMeBalance, 0);
        assertEq(startingFundMeBalance+startingOwnerBalance, endingOwnerBalance);
    }

    function testWithdrawFromMultipleFunders() public funded {
        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex = 1;

        for(uint160 i = startingFunderIndex; i < numberOfFunders+startingFunderIndex; i++){
            hoax(address(i), START_ETHER_VALUE);
            fundMe.fund{value: START_ETHER_VALUE}();
        }

        uint256 startingFundMeBalance = address(fundMe).balance;
        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        vm.startPrank(fundMe.getOwner());
        fundMe.withdraw();
        vm.stopPrank();

        assert(address(fundMe).balance == 0);
        assert(startingFundMeBalance + startingOwnerBalance ==  fundMe.getOwner().balance);
        assert((numberOfFunders+1)*START_ETHER_VALUE == fundMe.getOwner().balance - startingOwnerBalance);
    }
}