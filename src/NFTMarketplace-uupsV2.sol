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

    // 映射：NFT合约地址 => tokenId => 出售信息
    mapping(address => mapping(uint256 => Listing)) public listings;

    // 用于记录已经使用过的签名，防止重放攻击
    mapping(bytes32 => bool) public usedSignatures;

    event NFTListed(address indexed nftAddress, uint256 indexed tokenId, uint256 price, address indexed seller);
    event NFTBought(address indexed nftAddress, uint256 indexed tokenId, address indexed buyer);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize(IERC20 _token, address _initialOwner) public initializer {
        __Ownable_init(_initialOwner);
        __UUPSUpgradeable_init();

        token = _token;
    }

    // 授权升级合约的权限，仅限所有者
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // 卖家直接上架NFT
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

    // 使用离线签名上架NFT
    function listWithSignature(
        address nftAddress,
        uint256 tokenId,
        uint256 price,
        bytes memory signature
    ) public {
        // 生成消息哈希
        bytes32 messageHash = keccak256(abi.encodePacked(nftAddress, tokenId, price));
        require(!usedSignatures[messageHash], "Signature already used");

        // 恢复签名者地址
        address signer = recoverSigner(messageHash, signature);
        IERC721 nft = IERC721(nftAddress);
        require(signer == nft.ownerOf(tokenId), "Invalid signature");

        // 检查市场合约是否被批准操作NFT
        require(
            nft.getApproved(tokenId) == address(this) || nft.isApprovedForAll(signer, address(this)),
            "Marketplace not approved"
        );

        // 标记签名已使用
        usedSignatures[messageHash] = true;

        // 上架NFT
        listings[nftAddress][tokenId] = Listing(price, signer);
        emit NFTListed(nftAddress, tokenId, price, signer);
    }

    // 买家购买NFT
    function buyNFT(address nftAddress, uint256 tokenId) public {
        Listing memory listing = listings[nftAddress][tokenId];
        require(listing.price > 0, "NFT not listed");

        // 检查买家是否已批准市场合约转移其代币
        require(token.allowance(msg.sender, address(this)) >= listing.price, "Token allowance too low");

        // 使用 SafeERC20 确保安全的代币转移
        token.safeTransferFrom(msg.sender, listing.seller, listing.price);

        // 转移 NFT 给买家
        IERC721(nftAddress).safeTransferFrom(listing.seller, msg.sender, tokenId);

        // 删除出售信息
        delete listings[nftAddress][tokenId];
        emit NFTBought(nftAddress, tokenId, msg.sender);
    }

    // 恢复签名者地址
    function recoverSigner(bytes32 messageHash, bytes memory signature) public pure returns (address) {
        // 以太坊签名消息前缀
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
        return recover(ethSignedMessageHash, signature);
    }

    // 使用 ecrecover 恢复地址
    function recover(bytes32 hash, bytes memory signature) internal pure returns (address) {
        require(signature.length == 65, "Invalid signature length");

        bytes32 r;
        bytes32 s;
        uint8 v;

        // 拆分签名
        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }

        return ecrecover(hash, v, r, s);
    }

    // 为了保持可升级合约的存储布局，需要调整 __gap 的大小
    uint256[49] private __gap;
}