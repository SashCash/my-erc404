//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract ERC721Receiver {
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external virtual returns (bytes4) {
        return ERC721Receiver.onERC721Received.selector;
    }
}


abstract contract ERC404 is Ownable {
    // Events
    event ERC20Transfer(
        address indexed from,
        address indexed to,
        uint256 amount
    );
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 amount
    );
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed id
    );
    event ERC721Approval(
        address indexed owner,
        address indexed spender,
        uint256 indexed id
    );
    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );

    // Errors
    error NotFound();
    error AlreadyExists();
    error InvalidRecipient();
    error InvalidSender();
    error UnsafeRecipient();
    error Unauthorized();

    // Metadata
    /// @dev Token name
    string public name;

    /// @dev Token symbol
    string public symbol;

    /// @dev Decimals for fractional representation
    uint8 public immutable decimals;

    /// @dev Total supply in fractionalized representation
    uint256 public immutable totalSupply;

    /// @dev Current mint counter, monotonically increasing to ensure accurate ownership
    uint256 public minted;

    // Mappings
    /// @dev Balance of user in fractional representation
    mapping(address => uint256) public balanceOf;

    /// @dev Allowance of user in fractional representation
    mapping(address => mapping(address => uint256)) public allowance;

    /// @dev Approval in native representaion
    mapping(uint256 => address) public getApproved;

    /// @dev Approval for all in native representation
    mapping(address => mapping(address => bool)) public isApprovedForAll;

    /// @dev Owner of id in native representation
    mapping(uint256 => address) public _ownerOf;

    /// @dev Array of owned ids in native representation
    mapping(address => uint256[]) public _owned;

    /// @dev Tracks indices for the _owned mapping
    mapping(uint256 => uint256) public _ownedIndex;

    /// @dev Addresses whitelisted from minting / burning for gas savings (pairs, routers, etc)
    // is actually more a blacklist than a whitelist since it's used to skip minting / burning for certain addresses
    mapping(address => bool) public whitelist;

    // Constructor
    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint256 _totalNativeSupply,
        address _owner
    ) Ownable(_owner) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        totalSupply = _totalNativeSupply * (10 ** decimals);
    }

    function getOwned(address owner) public view returns (uint256[] memory) {
        return _owned[owner];
    }

    /// @notice Initialization function to set pairs / etc
    ///         saving gas by avoiding mint / burn on unnecessary targets
    function setWhitelist(address target, bool state) public onlyOwner {
        whitelist[target] = state;
    }

    /// @notice Function to find owner of a given native token
    function ownerOf(uint256 id) public view virtual returns (address owner) {
        owner = _ownerOf[id];

        if (owner == address(0)) {
            revert NotFound();
        }
    }

    /// @notice tokenURI must be implemented by child contract
    function tokenURI(uint256 id) public view virtual returns (string memory);

    /// @notice Function for token approvals
    /// @dev This function assumes id / native if amount less than or equal to current max id
    /// @dev If amountOrId is less than or equal to minted, it's an id value like erc721
    /// @dev Otherwise its a fungible amount like erc20
    function approve(
        address spender,
        uint256 amountOrId
    ) public virtual returns (bool) {
        // If amountOrId is less than or equal to minted, it's an id value like erc721
        if (amountOrId <= minted && amountOrId > 0) {
            address owner = _ownerOf[amountOrId];

            if (msg.sender != owner && !isApprovedForAll[owner][msg.sender]) {
                revert Unauthorized();
            }

            getApproved[amountOrId] = spender;

            emit Approval(owner, spender, amountOrId);
        } else {
            // Otherwise its a fungible amount like erc20
            allowance[msg.sender][spender] = amountOrId;

            emit Approval(msg.sender, spender, amountOrId);
        }

        return true;
    }

    function setApprovalForAll(address operator, bool approved) public virtual {
        isApprovedForAll[msg.sender][operator] = approved;

        emit ApprovalForAll(msg.sender, operator, approved);
    }

    /// @notice Function for mixed transfers, works for both ERC20 and ERC721
    /// @dev This function assumes id / native if amount less than or equal to current max id
    /// @dev If amountOrId is less than or equal to minted, it's an id value like erc721
    /// @dev Otherwise its a fungible amount like erc20
    function transferFrom(
        address from,
        address to,
        uint256 amountOrId
    ) public virtual {
        if (amountOrId <= minted) {
            if (from != _ownerOf[amountOrId]) {
                revert InvalidSender();
            }

            if (to == address(0)) {
                revert InvalidRecipient();
            }
            // If caller is not the owner, approved for all, or approved for this specific token id then revert
            if (
                msg.sender != from &&
                !isApprovedForAll[from][msg.sender] &&
                msg.sender != getApproved[amountOrId]
            ) {
                revert Unauthorized();
            }
        
            // Decrease the balance of the sender by 1 unit aka 10 ** decimals
            balanceOf[from] -= _getUnit();
        
            // Increase the balance of the receiver
            unchecked {
                balanceOf[to] += _getUnit();
            }
          
            // Set the owner of the token id to the receiver
            _ownerOf[amountOrId] = to;
            // Remove any approvals for the token id
            delete getApproved[amountOrId];

            // update _owned for sender
            // Get the last item id in the user's owned array
            uint256 updatedId = _owned[from][_owned[from].length - 1];
          
            // update the last item id to the moved id
            // Get the index of token id being transferred in the user's owned array and update it to the moved token id aka the last item id
            _owned[from][_ownedIndex[amountOrId]] = updatedId;
            // pop the last item id from the user's owned array to delete it since it has a new home
            _owned[from].pop();
            // and update index for the moved id in the user's owned array inside _ownedIndex mapping
            _ownedIndex[updatedId] = _ownedIndex[amountOrId];
            // and then add the moved id to the receiver's owned array
            _owned[to].push(amountOrId);
            // and then update the _ownedIndex index for the transferred token id in the receiver's owned array
            _ownedIndex[amountOrId] = _owned[to].length - 1;

            emit Transfer(from, to, amountOrId);
            emit ERC20Transfer(from, to, _getUnit());
        } else {
            // If amountOrId is a fungible amount like erc20 then check the allowance
            // and revert if the sender does not have enough allowance
            // Then decrease the allowance of the sender by the amount
            // Then transfer the amount from the sender to the receiver
            uint256 allowed = allowance[from][msg.sender];

            if (allowed != type(uint256).max)
                allowance[from][msg.sender] = allowed - amountOrId;

            _transfer(from, to, amountOrId);
        }
    }

    function transfer(
        address to,
        uint256 amount
    ) public virtual returns (bool) {
        return _transfer(msg.sender, to, amount);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id
    ) public virtual {
        transferFrom(from, to, id);

        if (
            to.code.length != 0 &&
            ERC721Receiver(to).onERC721Received(msg.sender, from, id, "") !=
            ERC721Receiver.onERC721Received.selector
        ) {
            revert UnsafeRecipient();
        }
    }

    /// @notice Function for safe ERC721 and ERC20 transfers with callback data
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        bytes calldata data
    ) public virtual {
        transferFrom(from, to, id);

        if (
            to.code.length != 0 &&
            ERC721Receiver(to).onERC721Received(msg.sender, from, id, data) !=
            ERC721Receiver.onERC721Received.selector
        ) {
            revert UnsafeRecipient();
        }
    }

    /// @notice Internal function for ERC20 transfers
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal returns (bool) {
        // Get the fungle unit format to properly calculate the balance
        uint256 unit = _getUnit();
        // Get the balance of the sender before the transfer
        uint256 balanceBeforeSender = balanceOf[from];
        // Get the balance of the receiver before the transfer
        uint256 balanceBeforeReceiver = balanceOf[to];

        // Update the balance of the sender (decrease)
        balanceOf[from] -= amount;

        // Update the balance of the receiver (increase)
        unchecked {
            balanceOf[to] += amount;
        }

        // Skip burn for certain addresses to save gas
        if (!whitelist[from]) {
            uint256 tokens_to_burn = (balanceBeforeSender / unit) -
                (balanceOf[from] / unit);
            for (uint256 i = 0; i < tokens_to_burn; i++) {
                _burn(from);
            }
        }

        // Skip minting for certain addresses to save gas
        if (!whitelist[to]) {
         
            uint256 tokens_to_mint = (balanceOf[to] / unit) -
                (balanceBeforeReceiver / unit);
            for (uint256 i = 0; i < tokens_to_mint; i++) {
                _mint(to);
            }
        }

        emit ERC20Transfer(from, to, amount);
        return true;
    }

    // Internal utility logic
    function _getUnit() internal view returns (uint256) {
        return 10 ** decimals;
    }

    function _mint(address to) internal virtual {
       
        if (to == address(0)) {
            revert InvalidRecipient();
        }

        unchecked {
            minted++;
        }
      
        uint256 id = minted;
       
        if (_ownerOf[id] != address(0)) {
            revert AlreadyExists();
        }

        _ownerOf[id] = to;
        _owned[to].push(id);
        _ownedIndex[id] = _owned[to].length - 1;

        emit Transfer(address(0), to, id);
    }

    function _burn(address from) internal virtual {
        if (from == address(0)) {
            revert InvalidSender();
        }
        // Get the id of the last item in the user's owned array
        uint256 id = _owned[from][_owned[from].length - 1];
        // pop the last item from the user's owned array
        _owned[from].pop();
        // delete the index of the last item in the user's owned array
        delete _ownedIndex[id];
        // delete the owner of the last item
        delete _ownerOf[id];
        // Remove any approvals for the token id
        delete getApproved[id];

        // emit a burn Transfer event
        emit Transfer(from, address(0), id);
    }

    function _setNameSymbol(
        string memory _name,
        string memory _symbol
    ) internal {
        name = _name;
        symbol = _symbol;
    }
}