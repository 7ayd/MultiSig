// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

contract MultiSigWallet {
    event Deposit(address indexed sender, uint256 amount, uint256 balance);
    event SubmitTransaction(
        address indexed owner, uint256 indexed txIndex, address indexed to, uint256 value, bytes data
    );
    event ConfirmTransaction(address indexed owner, uint256 indexed txIndex);
    event RevokeConfirmation(address indexed owner, uint256 indexed txIndex);
    event ExecuteTransaction(address indexed owner, uint256 indexed txIndex);

    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public numberOfConfirmationsRequired;

    struct Transcation {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        mapping(address => bool) isConfirmed;
        uint256 numConfirmations;
    }

    Transaction[] public transactions;

    modifier onlyOwner() {
        require(isOwner[msg.sender], "not owner");
        _;
    }

    modifier txExists(uint256 _txIndex) {
        require(_txIndex < transactions.length, "tx does not exist");
        _;
    }

    modifier txNotExecuted(uint256 _txIndex) {
        require(!transactions[_txIndex].executed, "tx already executed");
        _;
    }

    modifier txNotConfirmed(uint256 _txIndex) {
        require(!transactions[_txIndex].isConfirmed[msg.sender], "tx already confirmed");
        _;
    }

    constructor(address[] memory _owners, uint256 _numOfConfirmationRequired) {
        require(_owners.length > 0, "owners required");
        require(
            _numOfConfirmationRequired > 0 && _numOfConfirmationRequired <= _owners.length,
            "invalid number of required confirmations"
        );

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "invalid owner");
            require(!isOwner[owner], "owner not unique");

            isOwner[owner] = true;
            owners.push(owner);
        }

        numberOfConfirmationsRequired = _numOfConfirmationRequired;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    function submitTracation(address _to, uint256 _value, bytes memory _data) public onlyOwner {
        uint256 txIndex = transactions.length;

        transactions.push(Transaction({to: _to, value: _value, data: _data, executed: false, numConfirmations: 0}));

        emit SubmitTransaction(msg.sender, txIndex, _to, _value, _data);
    }

    function confirmTransaction(uint256 _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        txNotExecuted(_txIndex)
        txNotConfirmed(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];
        transaction.isConfirmed[msg.sender] = true;
        transaction.numConfirmations += 1;

        emit ConfirmTransaction(msg.sender, _txIndex);
    }

    function executeTransaction(uint256 _txIndex) public onlyOwner txExists(_txIndex) txNotExecuted(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];
        require(transaction.confirmations >= numberOfConfirmationsRequired, "cannot execute tx");
        transaction.executed = true;

        (bool success,) = transaction.to.call{value: transaction.value}(transaction.data);
        require(success, "tx failed");

        emit ExecuteTransaction(msg.sender, _txIndex);
    }

    function revokeConfirmation(uint256 _txIndex) public txExists(_txIndex) txNotExecuted(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];
        require(transaction.isConfirmed[msg.sender], "tx not confirmed");
        transaction.isConfirmed[msg.sender] = false;
        transaction.numConfirmations -= 1;

        emit RevokeConfirmation(msg.sender, _txIndex);
    }
}
