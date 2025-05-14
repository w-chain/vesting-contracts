// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IACM {
    function verifyAdmin(address admin) external view returns (bool); 
    function verifyDaoSigner(address signer) external view returns (bool);
}