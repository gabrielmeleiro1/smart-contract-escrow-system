// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract AdvancedSmartEscrow is ReentrancyGuard {
    using SafeMath for uint256;

    struct Party {
        address payable addr;
        bool hasApproved;
    }

    struct Agreement {
        uint256 id;
        Party[] buyers;
        Party[] sellers;
        uint256 amount;
        uint256 expirationDate;
        uint256 releasedAmount;
        uint256 stake;
        bool isDisputed;
        bool isCancelled;
        mapping(address => uint256) stakes;
    }

    mapping(uint256 => Agreement) public agreements;
    uint256 public nextAgreementId;
    uint256 public serviceFeePercentage; // in basis points (1/100 of a percent)
    address payable public owner;

    event AgreementCreated(uint256 indexed agreementId, address[] buyers, address[] sellers, uint256 amount, uint256 expirationDate);
    event FundsDeposited(uint256 indexed agreementId, address depositor, uint256 amount);
    event FundsReleased(uint256 indexed agreementId, address recipient, uint256 amount);
    event AgreementDisputed(uint256 indexed agreementId, address disputeInitiator);
    event DisputeResolved(uint256 indexed agreementId, address winner, uint256 amount);
    event AgreementCancelled(uint256 indexed agreementId);
    event StakeDeposited(uint256 indexed agreementId, address staker, uint256 amount);
    event FundsApproved(uint256 indexed agreementId, address approver, uint256 amount);



    constructor(uint256 _serviceFeePercentage) {
        owner = payable(msg.sender);
        serviceFeePercentage = _serviceFeePercentage;
    }

    function createAgreement(address[] memory _buyers, address[] memory _sellers, uint256 _amount, uint256 _expirationDate) external payable nonReentrant returns (uint256) {
        require(_buyers.length > 0 && _sellers.length > 0, "Both buyers and sellers are required");
        require(_amount > 0, "Amount must be greater than 0");
        require(_expirationDate > block.timestamp, "Expiration date must be in the future");

        uint256 agreementId = nextAgreementId++;
        Agreement storage newAgreement = agreements[agreementId];
        newAgreement.id = agreementId;
        newAgreement.amount = _amount;
        newAgreement.expirationDate = _expirationDate;

        for (uint i = 0; i < _buyers.length; i++) {
            newAgreement.buyers.push(Party({addr: payable(_buyers[i]), hasApproved: false}));
        }
        for (uint i = 0; i < _sellers.length; i++) {
            newAgreement.sellers.push(Party({addr: payable(_sellers[i]), hasApproved: false}));
        }

        emit AgreementCreated(agreementId, _buyers, _sellers, _amount, _expirationDate);
        return agreementId;
    }

    function depositFunds(uint256 _agreementId) external payable nonReentrant {
        Agreement storage agreement = agreements[_agreementId];
        require(block.timestamp < agreement.expirationDate, "Agreement has expired");
        require(!agreement.isCancelled, "Agreement is cancelled");
        require(msg.value > 0, "Must deposit some funds");

        bool isBuyer = false;
        for (uint i = 0; i < agreement.buyers.length; i++) {
            if (agreement.buyers[i].addr == msg.sender) {
                isBuyer = true;
                break;
            }
        }
        require(isBuyer, "Only buyers can deposit funds");

        emit FundsDeposited(_agreementId, msg.sender, msg.value);
    }

