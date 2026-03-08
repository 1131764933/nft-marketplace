// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "./NFTMarketplace.sol";
// import "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
// import "nft-marketplace/lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
contract NFTMarketplaceV2 is Initializable, UUPSUpgradeable, NFTMarketplace {
    mapping(bytes32 => bool) public usedSignatures;

    function initialize(IERC20 _token, address _initialOwner) public override initializer {
        __NFTMarketplace_init(_token, _initialOwner);
    }

    function __NFTMarketplace_init(IERC20 _token, address _initialOwner) internal initializer {
        __Ownable_init(_initialOwner);
        token = _token;
    }

    function listWithSignature(
        address nftAddress,
        uint256 tokenId,
        uint256 price,
        bytes memory signature
    ) public {
        bytes32 messageHash = keccak256(abi.encodePacked(nftAddress, tokenId, price));
        require(!usedSignatures[messageHash], "Signature already used");

        address signer = recoverSigner(messageHash, signature);
        require(signer == IERC721(nftAddress).ownerOf(tokenId), "Invalid signature");

        usedSignatures[messageHash] = true;
        super.list(nftAddress, tokenId, price);
    }

    function recoverSigner(bytes32 messageHash, bytes memory signature) public pure returns (address) {
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
        return recover(ethSignedMessageHash, signature);
    }

    function recover(bytes32 hash, bytes memory signature) internal pure returns (address) {
        (uint8 v, bytes32 r, bytes32 s) = splitSignature(signature);
        return ecrecover(hash, v, r, s);
    }

    function splitSignature(bytes memory sig) internal pure returns (uint8 v, bytes32 r, bytes32 s) {
        require(sig.length == 65, "Invalid signature length");

        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
