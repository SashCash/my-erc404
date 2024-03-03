// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./ERC404.sol";

/**
 * @title MonaLisa
 * @dev ERC404 token, convert the MonaLisa into a liquidity asset NFT and users can own a piece of the MonaLisa
 */
contract MonaLisa is ERC404 {
    string public dataURI;
    string public baseTokenURI;

    constructor(address _owner) ERC404("MonaLisa", "MNLSA", 18, 10000, _owner) {
        balanceOf[_owner] = 10000 * 10 ** 18; // Setting the initial balance of tokens for the owner
    }

    function setDataURI(string memory _dataURI) public onlyOwner {
        dataURI = _dataURI;
    }

    function setTokenURI(string memory _tokenURI) public onlyOwner {
        baseTokenURI = _tokenURI;
    }


    function tokenURI(uint256 id) public view override returns (string memory) {
        return baseTokenURI;
    }
}