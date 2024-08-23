// Allow users to send funds into contract
// Enable withdraw funds from contract by contract onwer
// Set minimum funding value in USD

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {PriceConverter} from "./PriceConverter.sol";

error NotOwner();

// before update: 691543 gas (transaction cost), 596263 (execution cost)
// first update:  668404 gas (transaction cost), 573350 (execution cost)
// second update: 645273 gas (trransaction cost), 550841 (execution cost)
contract FundMe {
    using PriceConverter for uint256;

    uint256 public constant MINIMUM_USD = 5e18; // first update (make constant - 23000 gas), second update (capitalize to constant-like view)
    address[] s_funders;
    mapping(address funder => uint256 amount) s_funderToAmount;

    address private s_priceFeed;

    address private /* immutable */ i_owner; // second update (make immutable - 417 gas, before - 2522 gas)
    
    modifier isOwner() {
        //require(msg.sender == i_owner, "Sender is not owner");
        if (msg.sender != i_owner) revert NotOwner();
        _;
    }

    constructor(address priceFeed_) {
        i_owner = msg.sender;
        s_priceFeed = priceFeed_;
    }


    function fund() public payable {
        require(msg.value.getConversionRate(s_priceFeed) >= MINIMUM_USD, "didn`t send enough funds");
        s_funders.push(msg.sender);
        s_funderToAmount[msg.sender] += msg.value;
    }

    function withdraw() public isOwner {
        for (uint256 funderIndex = 0; funderIndex < s_funders.length; funderIndex++) {
            address funder = s_funders[funderIndex];
            s_funderToAmount[funder] = 0;
        }
        s_funders = new address[](0);

        (bool callSuccess, /*bytes memory data*/ ) = payable(msg.sender).call{value: address(this).balance}("");
        require(callSuccess, "Call failed");
    }

    receive() external payable {
        fund();
    }

    fallback() external payable {
        fund();
    }

    function cheaperWithdraw() public isOwner {
        address[] memory funders = s_funders;
        // mappings can't be in memory, sorry!
        for (uint256 funderIndex = 0; funderIndex < funders.length; funderIndex++) {
            address funder = funders[funderIndex];
            s_funderToAmount[funder] = 0;
        }
        s_funders = new address[](0);
        // payable(msg.sender).transfer(address(this).balance);
        (bool success,) = i_owner.call{value: address(this).balance}("");
        require(success);
    }

    /**
     * Getter Functions
     */

    /**
     * @notice Gets the amount that an address has funded
     *  @param fundingAddress the address of the funder
     *  @return the amount funded
     */
    function getAddressToAmountFunded(address fundingAddress) public view returns (uint256) {
        return s_funderToAmount[fundingAddress];
    }

    function getVersion() public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeed);
        return priceFeed.version();
    }

    function getFunder(uint256 index) public view returns (address) {
        return s_funders[index];
    }

    function getOwner() public view returns (address) {
        return i_owner;
    }

    function getPriceFeed() public view returns (address) {
        return s_priceFeed;
    }

}
