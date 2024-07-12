// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "./AggregatorV3Interface.sol";

contract PutOption {
    address public asset;
    address public creator;
    uint256 public premium;
    uint256 public strikePrice;
    uint256 public quantity;
    uint256 public expiration;
    uint256 public executedPrice;
    address public buyer;
    bool public inited;
    bool public bought;
    bool public executed;
    IERC20 public premiumToken;
    AggregatorV3Interface public priceOracle;

    event TranferTokenEvent(
        address indexed from,
        address indexed to,
        uint256 indexed quantity,
        uint256 amountToPay
    );


    constructor(
        address _asset,
        address _creator,
        uint256 _premium,
        uint256 _strikePrice,
        uint256 _quantity,
        uint256 _expiration,
        address _premiumToken,
        address _priceOracle
    ) {
        asset = _asset;
        creator = _creator;
        premium = _premium;
        strikePrice = _strikePrice;
        quantity = _quantity;
        expiration = _expiration;
        buyer = address(0);
        bought = false;
        executed = false;
        inited = false;
        premiumToken = IERC20(_premiumToken);
        priceOracle = AggregatorV3Interface(_priceOracle);
    }

    modifier isInited() {
        require(inited, "Contract has not been inited by the creator!");
        _;
    }

    modifier notBought() {
        require(!bought, "Contract has been bought!");
        _;
    }

    modifier notExecuted() {
        require(!executed, "Contract has been executed!");
        _;
    }

    modifier onlyBuyer() {
        require(msg.sender == buyer, "Only the buyer can call this function!");
        _;
    }

    modifier onlyCreator() {
        require(msg.sender == creator, "Only the creator can call this function!");
        _;
    }

    modifier notExpired() {
        require(block.timestamp <= expiration, "Option expired");
        _;
    }

    function init() external onlyCreator {
        require(inited == false, "Option contract has already been initialized");
        inited = true;
        require(premiumToken.transferFrom(creator, address(this), strikeValue()), "Transfer failed");
        emit TranferTokenEvent(creator, address(this), strikeValue(), 0);
    }

    function buy() external notBought isInited notExpired {
        require(msg.sender != creator, "Creator cannot buy their own option");
        bought = true;
        buyer = msg.sender;
        require(premiumToken.transferFrom(msg.sender, creator, premium), "Premium transfer failed");
        emit TranferTokenEvent(msg.sender, creator, premium, 0);
    }

    function transfer(address newBuyer) external onlyBuyer isInited notExpired {
        buyer = newBuyer;
    }

    function execute() external onlyBuyer notExecuted isInited notExpired {
        require(_checkPosition(), "Option is out of the money");
        executed = true;
        uint256 amountToTransfer = strikeValue();
        require(premiumToken.transfer(buyer, amountToTransfer), "Asset transfer failed");
        require(IERC20(asset).transferFrom(buyer, creator, quantity), "Payment failed");
        emit TranferTokenEvent(buyer, creator, quantity, amountToTransfer);
    }

    function _checkPosition() internal returns (bool) {
        (, int256 price,, uint256 updatedAt,) = priceOracle.latestRoundData();
        require(updatedAt + 2 minutes > block.timestamp, "Price needs to be updated first");
        executedPrice = uint256(price);
        return uint256(price) <= strikePrice;
    }

    function cancel() external onlyCreator notBought isInited notExpired {
        executed = true;
        require(premiumToken.transfer(creator, strikeValue()), "Asset transfer failed");
        emit TranferTokenEvent(address(premiumToken), creator, strikeValue(), 0);
    }

    function withdraw() external onlyCreator isInited {
        require(block.timestamp > expiration, "Option not expired yet");
        require(!executed, "Option already executed");
        executed = true;
        require(premiumToken.transfer(creator, strikeValue()), "Asset transfer failed");
        emit TranferTokenEvent(address(premiumToken), creator, strikeValue(), 0);
    }

    function adjustPremium(uint256 newPremium) external onlyCreator notBought notExpired {
        premium = newPremium;
    }

    function strikeValue() public view returns (uint256) {
        return (strikePrice * quantity) / (10 ** priceOracle.decimals());
    }
}
