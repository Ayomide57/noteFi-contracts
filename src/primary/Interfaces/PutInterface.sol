// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


interface PutInterface {

    function init() external;

    function buy() external;

    function transfer(address buyer) external;

    function execute() external;

    function cancel() external;

    function withdraw() external;

    function adjustPremium(uint256 premium) external;

}