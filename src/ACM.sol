// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract ACM {
  using EnumerableSet for EnumerableSet.AddressSet;

  EnumerableSet.AddressSet private _admins;
  EnumerableSet.AddressSet private _daoSigners;

  address public immutable DEFAULT_ADMIN;

  error Unauthorized();
  error InvalidParams();

  event AdminAdded(address indexed admin);
  event AdminRemoved(address indexed admin);
  event DaoSignerAdded(address indexed signer);
  event DaoSignerRemoved(address indexed signer);

  constructor() {
    DEFAULT_ADMIN = msg.sender;
  }

  modifier onlyAdmin() {
    if (msg.sender != DEFAULT_ADMIN || _admins.contains(msg.sender)) revert Unauthorized();
    _;
  }

  modifier onlyDaoSigner() {
    if (!_daoSigners.contains(msg.sender)) revert Unauthorized();
    _;
  }

  function addAdmin(address newAdmin) external onlyAdmin {
    if (newAdmin == address(0)) revert InvalidParams();
    _admins.add(newAdmin);
    emit AdminAdded(newAdmin);
  }

  function removeAdmin(address admin) external {
    if (msg.sender != DEFAULT_ADMIN) revert Unauthorized();
    _admins.remove(admin);
    emit AdminRemoved(admin);
  }

  function verifyAdmin(address admin) external view returns (bool) {
    return admin == DEFAULT_ADMIN || _admins.contains(admin);
  }

  function addDaoSigner(address newSigner) external onlyAdmin {
    if (newSigner == address(0)) revert InvalidParams();
    _daoSigners.add(newSigner);
    emit DaoSignerAdded(newSigner);
  }

  function removeDaoSigner(address signer) external {
    if (msg.sender != DEFAULT_ADMIN) revert Unauthorized();
    _daoSigners.remove(signer);
    emit DaoSignerRemoved(signer);
  }

  function verifyDaoSigner(address signer) external view returns (bool) {
    return _daoSigners.contains(signer);
  }

}