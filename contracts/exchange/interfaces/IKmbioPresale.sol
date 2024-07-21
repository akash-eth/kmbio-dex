// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

interface IKmbioPresale {
    struct PresaleConfig {
        address token;
        uint256 price;
        uint256 listing_price;
        uint256 liquidity_percent;
        uint256 hardcap;
        uint256 softcap;
        uint256 min_contribution;
        uint256 max_contribution;
        uint256 startTime;
        uint256 endTime;
        uint256 liquidity_lockup_time;
    }

    function initialize(
        PresaleConfig memory _config,
        address _BaseBombRouter,
        address _owner,
        address _treasury,
        uint256 _emergencyFee,
        uint256 _ethFee,
        uint256 _tokenFee
    ) external;
}
