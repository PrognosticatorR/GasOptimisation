// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

contract GasContract {
    mapping(address => uint256) public balances;
    mapping(address => uint256) public whitelist;
    mapping(address => bool) isAdminOrOwner;
    mapping(address => ImportantStruct) public whiteListStruct;
    address[5] public administrators;

    struct ImportantStruct {
        bool paymentStatus;
        address sender;
        uint256 amount;
    }

    error InsufficientBalance();

    modifier onlyAdminOrOwner() {
        assembly {
            // Get free memory pointer
            let ptr := mload(0x40)
            // Allocate in memory | add, isAdminOrOwner.slot |
            mstore(ptr, caller())
            mstore(add(ptr, 0x20), isAdminOrOwner.slot)
            // Calculate storasge slot hashing our memory with keccak256(). We are hashing 64B.
            let slot := keccak256(ptr, 0x40)

            // If value isAdminOrOwner[msg.sender] = false, revert.
            if iszero(sload(slot)) {
                revert(0, 0) // we are not returnig anything
            }
        }
        _;
    }

    modifier checkIfWhiteListed() {
        assembly {
            // Get free memory pointer
            let ptr := mload(0x40)
            // Allocate in memory | add, whitelist.slot |
            mstore(ptr, caller())
            mstore(add(ptr, 0x20), whitelist.slot)
            // Calculate storasge slot hashing our memory with keccak256(). We are hashing 64B.
            let slot := keccak256(ptr, 0x40)
            // As we have our storage slot, we can make an storage load to get the storage value for that address (msg.sender).
            let usersTier := sload(slot)

            // If out of our desired range, revert.
            if or(lt(usersTier, 0), gt(usersTier, 4)) {
                revert(0, 0)
            }
        }
        _;
    }

    event supplyChanged(address indexed, uint256 indexed);
    event Transfer(address recipient, uint256 amount);
    event WhiteListTransfer(address indexed);
    event AddedToWhitelist(address userAddress, uint256 tier);

    constructor(address[] memory _admins, uint256 totalSupply) {
        for (uint256 i = 0; i < administrators.length; ) {
            address currAdd = _admins[i];
            administrators[i] = currAdd;
            isAdminOrOwner[currAdd] = true;
            unchecked {
                ++i;
            }
        }
        balances[msg.sender] = totalSupply;
        emit supplyChanged(msg.sender, totalSupply);
    }

    function addToWhitelist(
        address _userAddrs,
        uint256 _tier
    ) external onlyAdminOrOwner {
        require(_tier < 255);
        whitelist[_userAddrs] = (_tier == 1) ? 1 : (_tier == 2)
            ? 2
            : (_tier > 3)
            ? 3
            : _tier;
        emit AddedToWhitelist(_userAddrs, _tier);
    }

    function balanceOf(address _user) external view returns (uint256 balance_) {
        uint256 balance = balances[_user];
        return balance;
    }

    function transfer(
        address _recipient,
        uint256 _amount,
        string calldata _name
    ) external returns (bool status_) {
        require(bytes(_name).length < 9);
        uint256 senderSlot;
        uint256 sendBalance;
        assembly {
            // Get free memory pointer
            let ptr := mload(0x40)
            // Allocate in memory | add, balances.slot |
            mstore(ptr, caller())
            mstore(add(ptr, 0x20), balances.slot)
            // Calculate storasge slot hashing our memory with keccak256(). We are hashing 64B.
            senderSlot := keccak256(ptr, 0x40)
            // As we have our storage slot, we can make an storage load to get the current balance for that address (msg.sender).
            sendBalance := sload(senderSlot)

            if lt(sendBalance, _amount) {
                // Store function selector of InsufficientBalance() in memory.
                mstore(ptr, 0xf4d678b8)
                // Revert using 4 bytes of function selector.
                revert(ptr, 4)
            }
        }

        assembly {
            // Update storage subtracting amount to sender.
            sstore(senderSlot, sub(sendBalance, _amount))

            // Same as above, but this time for the recipient. We will overwrite the memory as we don't need previous values anymore. In this way, we optimise the expansion.
            // Get free memory pointer
            let ptr := mload(0x40)
            // Allocate in memory | add, balances.slot |
            mstore(ptr, _recipient)
            // Calculate storasge slot hashing our memory with keccak256(). We are hashing 64B.
            let recpSlot := keccak256(ptr, 0x40)
            // recpBalance is sload(recpSlot)
            sstore(recpSlot, add(sload(recpSlot), _amount))
        }
        emit Transfer(_recipient, _amount);
        return true;
    }

    function whiteTransfer(
        address _recipient,
        uint256 _amount
    ) external checkIfWhiteListed {
        require(_amount > 3);
        uint256 senderSlot;
        uint256 sendBalance;
        assembly {
            // Get free memory pointer
            let ptr := mload(0x40)
            // Allocate in memory | add, balances.slot |
            mstore(ptr, caller())
            mstore(add(ptr, 0x20), balances.slot)
            // Calculate storasge slot hashing our memory with keccak256(). We are hashing 64B.
            senderSlot := keccak256(ptr, 0x40)
            // As we have our storage slot, we can make an storage load to get the current balance for that address (msg.sender).
            sendBalance := sload(senderSlot)

            if lt(sendBalance, _amount) {
                // Store function selector of InsufficientBalance() in memory.
                mstore(ptr, 0xf4d678b80)
                // Revert using 4 bytes of function selector.
                revert(ptr, 4)
            }
        }

        whiteListStruct[msg.sender] = ImportantStruct(
            true,
            msg.sender,
            _amount
        );

        uint256 whiteListedAmt = whitelist[msg.sender];
        assembly {
            // Update storage subtracting amount to sender and adding whiteListedAmt.
            sstore(senderSlot, add(sub(sendBalance, _amount), whiteListedAmt))

            // Get free memory pointer
            let ptr := mload(0x40)
            // Allocate in memory | add, balances.slot |
            mstore(ptr, _recipient)
            // Calculate storage slot hashing our memory with keccak256(). We are hashing 64B.
            let recpSlot := keccak256(ptr, 0x40)
            // As we have our storage slot, we can make an storage load to get the current balance for that address (recipient).
            // recpBalance is sload(recpSlot)
            // Update storage adding amount to recipient and subtracting whiteListedAmt.
            sstore(recpSlot, sub(add(sload(recpSlot), _amount), whiteListedAmt))
        }
        emit WhiteListTransfer(_recipient);
    }

    function getPaymentStatus(
        address sender
    ) external view returns (bool, uint256) {
        return (
            whiteListStruct[sender].paymentStatus,
            whiteListStruct[sender].amount
        );
    }
}
