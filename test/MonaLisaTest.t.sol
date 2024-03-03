// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {MonaLisa} from "../contracts/MonaLisa.sol";
 
contract ERC404Test is Test {
    MonaLisa public monaLisa;
    address public owner;
    address public user2 = address(0x123);
    address public user3 = address(0x456);

    function setUp() public {
        owner = msg.sender;
        console.log("owner is : ", owner);
        monaLisa = new MonaLisa(owner);
        uint256 balanceOfOwner = monaLisa.balanceOf(owner);
        console.log("balanceOfOwner is : ", balanceOfOwner);
        vm.startPrank(owner);
        // The owner should always be whitelisted, this allows the owner to mint tokens
        monaLisa.setWhitelist(owner, true);
    }

    function testTransferFunc() public {
        uint256 currentBalanceOfOwner = monaLisa.balanceOf(owner);
        // Transfer 5 tokens from the owner to user2
        monaLisa.transfer(user2, 5 * 10 ** 18);
        uint256 balanceOfUser2 = monaLisa.balanceOf(user2);
        console.log("balanceOfUser2 is : ", balanceOfUser2);
        // Get the _owned tokens of user2
        uint256[] memory ownedTokens = monaLisa.getOwned(user2);
        for(uint256 i = 0; i < ownedTokens.length; i++) {
            console.log("ownedTokens[", i, "] is : ", ownedTokens[i]);
        }
        // Get value of minted variable
        uint256 minted = monaLisa.minted();
        console.log("minted is : ", minted);
        assertEq(minted, 5);
        assertEq(balanceOfUser2, 5 * 10 ** 18);
        assertEq(currentBalanceOfOwner - 5 * 10 ** 18, monaLisa.balanceOf(owner));
    }

    function testTransferFuncToUser3() public {
        // Transfer 5 tokens from the owner to user2
        monaLisa.transfer(user2, 5 * 10 ** 18);
        uint256 balanceOfUser2 = monaLisa.balanceOf(user2);
        console.log("balanceOfUser2 is : ", balanceOfUser2);
        // Get the _owned tokens of user2
        uint256[] memory ownedTokens = monaLisa.getOwned(user2);
        for(uint256 i = 0; i < ownedTokens.length; i++) {
            console.log("ownedTokens[", i, "] is : ", ownedTokens[i]);
            // Get ownedIndex of i+1
            uint256 ownedIndex = monaLisa._ownedIndex(i+1);
            console.log("ownedIndex is : ", ownedIndex);
            // Get ownerOf tokenId
            address ownerOf = monaLisa.ownerOf(i+1);
            console.log("ownerOf is : ", ownerOf);
        }
        // Get value of minted variable
        uint256 minted = monaLisa.minted();
        console.log("minted is : ", minted);
        vm.stopPrank();

        vm.startPrank(user2);
        // Transfer the token #2 from user2 to user3
        monaLisa.transferFrom(user2, user3, 2);
        // Assert that the owner of token #2 is user3
        assertEq(monaLisa.ownerOf(2), user3);
        // Assert that the balance of user2 is 4 * 10 ** 18 because user just lost 1 unit 
        assertEq(monaLisa.balanceOf(user2), 4 * 10 ** 18);
        // Assert that the balance of user3 is 1 * 10 ** 18 because user just received 1 unit
        assertEq(monaLisa.balanceOf(user3), 1 * 10 ** 18);
    }
}
