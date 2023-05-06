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
        require(isAdminOrOwner[msg.sender]);
        _;
    }

    modifier checkIfWhiteListed() {
        uint256 usersTier = whitelist[msg.sender];
        require(usersTier > 0 || usersTier < 4);
        _;
    }

    event supplyChanged(address indexed, uint256 indexed);
    event Transfer(address recipient, uint256 amount);
    event WhiteListTransfer(address indexed);
    event AddedToWhitelist(address userAddress, uint256 tier);

    constructor(address[] memory _admins, uint256 totalSupply) {
        for (uint256 i = 0; i < administrators.length; ) {
            // you only enter if current address (element grabbed) is not address(0)
            address currAdd = _admins[i];
            administrators[i] = currAdd;
            isAdminOrOwner[currAdd] = true;
            // You only enter here if the current address (element grabbed) is the msg.sender
            if (currAdd == msg.sender) {
                // If the current address (element grabbed)
                balances[currAdd] = totalSupply;
                emit supplyChanged(currAdd, totalSupply);
            }
            unchecked {
                ++i;
            }
        }
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
        if (balances[msg.sender] < _amount) {
            revert InsufficientBalance();
        }
        require(bytes(_name).length < 9);
        balances[msg.sender] -= _amount;
        balances[_recipient] += _amount;
        emit Transfer(_recipient, _amount);
        return true;
    }

    function whiteTransfer(
        address _recipient,
        uint256 _amount
    ) external checkIfWhiteListed {
        if (balances[msg.sender] < _amount) {
            revert InsufficientBalance();
        }
        require(_amount > 3);
        whiteListStruct[msg.sender] = ImportantStruct(
            true,
            msg.sender,
            _amount
        );
        uint256 whiteListedAmt = whitelist[msg.sender];
        // Load that balances[msg.sender] to memory
        // Write two times to memory
        // Write only one time to storage, as writing to memory is cheaper than writing to storage.

        balances[msg.sender] -= _amount;
        balances[_recipient] += _amount;
        balances[msg.sender] += whiteListedAmt;
        balances[_recipient] -= whiteListedAmt;
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
