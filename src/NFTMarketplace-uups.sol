// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract NFTMarketplace is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    using SafeERC20 for IERC20;

    IERC20 public token;

    struct Listing {
        uint256 price;
        address seller;
    }

    mapping(address => mapping(uint256 => Listing)) public listings;

    event NFTListed(address indexed nftAddress, uint256 indexed tokenId, uint256 price, address indexed seller);
    event NFTBought(address indexed nftAddress, uint256 indexed tokenId, address indexed buyer);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize(IERC20 _token, address _initialOwner) public initializer {
        __Ownable_init(_initialOwner);
        __UUPSUpgradeable_init();

        token = _token;
        // 不再需要调用 _transferOwnership，因为 __Ownable_init 已经设置了所有者
    }

    // 实现 _authorizeUpgrade 函数，限制升级权限为合约所有者
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function list(address nftAddress, uint256 tokenId, uint256 price) public {
        IERC721 nft = IERC721(nftAddress);
        require(nft.ownerOf(tokenId) == msg.sender, "Not the owner");

        require(
            nft.getApproved(tokenId) == address(this) || nft.isApprovedForAll(msg.sender, address(this)),
            "Marketplace not approved"
        );

        listings[nftAddress][tokenId] = Listing(price, msg.sender);
        emit NFTListed(nftAddress, tokenId, price, msg.sender);
    }

    function buyNFT(address nftAddress, uint256 tokenId) public {
        Listing memory listing = listings[nftAddress][tokenId];
        require(listing.price > 0, "NFT not listed");

        // 检查买家是否已批准市场合约转移其代币
        require(token.allowance(msg.sender, address(this)) >= listing.price, "Token allowance too low");

        // 使用 SafeERC20 以确保安全的代币转移
        token.safeTransferFrom(msg.sender, listing.seller, listing.price);

        // 转移 NFT 给买家
        IERC721(nftAddress).safeTransferFrom(listing.seller, msg.sender, tokenId);

        delete listings[nftAddress][tokenId];
        emit NFTBought(nftAddress, tokenId, msg.sender);
    }

    // 为了保持可升级合约的存储布局，需要添加一个保留空间
    uint256[50] private __gap;
}