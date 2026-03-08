// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
contract NFTMarketplace is Initializable, OwnableUpgradeable {
    IERC20 public token;
    struct Listing {
        uint256 price;
        address seller;
    }

    mapping(address => mapping(uint256 => Listing)) public listings;

    event NFTListed(address indexed nftAddress, uint256 indexed tokenId, uint256 price, address indexed seller);
    event NFTBought(address indexed nftAddress, uint256 indexed tokenId, address indexed buyer);

    function initialize(IERC20 _token, address _initialOwner) public virtual initializer {
        __Ownable_init(_initialOwner);
        token = _token;
    }

    function list(address nftAddress, uint256 tokenId, uint256 price) public {
        IERC721 nft = IERC721(nftAddress);
        require(nft.ownerOf(tokenId) == msg.sender, "Not the owner");
        require(nft.isApprovedForAll(msg.sender, address(this)), "Marketplace not approved");

        listings[nftAddress][tokenId] = Listing(price, msg.sender);
        emit NFTListed(nftAddress, tokenId, price, msg.sender);
    }

    function buyNFT(address nftAddress, uint256 tokenId) public {
        Listing memory listing = listings[nftAddress][tokenId];
        require(listing.price > 0, "NFT not listed");

        token.transferFrom(msg.sender, listing.seller, listing.price);
        IERC721(nftAddress).safeTransferFrom(listing.seller, msg.sender, tokenId);

        delete listings[nftAddress][tokenId];
        emit NFTBought(nftAddress, tokenId, msg.sender);
    }
}
