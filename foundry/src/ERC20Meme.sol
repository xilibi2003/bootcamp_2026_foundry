// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {
    IERC20
} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {
    IERC20Metadata
} from "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract ERC20Meme is IERC20, IERC20Metadata {
    error AlreadyInitialized();
    error ZeroAddress();
    error OnlyFactory();
    error ExceedsMaxSupply();
    error InsufficientBalance();
    error InsufficientAllowance();

    string private _name;
    string private _symbol;
    uint8 private constant _DECIMALS = 18;

    uint256 private _totalSupply;
    uint256 public maxSupply;
    address public factory;
    uint256 public perMint;
    bool public initialized;

    mapping(address account => uint256) private _balances;
    mapping(address owner => mapping(address spender => uint256))
        private _allowances;

    // constructor

    function initialize(
        string calldata symbol_,
        uint256 totalSupply_,
        uint256 perMint_,
        address factory_
    ) external {
        if (initialized) revert AlreadyInitialized();
        if (factory_ == address(0)) {
            revert ZeroAddress();
        }

        initialized = true;
        factory = factory_;
        maxSupply = totalSupply_;
        perMint = perMint_;
        _name = symbol_;
        _symbol = symbol_;
    }

    function mintTo(address to) external returns (uint256 mintedAmount) {
        if (msg.sender != factory) revert OnlyFactory();
        if (to == address(0)) revert ZeroAddress();

        mintedAmount = perMint;
        _mint(to, mintedAmount);
    }

    function name() external view returns (string memory) {
        return _name;
    }

    function symbol() external view returns (string memory) {
        return _symbol;
    }

    function decimals() external pure returns (uint8) {
        return _DECIMALS;
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function allowance(
        address tokenOwner,
        address spender
    ) external view returns (uint256) {
        return _allowances[tokenOwner][spender];
    }

    function transfer(address to, uint256 value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();

        _allowances[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool) {
        uint256 currentAllowance = _allowances[from][msg.sender];
        if (currentAllowance < value) revert InsufficientAllowance();

        unchecked {
            _allowances[from][msg.sender] = currentAllowance - value;
        }
        emit Approval(from, msg.sender, _allowances[from][msg.sender]);

        _transfer(from, to, value);
        return true;
    }

    function _transfer(address from, address to, uint256 value) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();

        uint256 fromBalance = _balances[from];
        if (fromBalance < value) revert InsufficientBalance();

        unchecked {
            _balances[from] = fromBalance - value;
            _balances[to] += value;
        }

        emit Transfer(from, to, value);
    }

    function _mint(address to, uint256 value) internal {
        if (to == address(0)) revert ZeroAddress();
        if (_totalSupply + value > maxSupply) revert ExceedsMaxSupply();

        _totalSupply += value;
        _balances[to] += value;
        emit Transfer(address(0), to, value);
    }
}
