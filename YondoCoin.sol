pragma solidity ^0.4.18;

import "github.com/OpenZeppelin/zeppelin-solidity/contracts/token/ERC20/MintableToken.sol";
import "github.com/OpenZeppelin/zeppelin-solidity/contracts/ownership/HasNoTokens.sol";
import "github.com/OpenZeppelin/zeppelin-solidity/contracts/ownership/HasNoEther.sol";
import "github.com/OpenZeppelin/zeppelin-solidity/contracts/ownership/Contactable.sol";
import "github.com/OpenZeppelin/zeppelin-solidity/contracts/token/ERC20/TokenTimelock.sol";

/**
 * @title YON, YondoCoin token
 * 
 * YondoCoin is used as a form of settlement between participant transactions
 * and to reward users and partnerships within the Yondo Ecosystem
 * 
 * Uses OpenZeppelin StandardToken, MintableToken
 */
contract YondoCoin is Contactable, HasNoTokens, HasNoEther, MintableToken {
    
    string public constant name = "YondoCoin"; // solium-disable-line uppercase
    string public constant symbol = "YON"; // solium-disable-line uppercase
    uint8 public constant decimals = 18; // solium-disable-line uppercase
    
    bool public saleFinished = false;
    bool public reservedTokensCreated = false;
    
    uint256 public crowdsaleSupply;
    
    // timelocks
    TokenTimelock public advisorsTimelock;
    TokenTimelock public marketingTimelock;
    TokenTimelock public companyTimelock_06m;
    TokenTimelock public companyTimelock_12m;
    TokenTimelock public companyTimelock_18m;
    TokenTimelock public companyTimelock_24m;
    TokenTimelock public companyTimelock_30m;
    TokenTimelock public companyTimelock_36m;
    
    uint256 public constant ONE_TOKENS = 1 ether;
    uint256 public constant MILLION_TOKENS = (10**6) * ONE_TOKENS;
    
    uint256 public constant supplyCap = 200 * MILLION_TOKENS;
    uint256 public constant crowdsaleCap = 100 * MILLION_TOKENS;
    
    
    
    modifier saleIsOn() {
        require(!saleFinished);
        _;
    }
    
    function YondoCoin() 
    Ownable()
    Contactable()
    HasNoTokens()
    HasNoEther()
    MintableToken()
    {
        contactInformation = 'https://tokensale.yondo.com/';
    }
    
    /**
    * @dev Override of mint function which enforces supply cap.
    * This is called when minting bounty tokens before sale is finished.
    */
    function mint(address _to, uint256 _amount) onlyOwner canMint public returns (bool) {
        require(totalSupply_.add(_amount) <= supplyCap);
        return super.mint(_to, _amount);
    }
    
    /**
    * @dev Function to mint tokens which are sold as part of the  crowdsale
    * @param _to The address that will receive the minted tokens.
    * @param _amount The amount of tokens to mint.
    * @return A boolean that indicates if the operation was successful.
    */
    function mintCrowdsale(address _to, uint256 _amount) onlyOwner canMint saleIsOn public returns (bool) {
        require(crowdsaleSupply.add(_amount) <= crowdsaleCap);
        if(mint(_to, _amount)){
            crowdsaleSupply = crowdsaleSupply.add(_amount);
            return true;
        }
        else {
            return false;
        }
    }
    
    function finishSale() onlyOwner saleIsOn public returns (bool) {
        saleFinished = true;
        return true;
    }
    
    /**
     * @dev One-time-use method to create special tokens specified in white paper specifically section 13 YondoCoin Token Sale. 
     * @param _yondoInc The address that will receive the minted tokens allocated to Yondo Inc.
     * @param _yondoRewards The address that will receive the minted tokens allocated to Yondo Ecosystem Rewards.
     * Must be run after finishSale() and before finishMinting()
     */
    function createReservedTokens(address _yondoInc, address _yondoRewards) onlyOwner canMint public {
        require(saleFinished);
        require(!reservedTokensCreated);
        require(_yondoInc != 0x0);
        require(_yondoRewards != 0x0);
        
        // Remainder of bounty allocation. Some minting may have already occurred for the bounty.
        // Equals 2% of the crowdsale minus what has already been allocated.
        uint256 bountyUsed = totalSupply_.sub(crowdsaleSupply);
        if(percentage(crowdsaleSupply, 2) > bountyUsed) {
            uint256 bountyRemainder = percentage(crowdsaleSupply, 2).sub(bountyUsed);
            mint(_yondoInc, bountyRemainder);
        }
        
        uint64 months = 1 years / 12;     
        
        // Advisors locked for 6 months
        uint256 advisorsTotal = percentage(crowdsaleSupply, 2);
        advisorsTimelock = mintAndGrant(_yondoInc, advisorsTotal, now + (6 * months));
        
        // Marketing locked for 3 months
        uint256 marketingTotal = percentage(crowdsaleSupply, 2);
        marketingTimelock = mintAndGrant(_yondoInc, marketingTotal, now + (3 * months));
        
        // Company releases - 6 equal installments over a period of 3 years
        uint256 companyTotal = percentage(crowdsaleSupply, 14);
        uint256 companyInstallment = companyTotal / 6;
        companyTimelock_06m = mintAndGrant(_yondoInc, companyInstallment, now + (6 * months));
        companyTimelock_12m = mintAndGrant(_yondoInc, companyInstallment, now + (12 * months));
        companyTimelock_18m = mintAndGrant(_yondoInc, companyInstallment, now + (18 * months));
        companyTimelock_24m = mintAndGrant(_yondoInc, companyInstallment, now + (24 * months));
        companyTimelock_30m = mintAndGrant(_yondoInc, companyInstallment, now + (30 * months));
        companyTimelock_36m = mintAndGrant(_yondoInc, companyInstallment, now + (36 * months));
        
        // Ecosystem Reward Tokens - fixed at 80M Tokens
        uint256 rewardsTotal = percentage(crowdsaleSupply, 80);
        mint(_yondoRewards, rewardsTotal);
        
        reservedTokensCreated = true;
    }
    
    
    /*
     * Internal methods
     */
    
    
    function mintAndGrant(address _to, uint256 _value, uint256 _unlock) internal returns (TokenTimelock) {
        TokenTimelock timelock = new TokenTimelock(this, _to, _unlock);
        mint(timelock, _value);
        return timelock;
    }
    
    function percentage(uint amount, uint _percentage) internal pure returns (uint256) {
        return amount * _percentage / 100;
    }
}
