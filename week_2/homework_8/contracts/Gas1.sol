// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";

contract Constants {
    
    uint8 constant tradeFlag = 1;
    uint8 constant basicFlag = 0;
    uint8 constant dividendFlag = 1;
    
}

contract GasContract is Ownable, Constants {
    error Unauthorized();
    error InsufficientBalance();
    error NameTooLong();
    error AmountTooLow();
    error IncompatibleTier();
    error IDError();
    error InvalidAddress();
    
    uint256 public immutable totalSupply; // cannot be updated
    uint256 public paymentCounter;
    uint256 constant tradePercent = 12;
    address public contractOwner;
    uint256 public tradeMode;
    address[5] public administrators; 

    enum PaymentType {
        Unknown,
        BasicPayment,
        Refund,
        Dividend,
        GroupPayment
    }

    // PaymentType constant defaultPayment = PaymentType.Unknown;

    mapping(address => uint256) public balances;
    mapping(address => Payment[]) public payments;
    History[] public paymentHistory; // when a payment was updated
    mapping(address => uint8) public whitelist;

    struct Payment {
        uint256 paymentID;
        bool adminUpdated;
        PaymentType paymentType;
        address recipient;
        bytes8 recipientName; // max 8 characters
        address admin; // administrators address
        uint256 amount;
    }

    struct History {
        uint256 blockNumber;
        uint256 lastUpdate;
        address updatedBy;
    }

    event AddedToWhitelist(address userAddress, uint8 tier);

    modifier onlyAdminOrOwner() {

        if(checkForAdmin(msg.sender)) {
            _;
        }
        else if(msg.sender == contractOwner) {
            _;
        }
        else{
            revert Unauthorized();
        }

    }

    event supplyChanged(address indexed, uint256 indexed);
    event Transfer(address recipient, uint256 amount);
    event PaymentUpdated(
        address admin,
        uint256 ID,
        uint256 amount,
        bytes8 recipient
    );
    event WhiteListTransfer(address indexed);

    constructor(address[] memory _admins, uint256 _totalSupply) {
        
        contractOwner = msg.sender;
        totalSupply = _totalSupply;

        for (uint256 ii = 0; ii < administrators.length; ii++) {

            if (_admins[ii] != address(0)) {
                
                administrators[ii] = _admins[ii];

                if (_admins[ii] == msg.sender) {
                
                    balances[msg.sender] = _totalSupply;
                    emit supplyChanged(_admins[ii], _totalSupply);

                } 

                else {

                    balances[_admins[ii]] = 0;
                    emit supplyChanged(_admins[ii], 0);

                }

            }
        }
    
    }

    function getPaymentHistory()
        public
        returns (History[] memory paymentHistory_)
    {
        return paymentHistory;
    }

    function checkForAdmin(address _user) public view returns (bool) {
        // bool admin = false;
        for (uint256 ii = 0; ii < administrators.length; ii++) {
            if (administrators[ii] == _user) {
                return true;
            }
        }
        return false;
        // return admin;
    }

    function balanceOf(address _user) public view returns (uint256 balance_) {
        uint256 balance = balances[_user];
        return balance;
    }

    function getTradingMode() public view returns (bool) {
        // bool mode = false;
        if (tradeFlag == 1 || dividendFlag == 1) {
            // mode = true;
            return true;
        } else {
            // mode = false;
            return false;
        }
        // return mode;
    }

    function addHistory(address _updateAddress, bool _tradeMode)
        public
        returns (bool status_, bool tradeMode_)
    {
        History memory history;
        history.blockNumber = block.number;
        history.lastUpdate = block.timestamp;
        history.updatedBy = _updateAddress;
        paymentHistory.push(history);
        bool[] memory status = new bool[](tradePercent);
        for (uint256 i = 0; i < tradePercent; i++) {
            status[i] = true;
        }
        return ((status[0] == true), _tradeMode);
    }

    function getPayments(address _user)
        public
        view
        returns (Payment[] memory payments_)
    {
        require(
            _user != address(0),
            "Gas Contract - getPayments function - User must have a valid non zero address"
        );
        return payments[_user];
    }

    function transfer(
        address _recipient,
        uint256 _amount,
        string memory _name
    ) public returns (bool status_) {
        
        if (balances[msg.sender] < _amount) {
            revert InsufficientBalance();
        }

        if (bytes(_name).length > 8) {
            revert NameTooLong();
        }

        balances[msg.sender] -= _amount;
        balances[_recipient] += _amount;
        emit Transfer(_recipient, _amount);
        Payment memory payment;
        payment.admin = address(0);
        payment.adminUpdated = false;
        payment.paymentType = PaymentType.BasicPayment;
        payment.recipient = _recipient;
        payment.amount = _amount;
        payment.recipientName = bytes8(bytes(_name));
        payment.paymentID = ++paymentCounter;
        payments[msg.sender].push(payment);
        bool[] memory status = new bool[](tradePercent);
        for (uint256 i = 0; i < tradePercent; i++) {
            status[i] = true;
        }
        return (status[0] == true);
    }

    function updatePayment(
        address _user,
        uint256 _ID,
        uint256 _amount,
        PaymentType _type
    ) public onlyAdminOrOwner {
        // require(
        //     _ID > 0,
        //     "Gas Contract - Update Payment function - ID must be greater than 0"
        // );
        if (_ID == 0) {
            revert IDError();
        }

        if (_amount == 0) {
            revert AmountTooLow();
        }

        // require(
        //     _amount > 0,
        //     "Gas Contract - Update Payment function - Amount must be greater than 0"
        // );
        if (_user == address(0)) {
            revert InvalidAddress();
        }

        // require(
        //     _user != address(0),
        //     "Gas Contract - Update Payment function - Administrator must have a valid non zero address"
        // );

        for (uint256 ii = 0; ii < payments[_user].length; ii++) {
            if (payments[_user][ii].paymentID == _ID) {
                payments[_user][ii].adminUpdated = true;
                payments[_user][ii].admin = _user;
                payments[_user][ii].paymentType = _type;
                payments[_user][ii].amount = _amount;
                bool tradingMode = getTradingMode();
                addHistory(_user, tradingMode);
                emit PaymentUpdated(
                    msg.sender,
                    _ID,
                    _amount,
                    payments[_user][ii].recipientName
                );
            }
        }
    }

    function addToWhitelist(address _userAddrs, uint8 _tier)
        public
        onlyAdminOrOwner
    {

        if(_tier > 254 || _tier == 0) {
            revert IncompatibleTier();
        }
        
        if (_tier >= 3 ){
            whitelist[_userAddrs] = 3; 
        }

        else{
            whitelist[_userAddrs] = _tier;
        }

        emit AddedToWhitelist(_userAddrs, _tier);
    }

    function whiteTransfer(address _recipient, uint256 _amount) public {
        
        if (balances[msg.sender] < _amount) {
            revert InsufficientBalance();
        }

        if (_amount < 4) {
            revert AmountTooLow();
        }

        uint sender_balance = balances[msg.sender];
        uint recipient_balance = balances[_recipient];

        sender_balance = sender_balance + whitelist[msg.sender] - _amount;
        recipient_balance = recipient_balance + _amount - whitelist[msg.sender] ;

        balances[msg.sender] = sender_balance;
        balances[_recipient] = recipient_balance;
        
        emit WhiteListTransfer(_recipient);

    }
}