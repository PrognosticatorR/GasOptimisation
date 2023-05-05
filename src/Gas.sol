// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

contract GasContract {
    mapping(address => uint256) public balances;
    uint8 constant tradePercent = 12;
    mapping(address => uint256) public whitelist;
    mapping(address => bool) isAdminOrOwner;
    mapping(address => ImportantStruct) public whiteListStruct;
    address[5] public administrators;

    struct ImportantStruct {
        uint256 amount;
        uint16 valueA; // max 3 digits
        uint16 valueB; // max 3 digits
        bool paymentStatus;
        address sender;
    }

    error InsufficientBalance();

    modifier onlyAdminOrOwner() {
        if (!isAdminOrOwner[msg.sender]) {
            revert("onlyAdminOrOwner modifier");
            _;
        }
        _;
    }

    modifier checkIfWhiteListed(address sender) {
        uint256 usersTier = whitelist[msg.sender];
        require(usersTier > 0 || usersTier < 4, "not whitelisted");
        _;
    }

    event supplyChanged(address indexed, uint256 indexed);
    event Transfer(address recipient, uint256 amount);
    event WhiteListTransfer(address indexed);
    event AddedToWhitelist(address userAddress, uint256 tier);

    constructor(address[] memory _admins, uint256 totalSupply) {
        for (uint256 i = 0; i < administrators.length; i++) {
            if (_admins[i] != address(0)) {
                administrators[i] = _admins[i];
                isAdminOrOwner[administrators[i]] = true;
                if (_admins[i] == msg.sender) {
                    balances[msg.sender] = totalSupply;
                    emit supplyChanged(_admins[i], totalSupply);
                } else if (_admins[i] != msg.sender) {
                    emit supplyChanged(_admins[i], 0);
                }
            }
        }
    }

    function balanceOf(address _user) external view returns (uint256 balance_) {
        uint256 balance = balances[_user];
        return balance;
    }

    function transfer(address _recipient, uint256 _amount, string calldata _name) external returns (bool status_) {
        if (balances[msg.sender] < _amount) {
            revert InsufficientBalance();
        }
        require(bytes(_name).length < 9, "name too long");
        balances[msg.sender] -= _amount;
        balances[_recipient] += _amount;
        emit Transfer(_recipient, _amount);
        bool[] memory status = new bool[](tradePercent);
        for (uint256 i = 0; i < tradePercent;) {
            status[i] = true;
            unchecked {
                ++i;
            }
        }
        return (status[0] == true);
    }

    function addToWhitelist(address _userAddrs, uint256 _tier) external onlyAdminOrOwner {
        require(_tier < 255, "_tier < 255");
        whitelist[_userAddrs] = _tier;
        if (_tier > 3) {
            whitelist[_userAddrs] = 3;
        } else if (_tier == 1) {
            whitelist[_userAddrs] = 1;
        } else if (_tier > 0 && _tier < 3) {
            whitelist[_userAddrs] = 2;
        }
        emit AddedToWhitelist(_userAddrs, _tier);
    }

    function whiteTransfer(address _recipient, uint256 _amount) external checkIfWhiteListed(msg.sender) {
        whiteListStruct[msg.sender] = ImportantStruct(_amount, 0, 0, true, msg.sender);

        if (balances[msg.sender] < _amount) {
            revert InsufficientBalance();
        }
        require(_amount > 3, "_amount > 3");
        balances[msg.sender] -= _amount;
        balances[_recipient] += _amount;
        balances[msg.sender] += whitelist[msg.sender];
        balances[_recipient] -= whitelist[msg.sender];

        emit WhiteListTransfer(_recipient);
    }

    function getPaymentStatus(address sender) external view returns (bool, uint256) {
        return (whiteListStruct[sender].paymentStatus, whiteListStruct[sender].amount);
    }
}
