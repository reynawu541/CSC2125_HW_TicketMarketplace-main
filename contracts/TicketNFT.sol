// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {ITicketNFT} from "./interfaces/ITicketNFT.sol";

// Uncomment this line to use console.log
// import "hardhat/console.sol";

contract TicketNFT is ERC1155, ITicketNFT {
    // your code goes here (you can do it!)

    address private marketplaceContract;

    address public owner;

    constructor(address _marketplaceContract) ERC1155("") {
        marketplaceContract = _marketplaceContract;
        owner = msg.sender;
    }
    
    function mintFromMarketPlace(address to, uint256 nftId) external {
        require(msg.sender == marketplaceContract, "Caller is not the marketplace contract");
        _mint(to, nftId, 1, "");
    }
}