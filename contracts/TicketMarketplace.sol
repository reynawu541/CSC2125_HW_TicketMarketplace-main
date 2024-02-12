// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ITicketNFT} from "./interfaces/ITicketNFT.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {TicketNFT} from "./TicketNFT.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol"; 
import {ITicketMarketplace} from "./interfaces/ITicketMarketplace.sol";
import "hardhat/console.sol";

contract TicketMarketplace is ITicketMarketplace {
    address public nftContract;         // NFT contract address
    address public owner;               // marketplace owner
    address public ERC20Address;        // ERC20 token address used for trasnactions
    uint128 public currentEventId;      // event counter
    mapping(uint128 => Event) public events;    // a mapping to store event details

    struct Event {
        uint128 nextTicketToSell;       // tracks the ticket ID to be sold next
        uint128 maxTickets;             // the maximum number of tickets available for the event
        uint256 pricePerTicket;         // price per ticket 
        uint256 pricePerTicketERC20;    // price per ticket if purchased with an ERC20 token
    }


    // ensures that only the account identified as "owner" can successfully call and execute that function
    modifier onlyOwner() {
        require(msg.sender == owner, "Unauthorized access");
        _;
    }

    // set up the constructor
    constructor(address _ERC20Address) {
        owner = msg.sender;                 // set the "owner" to the address of the account that deploys the contract
        ERC20Address = _ERC20Address;
        currentEventId = 0;              
        nftContract = address(new TicketNFT(address(this)));    // create a new TicketNFT contract and set the state variable to its address
    }

    // allow the contract owner to create a new event
    function createEvent(uint128 maxTickets, uint256 pricePerTicket, uint256 pricePerTicketERC20) external override onlyOwner {
        events[currentEventId] = Event(0, maxTickets, pricePerTicket, pricePerTicketERC20);
        emit EventCreated(uint128(currentEventId), maxTickets, pricePerTicket, pricePerTicketERC20);
        currentEventId++;
    }

    // allow the contract owner to update the maximum number of tickets avaialble for a specific event
    function setMaxTicketsForEvent(uint128 eventId, uint128 newMaxTickets) external override onlyOwner {
        require(newMaxTickets >= events[eventId].maxTickets, "The new number of max tickets is too small!");    // ensuring the new max number of tickets is not less than the current max
        events[eventId].maxTickets = newMaxTickets;
        emit MaxTicketsUpdate(eventId, newMaxTickets);      
    }

    // allow the contract owner to update the price of tickets for a specific event when the tickets are purchased with Ether
    function setPriceForTicketETH(uint128 eventId, uint256 price) external override onlyOwner {
        events[eventId].pricePerTicket = price;
        emit PriceUpdate(eventId, price, "ETH");
    }

    // allow the ocntract owner to update the price of tickets for a specific event when the tickets are purchased with ERC20
    function setPriceForTicketERC20(uint128 eventId, uint256 price) external override onlyOwner {
        events[eventId].pricePerTicketERC20 = price;
        emit PriceUpdate(eventId, price, "ERC20");
    }


    // allow the contract owner to update the address of the ERC20 token 
    function setERC20Address(address newERC20Address) external override onlyOwner {
        ERC20Address = newERC20Address;
        emit ERC20AddressUpdate(newERC20Address);
    }

    // allow users to purchase tickets for an event using Ether
    function buyTickets(uint128 eventId, uint128 ticketCount) payable external override {

        (bool mulSuccess, uint256 totalPrice) = Math.tryMul(events[eventId].pricePerTicket, ticketCount);
        require(mulSuccess, "Overflow happened while calculating the total price of tickets. Try buying smaller number of tickets.");
        // make sure that the Ether sent is at least equal to the total price of the tickets
        require(msg.value >= totalPrice, "Not enough funds supplied to buy the specified number of tickets.");
        
        // confirms that there are enough tickets left for sale
        require(events[eventId].nextTicketToSell + ticketCount <= events[eventId].maxTickets, "We don\'t have that many tickets left to sell!");

        uint256 eId = eventId;

       
        eId = eId << 128;  // leaving space for ticket number

        // Mint NFTs to the buyer
        for (uint128 i = 0; i < ticketCount; i++) {
            uint256 nftId = eId + events[eventId].nextTicketToSell + i;
            ITicketNFT(nftContract).mintFromMarketPlace(msg.sender, nftId);
        }

        events[eventId].nextTicketToSell += ticketCount; // update the next ticket to sell
        emit TicketsBought(eventId, ticketCount, "ETH");
    }

    // purchase tickets for an event using ERC20 token
    function buyTicketsERC20(uint128 eventId, uint128 ticketCount) external override {

        (bool mulSuccess, uint256 totalPrice) = Math.tryMul(events[eventId].pricePerTicketERC20, ticketCount);
        require(mulSuccess, "Overflow happened while calculating the total price of tickets. Try buying smaller number of tickets.");

        require(events[eventId].nextTicketToSell + ticketCount <= events[eventId].maxTickets, "We don\'t have that many tickets left to sell!");
        IERC20 erc20 = IERC20(ERC20Address);
        require(erc20.allowance(msg.sender, address(this)) >= totalPrice, "Not enough funds supplied to buy the specified number of tickets.");

        // Transfer ERC20 tokens from buyer to contract
        require(erc20.transferFrom(msg.sender, address(this), totalPrice), "Transfer of ERC20 tokens failed");

        uint256 eId = eventId;

        eId = eId << 128;

        // Mint NFTs to the buyer
        for (uint128 i = 0; i < ticketCount; i++) {
            uint256 nftId = eId + events[eventId].nextTicketToSell + i;
            ITicketNFT(nftContract).mintFromMarketPlace(msg.sender, nftId);
        }

        events[eventId].nextTicketToSell += ticketCount;
        emit TicketsBought(eventId, ticketCount, "ERC20");
    }

}