// SPDX-License-Identifier: MIT

/**
 * @title ComTpassERC721
 * @author monmo2023
 * @notice NFT contract with minting and transfer functions
 */

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract ComTpassERC721 is ERC721Enumerable, ERC721URIStorage, Ownable, Pausable {
    using Strings for uint256;

    // Configuration variables
    string private _baseUri;
    string private _baseExtension;
    uint256 private _cost;
    uint256 private _maxSupply;
    uint256 private _maxMintAmount;

    // Access control lists
    mapping(address => bool) private _whitelisted;
    mapping(address => bool) private _vipList;

    // VIP upgrade price
    uint256 private _vipPrice;

    // Modifiers
    modifier onlyVIP() {
        require(_vipList[msg.sender], "Only VIP can access this function");
        _;
    }

    modifier onlyAdminOrOwner() {
        require(_vipList[msg.sender] || msg.sender == owner(), "Only admins or owner can access this function");
        _;
    }

    // Events
    event PassTransfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event AuthenticityVerified(address indexed owner, uint256 indexed tokenId);

    /**
     * @dev Contract constructor
     * @param _name The name of the token
     * @param _symbol The symbol of the token
     * @param _initBaseURI The base URI for token metadata
     * @param _initCost The cost of minting an NFT
     * @param _initMaxSupply The maximum supply of NFTs
     * @param _initMaxMintAmount The maximum number of NFTs that can be minted per transaction
     * @param _initVipPrice The price to upgrade to VIP status
     */
    constructor(
        string memory _name,
        string memory _symbol,
        string memory _initBaseURI,
        uint256 _initCost,
        uint256 _initMaxSupply,
        uint256 _initMaxMintAmount,
        uint256 _initVipPrice
    ) ERC721(_name, _symbol) {
        setBaseURI(_initBaseURI);
        setCost(_initCost);
        setMaxSupply(_initMaxSupply);
        setMaxMintAmount(_initMaxMintAmount);
        setVipPrice(_initVipPrice);
        mint(msg.sender, 20);
    }

    // Admin and configuration functions
    function addToVIPList(address[] memory addresses) public onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            _vipList[addresses[i]] = true;
        }
    }

    function addToWhitelist(address[] memory addresses) public onlyAdminOrOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            _whitelisted[addresses[i]] = true;
        }
    }

    function removeFromVIPList(address[] memory addresses) public onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            _vipList[addresses[i]] = false;
        }
    }

    function setBaseExtension(string memory newBaseExtension) public onlyOwner {
        _baseExtension = newBaseExtension;
    }

    function setBaseURI(string memory newBaseURI) public onlyOwner {
        _baseUri = newBaseURI;
    }

    function setCost(uint256 newCost) public onlyOwner {
        _cost = newCost;
    }

    function setMaxMintAmount(uint256 newMaxMintAmount) public onlyOwner {
        _maxMintAmount = newMaxMintAmount;
    }

    function setMaxSupply(uint256 newMaxSupply) public onlyOwner {
        _maxSupply = newMaxSupply;
    }

    function setVipPrice(uint256 newVipPrice) public onlyOwner {
        _vipPrice = newVipPrice;
    }


    /**
     * @dev Mints NFTs to the specified recipient
     * @param to The address of the recipient
     * @param mintAmount The number of NFTs to mint
     */
    function mint(address to, uint256 mintAmount) public payable whenNotPaused {
        uint256 supply = totalSupply();
        require(_whitelisted[msg.sender], "Not whitelisted");
        require(!paused(), "Sale paused");
        require(mintAmount > 0, "Need to mint at least 1 NFT");
        require(mintAmount <= _maxMintAmount, "Max mint amount per transaction exceeded");
        require(supply + mintAmount <= _maxSupply, "Exceeds max supply");
        require(msg.value >= _cost * mintAmount, "Ether value sent is not correct");

        for (uint256 i = 1; i <= mintAmount; i++) {
            _safeMint(to, supply + i);
            _setTokenURI(supply + i, tokenURI(supply + i));
        }
    }

    /**
     * @dev Transfers ownership of an NFT to another address
     * @param to The address to transfer to
     * @param tokenId The ID of the token to transfer
     */
    function transferPass(address to, uint256 tokenId) public {
        require(_isApprovedOrOwner(msg.sender, tokenId), "Transfer not authorized");
        require(!_isContract(to), "Transfer to contract not allowed");

        _transfer(msg.sender, to, tokenId);
        emit PassTransfer(msg.sender, to, tokenId);
    }

    /**
     * @dev Verifies the authenticity of an NFT
     * @param tokenId The ID of the token to verify
     * @notice Only VIP users can call this function
     */
    function verifyAuthenticity(uint256 tokenId) public onlyVIP {
        require(_exists(tokenId), "Token does not exist");
        emit AuthenticityVerified(ownerOf(tokenId), tokenId);
    }

    /**
     * @dev Gets the token URI of an NFT
     * @param tokenId The ID of the token
     * @return The token URI
     */
    function getPassInfo(uint256 tokenId) public view returns (string memory) {
        require(_exists(tokenId), "Token does not exist");
        return tokenURI(tokenId);
    }

    /**
     * @dev Checks if an address is a VIP
     * @param user The address to check
     * @return A boolean indicating if the address is a VIP
     */
    function isVIP(address user) public view returns (bool) {
        return _vipList[user];
    }

    // Rest of the contract...

    /**
     * @dev Overrides the ERC721 function to support additional interfaces
     * @param interfaceId The ID of the interface to check
     * @return A boolean indicating if the interface is supported
     */
    function supportsInterface(bytes4 interfaceId) public view override(ERC721Enumerable, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev Overrides the ERC721URIStorage function to include the base extension
     * @param tokenId The ID of the token
     * @return The token URI
     */
    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        return string(abi.encodePacked(_baseURI(), tokenId.toString(), _baseExtension));
    }

    /**
     * @dev Overrides the transferFrom function to emit the PassTransfer event
     * @param from The address to transfer from
     * @param to The address to transfer to
     * @param tokenId The ID of the token to transfer
     */
    function transferFrom(address from, address to, uint256 tokenId) public override(ERC721, IERC721) {
        super.transferFrom(from, to, tokenId);
        emit PassTransfer(from, to, tokenId);
    }

    /**
     * @dev Internal function to burn a token
     * @param tokenId The ID of the token to burn
     */
    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    /**
     * @dev Internal function to check if an address is a contract
     * @param addr The address to check
     * @return A boolean indicating if the address is a contract
     */
    function _isContract(address addr) private view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(addr)
        }
        return size > 0;
    }

    /**
     * @dev Internal function to handle token transfers before the transfer
     * @param from The address to transfer from
     * @param to The address to transfer to
     * @param tokenId The ID of the token to transfer
     * @param batchSize The number of tokens being transferred
     */
    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal
        whenNotPaused
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }
}