function releaseFunds(uint256 _agreementId, uint256 _amount) external nonReentrant {
    Agreement storage agreement = agreements[_agreementId];
    require(!agreement.isDisputed, "Agreement is disputed");
    require(!agreement.isCancelled, "Agreement is cancelled");
    require(_amount > 0 && _amount <= agreement.amount.sub(agreement.releasedAmount), "Invalid release amount");

    bool isBuyer = false;
    uint buyerIndex;
    for (uint i = 0; i < agreement.buyers.length; i++) {
        if (agreement.buyers[i].addr == msg.sender) {
            isBuyer = true;
            buyerIndex = i;
            break;
        }
    }
    require(isBuyer, "Only buyers can release funds");

    agreement.buyers[buyerIndex].hasApproved = true;

    bool allBuyersApproved = true;
    for (uint i = 0; i < agreement.buyers.length; i++) {
        if (!agreement.buyers[i].hasApproved) {
            allBuyersApproved = false;
            break;
        }
    }

    if (allBuyersApproved) {
        uint256 serviceFee = _amount.mul(serviceFeePercentage).div(10000);
        uint256 amountAfterFee = _amount.sub(serviceFee);

        agreement.releasedAmount = agreement.releasedAmount.add(_amount);

        for (uint i = 0; i < agreement.sellers.length; i++) {
            uint256 sellerShare = amountAfterFee.div(agreement.sellers.length);
            agreement.sellers[i].addr.transfer(sellerShare);
            emit FundsReleased(_agreementId, agreement.sellers[i].addr, sellerShare);
        }

        owner.transfer(serviceFee);
    } else {
        emit FundsApproved(_agreementId, msg.sender, _amount);
    }
}

    function initiateDispute(uint256 _agreementId) external nonReentrant {
        Agreement storage agreement = agreements[_agreementId];
        require(!agreement.isDisputed, "Dispute already initiated");
        require(!agreement.isCancelled, "Agreement is cancelled");
        require(block.timestamp < agreement.expirationDate, "Agreement has expired");

        bool isParty = false;
        for (uint i = 0; i < agreement.buyers.length; i++) {
            if (agreement.buyers[i].addr == msg.sender) {
                isParty = true;
                break;
            }
        }
        for (uint i = 0; i < agreement.sellers.length; i++) {
            if (agreement.sellers[i].addr == msg.sender) {
                isParty = true;
                break;
            }
        }
        require(isParty, "Only agreement parties can initiate a dispute");

        agreement.isDisputed = true;
        emit AgreementDisputed(_agreementId, msg.sender);
    }

    function resolveDispute(uint256 _agreementId, address payable _winner) external nonReentrant {
        require(msg.sender == owner, "Only owner can resolve disputes");
        Agreement storage agreement = agreements[_agreementId];
        require(agreement.isDisputed, "No active dispute");

        uint256 totalAmount = address(this).balance;
        uint256 serviceFee = totalAmount.mul(serviceFeePercentage).div(10000);
        uint256 winnerAmount = totalAmount.sub(serviceFee);

        _winner.transfer(winnerAmount);
        owner.transfer(serviceFee);

        agreement.isDisputed = false;
        emit DisputeResolved(_agreementId, _winner, winnerAmount);
    }

    function cancelAgreement(uint256 _agreementId) external nonReentrant {
        Agreement storage agreement = agreements[_agreementId];
        require(!agreement.isDisputed, "Cannot cancel a disputed agreement");
        require(!agreement.isCancelled, "Agreement already cancelled");
        require(block.timestamp < agreement.expirationDate, "Agreement has expired");

        bool isParty = false;
        for (uint i = 0; i < agreement.buyers.length; i++) {
            if (agreement.buyers[i].addr == msg.sender) {
                isParty = true;
                break;
            }
        }
        for (uint i = 0; i < agreement.sellers.length; i++) {
            if (agreement.sellers[i].addr == msg.sender) {
                isParty = true;
                break;
            }
        }
        require(isParty, "Only agreement parties can cancel");

        agreement.isCancelled = true;

        uint256 totalAmount = address(this).balance;
        uint256 buyerShare = totalAmount.div(agreement.buyers.length);

        for (uint i = 0; i < agreement.buyers.length; i++) {
            agreement.buyers[i].addr.transfer(buyerShare);
        }

        emit AgreementCancelled(_agreementId);
    }

    function depositStake(uint256 _agreementId) external payable nonReentrant {
        Agreement storage agreement = agreements[_agreementId];
        require(!agreement.isCancelled, "Agreement is cancelled");
        require(block.timestamp < agreement.expirationDate, "Agreement has expired");

        bool isParty = false;
        for (uint i = 0; i < agreement.buyers.length; i++) {
            if (agreement.buyers[i].addr == msg.sender) {
                isParty = true;
                break;
            }
        }
        for (uint i = 0; i < agreement.sellers.length; i++) {
            if (agreement.sellers[i].addr == msg.sender) {
                isParty = true;
                break;
            }
        }
        require(isParty, "Only agreement parties can stake");

        agreement.stakes[msg.sender] = agreement.stakes[msg.sender].add(msg.value);
        agreement.stake = agreement.stake.add(msg.value);

        emit StakeDeposited(_agreementId, msg.sender, msg.value);
    }

    function getAgreementDetails(uint256 _agreementId) external view returns (
        uint256 id,
        uint256 amount,
        uint256 expirationDate,
        uint256 releasedAmount,
        uint256 stake,
        bool isDisputed,
        bool isCancelled
    ) {
        Agreement storage agreement = agreements[_agreementId];
        return (
            agreement.id,
            agreement.amount,
            agreement.expirationDate,
            agreement.releasedAmount,
            agreement.stake,
            agreement.isDisputed,
            agreement.isCancelled
        );
    }

    function setServiceFeePercentage(uint256 _newFeePercentage) external {
        require(msg.sender == owner, "Only owner can set fee");
        require(_newFeePercentage <= 1000, "Fee cannot exceed 10%");
        serviceFeePercentage = _newFeePercentage;
    }
}
