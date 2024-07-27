// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import "../../src/primary/Factory.sol";
import {CallOption} from "../../src/primary/Call.sol";
import "../../src/primary/Put.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../../src/primary/interfaces/AggregatorV3Interface.sol";
import {CommonBase} from "forge-std/Base.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";

contract Handler is CommonBase, StdCheats, StdUtils {
    CallOption public callOption;

    address ethToken = 0xCa03230E7FB13456326a234443aAd111AC96410A; // 18 decimals
    address noteToken = 0x03F734Bd9847575fDbE9bEaDDf9C166F880B5E5f; // 18 decimals
    address priceOracle = 0xc302BD52985e75C1f563a47f2b5dfC4e2b5C6C7E; // 8 decimals

    address public buyer = makeAddr("buyer");
    address public creator;
    ERC20 ethERC20 = ERC20(ethToken);
    ERC20 noteERC20 = ERC20(noteToken);


    constructor(CallOption _callOption, address _creator){
        callOption = _callOption;
        creator = _creator;
    }

    function init(uint256 amount) public virtual {
        amount = bound(amount, 1e16, 1e18);
        deal(ethToken, creator, amount);
        ethERC20.approve(address(callOption), amount);
        callOption.init();
    }

    function buy(uint256 amount) public virtual {
        amount = bound(amount, 1e18, 1000e18);
        deal(noteToken, buyer, 100e18);
        noteERC20.approve(address(callOption), 10e18);
        callOption.buy();
    }

    function transfer() public virtual {
        address newBuyer = makeAddr("buyer");
        callOption.transfer(newBuyer);
    }

    function execute() public virtual {
        noteERC20.approve(address(callOption), callOption.strikeValue());
        callOption.execute();
    }

    function withdraw() public virtual {
        vm.warp(block.timestamp + 8 days);
        vm.prank(creator);
        callOption.withdraw();
    }

    function adjustPremium(uint256 newPremium) public virtual {
        newPremium = bound(newPremium, 5e18, 11e18);
        callOption.adjustPremium(newPremium);
    }
}

contract CallOption_Handler_Test is Test{
    CallOption public callOption;
    Handler public handler;
    OptionsFactory public factory;

    address ethToken = 0xCa03230E7FB13456326a234443aAd111AC96410A; // 18 decimals

    function setUp() public {
        factory = OptionsFactory(0xA5192B03B520aF7214930936C958CF812e361CD3);
        uint256 premium = 10e18;
        uint256 strikePrice = 3500e8;
        uint256 quantity = 1e16;
        uint256 expiration = block.timestamp + 1 weeks;

        address creator = makeAddr("creator");
        vm.prank(creator);
        factory.createCallOption(ethToken, premium, strikePrice, quantity, expiration);

        address[] memory callOptions = factory.getCallOptions();
        callOption = CallOption(callOptions[callOptions.length - 1]);
        handler = new Handler(callOption, creator);
        //targetContract(address(handler));
    }

    function invariant_eth_balance() public view  {
        //assertGe(address(handler).balance, 0);
    }
}

// forge test --match-path test/Handler/CallTestHandler.t.sol -vvv
