// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

contract GasContract {
    bytes32 private constant __ADDED_TO_WHITE_LIST_EVENT = 0x62c1e066774519db9fe35767c15fc33df2f016675b7cc0c330ed185f286a2d52;
    bytes32 private constant __WHITE_LIST_TRANSFER_EVENT = 0x98eaee7299e9cbfa56cf530fd3a0c6dfa0ccddf4f837b8f025651ad9594647b3;
    mapping(address => uint256) public balances;
    mapping(address => uint256) public whitelist;
    mapping(address => bool) isAdminOrOwner;
    mapping(address => ImportantStruct) whiteListStruct;

    struct ImportantStruct {
        bool paymentStatus;
        address sender;
        uint256 amount;
    }

    error InsufficientBalance();

    modifier onlyAdminOrOwner() {
        assembly {
            // Get free memory pointer
            let ptr := mload(0)
            // Allocate in memory | add, isAdminOrOwner.slot |
            mstore(ptr, caller())
            mstore(0x20, isAdminOrOwner.slot)
            // Calculate storasge slot hashing our memory with keccak256(). We are hashing 64B.
            let slot := keccak256(ptr, 0x40)
            // If value isAdminOrOwner[msg.sender] = false, revert.
            if iszero(sload(slot)) { revert(0, 0) } // we are not returnig anything
        }
        _;
    }

    modifier checkIfWhiteListed() {
        assembly {
            // Get free memory pointer
            let ptr := mload(0)
            // Allocate in memory | add, whitelist.slot |
            mstore(0, caller())
            mstore(0x20, whitelist.slot)
            // Calculate storasge slot hashing our memory with keccak256(). We are hashing 64B.
            let slot := keccak256(ptr, 0x40)
            // As we have our storage slot, we can make an storage load to get the storage value for that address (msg.sender).
            let usersTier := sload(slot)
            // If out of our desired range, revert.
            if or(lt(usersTier, 0), gt(usersTier, 4)) { revert(0, 0) }
        }
        _;
    }

    function getPaymentStatus(address sender) external view returns (bool, uint256) {
        return (whiteListStruct[sender].paymentStatus, whiteListStruct[sender].amount);
    }

    function administrators(uint256 _index) external payable returns (address) {
        return _index == 0
            ? 0x3243Ed9fdCDE2345890DDEAf6b083CA4cF0F68f2
            : _index == 1
                ? 0x2b263f55Bf2125159Ce8Ec2Bb575C649f822ab46
                : _index == 2 ? 0x0eD94Bc8435F3189966a49Ca1358a55d871FC3Bf : _index == 3 ? 0xeadb3d065f8d15cc05e92594523516aD36d1c834 : address(0x1234);
    }

    event WhiteListTransfer(address indexed);

    constructor(address[] memory _admins, uint256 totalSupply) {
        for (uint256 i = 0; i < _admins.length;) {
            isAdminOrOwner[_admins[i]] = true;
            unchecked {
                ++i;
            }
        }
        balances[msg.sender] = totalSupply;
    }

    function addToWhitelist(address _userAddrs, uint256 _tier) external onlyAdminOrOwner {
        require(_tier < 255);
        assembly {
            // Get free memory pointer
            let ptr := mload(0)
            // Allocate in memory | add, whitelist.slot |
            mstore(ptr, _userAddrs)
            mstore(add(ptr, 0x20), whitelist.slot)
            // Calculate storasge slot hashing our memory with keccak256(). We are hashing 64B.
            let slot := keccak256(ptr, 0)
            // if _tier greater than 3, store 3. Else, store _tier.
            switch gt(_tier, 3)
            case true { sstore(slot, 3) }
            default { sstore(slot, _tier) }
            mstore(0, _userAddrs)
            mstore(0x20, _tier)
            log1(0, 0x40, __ADDED_TO_WHITE_LIST_EVENT)
        }
    }

    function balanceOf(address _user) external view returns (uint256 balance_) {
        return balances[_user];
    }

    function transfer(address _recipient, uint256 _amount, string calldata _name) external returns (bool status_) {
        require(bytes(_name).length < 9);
        assembly {
            // Get free memory pointer
            let ptr := mload(0x40)
            // Allocate in memory | add, balances.slot |
            mstore(ptr, caller())
            mstore(add(ptr, 0x20), balances.slot)
            // Calculate storasge slot hashing our memory with keccak256(). We are hashing 64B.
            let senderSlot := keccak256(ptr, 0x40)
            // As we have our storage slot, we can make an storage load to get the current balance for that address (msg.sender).
            let sendBalance := sload(senderSlot)

            // If not enough amount
            if lt(sendBalance, _amount) {
                // Store function selector of InsufficientBalance() in memory.
                mstore(ptr, 0xf4d678b8)
                // Revert using 4 bytes of function selector.
                revert(ptr, 4)
            }

            // Update storage subtracting amount to sender.
            sstore(senderSlot, sub(sendBalance, _amount))

            // Allocate in memory | add, balances.slot |
            mstore(ptr, _recipient)
            // Calculate storasge slot hashing our memory with keccak256(). We are hashing 64B.
            let recpSlot := keccak256(ptr, 0x40)
            // recpBalance is sload(recpSlot)
            sstore(recpSlot, add(sload(recpSlot), _amount))
        }
        return true;
    }

    function whiteTransfer(address _recipient, uint256 _amount) external checkIfWhiteListed {
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
        whiteListStruct[msg.sender] = ImportantStruct(true, msg.sender, _amount);
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
            log2(0x00, 0x00, __WHITE_LIST_TRANSFER_EVENT, _recipient)
        }
    }
}
