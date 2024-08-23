// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

library PriceConverter {
    function getPrice(address priceFeedAddress_) internal view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(priceFeedAddress_);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return uint256(price * 1e10);
    }

    function getConversionRate(uint256 ethAmount, address priceFeed_) internal view returns (uint256) {
        uint256 ethPrice = getPrice(priceFeed_);
        uint256 ethAmountToUsd = (ethPrice * ethAmount) / 1e18;
        return ethAmountToUsd;
    }
}
