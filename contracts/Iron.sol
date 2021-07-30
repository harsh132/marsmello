// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Iron is ERC20, Ownable {
    constructor() ERC20("Iron", "Fe") {
        _mint(msg.sender, 1000000000 * 10**decimals());
    }

    function mint(uint256 amount) public onlyOwner {
        _mint(msg.sender, amount * 10**decimals());
    }
}
