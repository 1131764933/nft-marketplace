// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title NFTMarketplace
 * @dev 生产级 NFT 市场合约
 * 
 * 功能：
 * 1. 上架 NFT (list)
 * 2. 购买 NFT (buy)
 * 3. 签名上架 (listWithSignature)
 * 4. 下架 NFT (cancelListing)
 * 5. 提取收益 (withdraw)
 * 
 * 安全特性：
 * - 重入保护 (ReentrancyGuard)
 * - Checks-Effects-Interactions 模式
 * - 平台手续费
 * - ECDSA 签名验证
 */
contract NFTMarketplace is Initializable, OwnableUpgradeable, ReentrancyGuard, UUPSUpgradeable {
    
    // ============ 事件 ============
    event NFTListed(
        address indexed nftAddress, 
        uint256 indexed tokenId, 
        uint256 price, 
        address indexed seller
    );
    event NFTBought(
        address indexed nftAddress, 
        uint256 indexed tokenId, 
        address indexed buyer,
        uint256 price
    );
    event ListingCancelled(
        address indexed nftAddress, 
        uint256 indexed tokenId,
        address indexed seller
    );
    event FeeWithdrawn(address indexed owner, uint256 amount);
    event PlatformFeeUpdated(uint256 newFee);

    // ============ 错误定义 ============
    error NotNFTOwner();
    error NotApproved();
    error NotListed();
    error AlreadyListed();
    error InsufficientPayment();
    error TransferFailed();
    error InvalidSignature();
    error SignatureUsed();
    error FeeTooHigh();

    // ============ 数据结构 ============
    struct Listing {
        uint256 price;
        address seller;
    }

    // ============ 状态变量 ============
    
    /// @notice 支付代币
    IERC20 public token;
    
    /// @notice NFT 上架信息
    mapping(address => mapping(uint256 => Listing)) public listings;
    
    /// @notice 已使用的签名
    mapping(bytes32 => bool) public usedSignatures;
    
    /// @notice 平台手续费 (百分比, 基准 10000)
    uint256 public platformFee = 250; // 2.5%
    
    /// @notice 最高手续费 (10%)
    uint256 public constant MAX_FEE = 1000;
    
    /// @notice 累计手续费
    uint256 public accumulatedFees;

    // ============ 初始化 ============
    
    function initialize(
        IERC20 _token, 
        address _initialOwner
    ) public virtual initializer {
        __Ownable_init(_initialOwner);
        token = _token;
    }

    // ============ 核心功能 ============

    /**
     * @notice 上架 NFT
     */
    function list(
        address nftAddress, 
        uint256 tokenId, 
        uint256 price
    ) external nonReentrant {
        // 1. 验证卖家是 NFT 所有者
        IERC721 nft = IERC721(nftAddress);
        if (nft.ownerOf(tokenId) != msg.sender) {
            revert NotNFTOwner();
        }
        
        // 2. 验证市场已授权
        if (!nft.isApprovedForAll(msg.sender, address(this))) {
            revert NotApproved();
        }
        
        // 3. 验证价格有效
        if (price == 0) {
            revert InsufficientPayment();
        }
        
        // 4. 检查是否已上架
        if (listings[nftAddress][tokenId].seller != address(0)) {
            revert AlreadyListed();
        }
        
        // 5. 记录上架信息
        listings[nftAddress][tokenId] = Listing(price, msg.sender);
        
        emit NFTListed(nftAddress, tokenId, price, msg.sender);
    }

    /**
     * @notice 购买 NFT
     * @dev 使用 Checks-Effects-Interactions 模式防止重入
     */
    function buy(
        address nftAddress, 
        uint256 tokenId
    ) external nonReentrant {
        // ============ Checks ============
        Listing memory listing = listings[nftAddress][tokenId];
        
        if (listing.seller == address(0)) {
            revert NotListed();
        }
        
        // ============ Effects ============
        uint256 price = listing.price;
        address seller = listing.seller;
        
        // 计算手续费
        uint256 fee = (price * platformFee) / 10000;
        uint256 sellerAmount = price - fee;
        
        // 删除上架信息
        delete listings[nftAddress][tokenId];
        
        // 累计手续费
        accumulatedFees += fee;
        
        emit NFTBought(nftAddress, tokenId, msg.sender, price);
        
        // ============ Interactions ============
        
        // 1. 先转 NFT 给买家
        IERC721(nftAddress).safeTransferFrom(seller, msg.sender, tokenId);
        
        // 2. 再转代币给卖家
        // 注意：这里使用 safeTransfer 或检查返回值
        if (!token.transferFrom(msg.sender, seller, sellerAmount)) {
            revert TransferFailed();
        }
    }

    /**
     * @notice 签名上架 (可选)
     */
    function listWithSignature(
        address nftAddress,
        uint256 tokenId,
        uint256 price,
        bytes calldata signature
    ) external nonReentrant {
        // 1. 生成消息哈希
        bytes32 messageHash = keccak256(abi.encode(
            nftAddress, 
            tokenId, 
            price, 
            msg.sender
        ));
        
        // 2. 检查签名是否已使用
        if (usedSignatures[messageHash]) {
            revert SignatureUsed();
        }
        
        // 3. 验证签名
        bytes32 ethSignedMessageHash = ECDSA.toEthSignedMessageHash(messageHash);
        address signer = ECDSA.recover(ethSignedMessageHash, signature);
        
        // 验证签名者是 NFT 所有者
        if (signer != IERC721(nftAddress).ownerOf(tokenId)) {
            revert InvalidSignature();
        }
        
        // 4. 标记签名已使用
        usedSignatures[messageHash] = true;
        
        // 5. 调用 list 上架
        list(nftAddress, tokenId, price);
    }

    /**
     * @notice 取消上架
     */
    function cancelListing(
        address nftAddress, 
        uint256 tokenId
    ) external nonReentrant {
        Listing memory listing = listings[nftAddress][tokenId];
        
        if (listing.seller != msg.sender) {
            revert NotNFTOwner();
        }
        
        delete listings[nftAddress][tokenId];
        
        emit ListingCancelled(nftAddress, tokenId, msg.sender);
    }

    /**
     * @notice 提取平台手续费
     */
    function withdrawFees() external onlyOwner nonReentrant {
        uint256 amount = accumulatedFees;
        
        if (amount == 0) {
            revert TransferFailed();
        }
        
        accumulatedFees = 0;
        
        if (!token.transferFrom(address(this), owner(), amount)) {
            revert TransferFailed();
        }
        
        emit FeeWithdrawn(owner(), amount);
    }

    // ============ 管理员功能 ============

    /**
     * @notice 设置平台手续费
     */
    function setPlatformFee(uint256 newFee) external onlyOwner {
        if (newFee > MAX_FEE) {
            revert FeeTooHigh();
        }
        platformFee = newFee;
        emit PlatformFeeUpdated(newFee);
    }

    // ============ UUPS 升级 ============
    
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // ============ 辅助函数 ============

    /**
     * @notice 获取上架信息
     */
    function getListing(
        address nftAddress, 
        uint256 tokenId
    ) external view returns (Listing memory) {
        return listings[nftAddress][tokenId];
    }

    /**
     * @notice 检查 NFT 是否已上架
     */
    function isListed(
        address nftAddress, 
        uint256 tokenId
    ) external view returns (bool) {
        return listings[nftAddress][tokenId].seller != address(0);
    }
}
