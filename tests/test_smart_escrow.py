import pytest
from brownie import SmartEscrow, accounts, reverts

@pytest.fixture
def smart_escrow():
    arbiter = accounts[0]
    return SmartEscrow.deploy(arbiter, {'from': arbiter})

def test_create_agreement(smart_escrow):
    buyer = accounts[1]
    seller = accounts[2]
    amount = 1e18  # 1 ETH

    initial_balance = buyer.balance()
    tx = smart_escrow.createAgreement(seller, {'from': buyer, 'value': amount})
    
    assert tx.events['AgreementCreated']['buyer'] == buyer
    assert tx.events['AgreementCreated']['seller'] == seller
    assert tx.events['AgreementCreated']['amount'] == amount
    assert buyer.balance() == initial_balance - amount
    
    agreement = smart_escrow.getAgreement(0)
    assert agreement[0] == buyer
    assert agreement[1] == seller
    assert agreement[2] == amount
    assert agreement[3] == 1  # State.AWAITING_DELIVERY

def test_confirm_delivery(smart_escrow):
    buyer = accounts[1]
    seller = accounts[2]
    amount = 1e18  # 1 ETH

    smart_escrow.createAgreement(seller, {'from': buyer, 'value': amount})
    
    initial_balance = seller.balance()
    tx = smart_escrow.confirmDelivery(0, {'from': buyer})
    
    assert tx.events['ItemDelivered'] is not None
    assert tx.events['FundsReleased'] is not None
    assert seller.balance() == initial_balance + amount
    
    agreement = smart_escrow.getAgreement(0)
    assert agreement[3] == 2  # State.COMPLETE

def test_refund_buyer(smart_escrow):
    buyer = accounts[1]
    seller = accounts[2]
    amount = 1e18  # 1 ETH

    smart_escrow.createAgreement(seller, {'from': buyer, 'value': amount})
    
    initial_balance = buyer.balance()
    tx = smart_escrow.refundBuyer(0, {'from': seller})
    
    assert tx.events['FundsRefunded'] is not None
    assert buyer.balance() == initial_balance + amount
    
    agreement = smart_escrow.getAgreement(0)
    assert agreement[3] == 3  # State.REFUNDED

def test_raise_dispute(smart_escrow):
    buyer = accounts[1]
    seller = accounts[2]
    amount = 1e18  # 1 ETH

    smart_escrow.createAgreement(seller, {'from': buyer, 'value': amount})
    tx = smart_escrow.raiseDispute(0, {'from': buyer})
    
    assert tx.events['DisputeRaised'] is not None
    
    agreement = smart_escrow.getAgreement(0)
    assert agreement[3] == 4  # State.DISPUTED

def test_resolve_dispute(smart_escrow):
    arbiter = accounts[0]
    buyer = accounts[1]
    seller = accounts[2]
    amount = 1e18  # 1 ETH

    smart_escrow.createAgreement(seller, {'from': buyer, 'value': amount})
    smart_escrow.raiseDispute(0, {'from': buyer})
    
    initial_balance = seller.balance()
    tx = smart_escrow.resolveDispute(0, seller, {'from': arbiter})
    
    assert tx.events['DisputeResolved']['winner'] == seller
    assert seller.balance() == initial_balance + amount
    
    agreement = smart_escrow.getAgreement(0)
    assert agreement[3] == 2  # State.COMPLETE

def test_only_buyer_can_confirm_delivery(smart_escrow):
    buyer = accounts[1]
    seller = accounts[2]
    amount = 1e18  # 1 ETH

    smart_escrow.createAgreement(seller, {'from': buyer, 'value': amount})
    
    with reverts("Only buyer can call this function"):
        smart_escrow.confirmDelivery(0, {'from': seller})

def test_only_seller_can_refund(smart_escrow):
    buyer = accounts[1]
    seller = accounts[2]
    amount = 1e18  # 1 ETH

    smart_escrow.createAgreement(seller, {'from': buyer, 'value': amount})
    
    with reverts("Only seller can call this function"):
        smart_escrow.refundBuyer(0, {'from': buyer})

def test_only_arbiter_can_resolve_dispute(smart_escrow):
    buyer = accounts[1]
    seller = accounts[2]
    amount = 1e18  # 1 ETH

    smart_escrow.createAgreement(seller, {'from': buyer, 'value': amount})
    smart_escrow.raiseDispute(0, {'from': buyer})
    
    with reverts("Only arbiter can call this function"):
        smart_escrow.resolveDispute(0, seller, {'from': buyer})