// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SmartEscrow {
    enum State { AWAITING_PAYMENT, AWAITING_DELIVERY, COMPLETE, REFUNDED, DISPUTED }

    struct Agreement {
        address payable buyer;
        address payable seller;
        uint256 amount;
        State state;
        uint256 createdAt;
    }

    mapping(uint256 => Agreement) public agreements;
    uint256 public agreementCount;
    address public arbiter;

    event AgreementCreated(uint256 agreementId, address buyer, address seller, uint256 amount);
    event PaymentReceived(uint256 agreementId);
    event ItemDelivered(uint256 agreementId);
    event FundsReleased(uint256 agreementId);
    event FundsRefunded(uint256 agreementId);
    event DisputeRaised(uint256 agreementId);
    event DisputeResolved(uint256 agreementId, address winner);

    constructor(address _arbiter) {
        arbiter = _arbiter;
    }

    modifier onlyBuyer(uint256 _agreementId) {
        require(msg.sender == agreements[_agreementId].buyer, "Only buyer can call this function");
        _;
    }

    modifier onlySeller(uint256 _agreementId) {
        require(msg.sender == agreements[_agreementId].seller, "Only seller can call this function");
        _;
    }

    modifier onlyArbiter() {
        require(msg.sender == arbiter, "Only arbiter can call this function");
        _;
    }

    function createAgreement(address payable _seller) external payable returns (uint256) {
        require(msg.value > 0, "Payment amount must be greater than 0");
        
        uint256 agreementId = agreementCount++;
        agreements[agreementId] = Agreement({
            buyer: payable(msg.sender),
            seller: _seller,
            amount: msg.value,
            state: State.AWAITING_DELIVERY,
            createdAt: block.timestamp
        });

        emit AgreementCreated(agreementId, msg.sender, _seller, msg.value);
        emit PaymentReceived(agreementId);

        return agreementId;
    }

    function confirmDelivery(uint256 _agreementId) external onlyBuyer(_agreementId) {
        Agreement storage agreement = agreements[_agreementId];
        require(agreement.state == State.AWAITING_DELIVERY, "Invalid agreement state");

        agreement.state = State.COMPLETE;
        agreement.seller.transfer(agreement.amount);

        emit ItemDelivered(_agreementId);
        emit FundsReleased(_agreementId);
    }

    function refundBuyer(uint256 _agreementId) external onlySeller(_agreementId) {
        Agreement storage agreement = agreements[_agreementId];
        require(agreement.state == State.AWAITING_DELIVERY, "Invalid agreement state");

        agreement.state = State.REFUNDED;
        agreement.buyer.transfer(agreement.amount);

        emit FundsRefunded(_agreementId);
    }

    function raiseDispute(uint256 _agreementId) external {
        Agreement storage agreement = agreements[_agreementId];
        require(msg.sender == agreement.buyer || msg.sender == agreement.seller, "Only buyer or seller can raise a dispute");
        require(agreement.state == State.AWAITING_DELIVERY, "Invalid agreement state");

        agreement.state = State.DISPUTED;

        emit DisputeRaised(_agreementId);
    }

    function resolveDispute(uint256 _agreementId, address payable _winner) external onlyArbiter {
        Agreement storage agreement = agreements[_agreementId];
        require(agreement.state == State.DISPUTED, "Agreement must be in disputed state");
        require(_winner == agreement.buyer || _winner == agreement.seller, "Winner must be buyer or seller");

        agreement.state = State.COMPLETE;
        _winner.transfer(agreement.amount);

        emit DisputeResolved(_agreementId, _winner);
    }

    function getAgreement(uint256 _agreementId) external view returns (
        address, address, uint256, State, uint256
    ) {
        Agreement storage agreement = agreements[_agreementId];
        return (
            agreement.buyer,
            agreement.seller,
            agreement.amount,
            agreement.state,
            agreement.createdAt
        );
    }
}