pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    uint8 private deci;

    constructor(string memory name_, string memory symbol_, uint8 decimals_, uint256 amount_) ERC20(name_, symbol_) {
        deci = decimals_;
        _mint(msg.sender, amount_ * 10 ** decimals());
    }
    
    function decimals() override public view returns (uint8) {
        return deci;
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

import "@openzeppelin/contracts/access/Ownable.sol";

contract MockToken2 is ERC20, Ownable {
    uint8 private deci;

    constructor(string memory name_, string memory symbol_, uint8 decimals_, uint256 amount_, address admin_) ERC20(name_, symbol_) {
        deci = decimals_;
        _mint(msg.sender, amount_ * 10 ** decimals());
        _transferOwnership(admin_);
    }

    function decimals() override public view returns (uint8) {
        return deci;
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}