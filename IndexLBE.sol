// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity 0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract INDEXSale is Ownable {
    using SafeERC20 for ERC20;
    using Address for address;

    uint256 constant MIMdecimals = 10**18;
    uint256 constant INDEXdecimals = 10**9;

    uint256 public MAX_SOLD = 100000 * INDEXdecimals;
    uint256 public privateSalePrice = (5 * MIMdecimals) / INDEXdecimals;
    uint256 public publicSalePrice = (75 * MIMdecimals) / (INDEXdecimals * 10);

    uint256 public constant MAX_PRIVATE_SALE_PER_ACCOUNT = 200 * INDEXdecimals;
    uint256 public constant MAX_PUBLIC_SALE_PER_ACCOUNT = 67 * INDEXdecimals; // 502.5

    mapping(address => bool) public approvedBuyers;
    mapping(address => uint256) public invested;

    address public INDEX; // INDEX Token
    address public dev;

    uint256 public sold;
    uint256 owed;

    ERC20 MIM;

    bool public publicSale;
    bool public claimable;
    uint256 public claimableTimestamp;

    constructor(address _dev, address mim_address) {
        dev = _dev;
        MIM = ERC20(mim_address);
        publicSale = false;
        claimable = false;
    }

    modifier onlyEOA() {
        require(msg.sender == tx.origin, "!EOA");
        _;
    }

    function _approveBuyer(address newBuyer_)
        internal
        onlyOwner
        returns (bool)
    {
        approvedBuyers[newBuyer_] = true;
        return approvedBuyers[newBuyer_];
    }

    function approveBuyer(address newBuyer_) external onlyOwner returns (bool) {
        return _approveBuyer(newBuyer_);
    }

    function approveBuyers(address[] calldata newBuyers_)
        external
        onlyOwner
        returns (uint256)
    {
        for (
            uint256 iteration_ = 0;
            newBuyers_.length > iteration_;
            iteration_++
        ) {
            _approveBuyer(newBuyers_[iteration_]);
        }
        return newBuyers_.length;
    }

    function amountBuyable(address buyer) public view returns (uint256) {
        uint256 max;
        if (approvedBuyers[buyer] && !publicSale) {
            max = MAX_PRIVATE_SALE_PER_ACCOUNT;
        }
        if (!approvedBuyers[buyer] && publicSale) {
            max = MAX_PUBLIC_SALE_PER_ACCOUNT;
        }
        return max - invested[buyer];
    }

    function buyINDEX(uint256 amount) public onlyEOA {
        require(INDEX == address(0), "No longer for sale");
        require(sold < MAX_SOLD, "sold out");
        require(sold + amount < MAX_SOLD, "not enough remaining");
        require(
            amount <= amountBuyable(msg.sender),
            "amount exceeds buyable amount"
        );

        uint256 price;
        if (publicSale) {
            price = publicSalePrice;
        } else {
            price = privateSalePrice;
        }

        MIM.safeTransferFrom(msg.sender, address(this), amount * price);
        invested[msg.sender] += amount;
        sold += amount;
        owed += amount;
    }

    function claimINDEX() public onlyEOA {
        require(isClaimable(), "Claiming not active");
        ERC20(INDEX).transfer(msg.sender, invested[msg.sender]);
        owed -= invested[msg.sender];
        invested[msg.sender] = 0;
    }

    function setIndexAddress(address _INDEX) public {
        require(msg.sender == dev, "!dev");
        INDEX = _INDEX;
        claimableTimestamp = block.timestamp;
    }

    function setClaimingActive() public {
        require(msg.sender == dev, "!dev");
        claimable = true;
    }

    function getCurrentTimestamp() external view returns (uint256) {
        return block.timestamp;
    }

    function setPublicSaleActive(bool _publicSale) public {
        require(msg.sender == dev, "!dev");
        publicSale = _publicSale;
    }

    function setMaxSold(uint256 _MAX_SOLD) public {
        require(msg.sender == dev, "!dev");
        MAX_SOLD = _MAX_SOLD * INDEXdecimals;
    }

    function setPrivateSalePrice(uint256 _price) public {
        require(msg.sender == dev, "!dev");
        privateSalePrice = (_price * MIMdecimals) / (INDEXdecimals * 10);
    }

    function setPublicSalePrice(uint256 _price) public {
        require(msg.sender == dev, "!dev");
        publicSalePrice = (_price * MIMdecimals) / (INDEXdecimals * 10);
    }

    function withdraw(address _token) public {
        require(msg.sender == dev, "!dev");
        require(INDEX != address(0), "INDEX address not set");
        uint256 b = IERC20(_token).balanceOf(address(this));
        IERC20(_token).transfer(dev, b);
    }

    function isClaimable() public returns (bool) {
        if (claimable) {
            return true;
        }
        if (claimableTimestamp + 3 * 3600 <= block.timestamp) {
            claimable = true;
            return true;
        }
        return false;
    }
}
