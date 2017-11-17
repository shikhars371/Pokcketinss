pragma solidity 0.4.18;

/// @title Abstract token contract - Functions to be implemented by token contracts.
contract Token {

    uint public totalSupply;
    
    function totalSupply() public constant returns(uint total_Supply);

    function balanceOf(address who) public constant returns(uint256);

    function allowance(address owner, address spender) public constant returns(uint);

    function transferFrom(address from, address to, uint value) public returns(bool ok);

    function approve(address spender, uint value) public returns(bool ok);

    function transfer(address to, uint value)public returns(bool ok);

    event Transfer(address indexed from, address indexed to, uint value);

    event Approval(address indexed owner, address indexed spender, uint value);

}

/// @title Standard token contract - Standard token interface implementation.
contract PocketinnsToken is Token {

    /*
     *  Token meta data
     */
    string constant public name = "Pocketinns Token";
    string constant public symbol = "Pinns";
    uint8 constant public decimals = 18;
    address public owner;
    address public dutchAuctionAddress;
    
     modifier onlyForDutchAuctionContract() {
        if (msg.sender != dutchAuctionAddress)
            // Only owner is allowed to proceed
            revert();
        _;
    }
    
    
    /*
     *  Data structures
     */
    mapping (address => uint256) balances;
    mapping (address => mapping (address => uint256)) allowed;
    uint256 public totalSupply;

    /*
     *  Public functions
     */
 
    
    function PocketinnsToken(address dutchAuction) public
    {
        owner = msg.sender;
        totalSupply = 150000000 * 10**18;
        balances[dutchAuction] = 30000000 * 10**18;
        dutchAuctionAddress = dutchAuction;  // we have stored the dutch auction contract address for burning tokens present after ITO
    }
    
    function burnLeftItoTokens(uint _burnValue)
    public
    onlyForDutchAuctionContract
    {
 
        totalSupply -=_burnValue;
        balances[dutchAuctionAddress] = 0;
    }
     
    /// @dev Transfers sender's tokens to a given address. Returns success.
    /// @param _to Address of token receiver.
    /// @param _value Number of tokens to transfer.
    /// @return Returns success of function call.
    function transfer(address _to, uint256 _value)
        public
        returns (bool)
    {
        if (balances[msg.sender] < _value) {
            // Balance too low
            revert();
        }
        balances[msg.sender] -= _value;
        balances[_to] += _value;
        Transfer(msg.sender, _to, _value);
        return true;
    }

    /// @dev Allows allowed third party to transfer tokens from one address to another. Returns success.
    /// @param _from Address from where tokens are withdrawn.
    /// @param _to Address to where tokens are sent.
    /// @param _value Number of tokens to transfer.
    /// @return Returns success of function call.
    function transferFrom(address _from, address _to, uint256 _value)
        public
        returns (bool)
    {
        if (balances[_from] < _value || allowed[_from][msg.sender] < _value) {
            // Balance or allowance too low
            revert();
        }
        balances[_to] += _value;
        balances[_from] -= _value;
        allowed[_from][msg.sender] -= _value;
        Transfer(_from, _to, _value);
        return true;
    }

    /// @dev Sets approved amount of tokens for spender. Returns success.
    /// @param _spender Address of allowed account.
    /// @param _value Number of approved tokens.
    /// @return Returns success of function call.
    function approve(address _spender, uint256 _value)
        public
        returns (bool)
    {
        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }

    /*
     * Read functions
     */
    /// @dev Returns number of allowed tokens for given address.
    /// @param _owner Address of token owner.
    /// @param _spender Address of token spender.
    /// @return Returns remaining allowance for spender.
    function allowance(address _owner, address _spender)
        constant
        public
        returns (uint256)
    {
        return allowed[_owner][_spender];
    }

    /// @dev Returns number of tokens owned by given address.
    /// @param _owner Address of token owner.
    /// @return Returns balance of owner.
    function balanceOf(address _owner)
        constant
        public
        returns (uint256)
    {
        return balances[_owner];
    }
}

contract pinnsDutchAuction
    {
    
    
    uint constant public MAX_TOKENS = 30000000 * 10**18; // 30M pinns Token
    uint constant public minimumInvestment = 1 * 10**18; // 1 ether is minimum minimumInvestment        
    uint constant public goodwillTokensAmount = 5000000 * 10**18; // 5M pinns Token
    
    Stages public stage;
    
     /*
     *  Enums
     */
    enum Stages {
        AuctionDeployed,
        AuctionSetUp,
        AuctionStarted,
        AuctionEnded,
        goodwillDistributionStarted
    }
     
     /*
     *  Storage
     */
    PocketinnsToken public pinnsToken;
    address public owner;
    uint public ceiling;
    uint public priceFactor;
  
  
    /*
     *  Store to maintain the status and details of the investors,
     *  who invest in first four days for distributing goodwill bonus tokens
     */
    
    uint public day1Count;
    uint public day2Count;
    uint public day3Count;
    uint public day4Count;
    
    uint public day1Bonus;
    uint public day2Bonus;
    uint public day3Bonus;
    uint public day4Bonus;
    
    mapping (address => bool) public statusDay1; 
    mapping (address => bool) public statusDay2;
    mapping (address => bool) public statusDay3;
    mapping (address => bool) public statusDay4;
    
     /*
     *  Variables to store the total amount recieved per day
     */
    uint public day1Recieved;
    uint public day2Recieved;
    uint public day3Recieved;
    uint public day4Recieved;
    uint public totalReceived;
    


    uint public startItoTimestamp; // to store the starting time of the ITO
    uint public pricePerToken;
    uint public startPricePerToken;
    uint public currentPerTokenPrice;   
    uint public finalPrice;
    uint public totalTokensSold;
    
    mapping (address => uint) public noBonusDays;
    mapping (address => uint) public itoBids;
    event ito(address investor, uint amount, string day);
    
     /*
     *  Modifiers
     */
     
    modifier atStage(Stages _stage) {
        if (stage != _stage)
            // Contract not in expected state
            revert();
        _;
    }

    modifier isOwner() {
        if (msg.sender != owner)
            // Only owner is allowed to proceed
            revert();
        _;
    }

    modifier isValidPayload() {
        if (msg.data.length != 4 && msg.data.length != 36)
            revert();
        _;
    }
    
    function pinnsDutchAuction(uint EtherPriceFactor)
        public
    {
        if (EtherPriceFactor == 0)
            // price Argument is null.
            revert();
        owner = msg.sender;
        stage = Stages.AuctionDeployed;
        priceFactor = EtherPriceFactor;
       
    }
    
     /// @dev Setup function sets external contracts' addresses.
    function start_ICO(address toknn_) external isOwner atStage(Stages.AuctionDeployed)
    {
      if (pinnsToken.balanceOf(this) != MAX_TOKENS)
            revert();
            
        pinnsToken = PocketinnsToken(toknn_);
        stage = Stages.AuctionStarted;
        startItoTimestamp = block.timestamp;
        startPricePerToken = 2500;  //2500 cents is the starting price
        currentPerTokenPrice = startPricePerToken;
    }
    
    function ()
        public 
        payable 
        atStage(Stages.AuctionStarted)
        {
            if (msg.value < minimumInvestment || 
            ((msg.value * priceFactor *100)/currentPerTokenPrice) >= (MAX_TOKENS - totalTokensSold) ||
            totalReceived >= 149000 * 10**18  //checks 46 million dollar hardcap considering 1 eth=300dollar
            )
            revert();
            totalReceived += msg.value;       
            getCurrentPrice();
            setInvestment(msg.sender,msg.value);
        }
        
        function getCurrentPrice() public
        {
            totalTokensSold = ((totalReceived * priceFactor)/currentPerTokenPrice)*100;
            uint priceCalculationFactor = (block.timestamp - startItoTimestamp)/432;
            if(priceCalculationFactor <=1600)
            {
                currentPerTokenPrice = 2500 - priceCalculationFactor;
            }
            else if (priceCalculationFactor > 1600 && priceCalculationFactor <= 3100)
            {
                currentPerTokenPrice = 900 - ((priceCalculationFactor - 1600)/2);
            }
        }
        
        function setInvestment(address investor,uint amount) private 
        {
            if (currentPerTokenPrice == 2500 || currentPerTokenPrice == 2400)
            {
                statusDay1[investor] = true;
                day1Count++;   // will be used later for goodwill token distribution
                itoBids[investor] += amount;     // will be used for ITO token distribution
                ito(investor,amount,"day 1");
            }
            else if ((currentPerTokenPrice == 2300 || currentPerTokenPrice == 2200))
            {
                statusDay2[investor] = true;
                day2Count++;    // will be used later for goodwill token distribution
                itoBids[investor] += amount;     // will be used for ITO token distribution
                ito(investor,amount,"day 2");
            }
            else if((currentPerTokenPrice == 2100 || currentPerTokenPrice == 2000))
            {
                statusDay3[investor] = true;
                day3Count++;        // will be used later for goodwill token distribution
                itoBids[investor] += amount;     // will be used for ITO token distribution
                ito(investor,amount,"day 3");
            }
            else if((currentPerTokenPrice == 1900 || currentPerTokenPrice == 1800))
            {
                statusDay4[investor] = true;
                day4Count++;        // will be used later for goodwill token distribution
                itoBids[investor] += amount;     // will be used for ITO token distribution
                ito(investor,amount,"day 4");
            }
            else if(currentPerTokenPrice < 1800)
            {
                if((block.timestamp - startItoTimestamp) >=16 days)
                finalizeAuction();
                itoBids[investor] += amount;     // will be used for ITO token distribution
                noBonusDays[investor] = amount;
                ito(investor,amount,"5th day or after");
            }
        }
        
        function finalizeAuction() private
        {
            uint leftTokens = MAX_TOKENS - totalTokensSold;
            finalPrice = currentPerTokenPrice;
            pinnsToken.burnLeftItoTokens(leftTokens);
            stage = Stages.AuctionEnded;
        }
        
        //Investor can claim his tokens within two weeks of ICO end using this function
        //It can be also used to claim on behalf of any investor
        function claimTokensICO(address receiver) public
        atStage(Stages.AuctionEnded)
        {
            if (receiver == 0)
            receiver = msg.sender;
            if(itoBids[receiver] >0)
            {
            uint tokenCount = (itoBids[receiver] * priceFactor) / (finalPrice);
            itoBids[receiver] = 0;
            pinnsToken.transfer(receiver, tokenCount);
            }
        }
        
        
        //After 2 weeks owner will start godwill token distribution and will ensure that 
        //5 million goodwill tokens are sent to the contract
        function startGoodwillDistribution()
        public
        atStage(Stages.AuctionEnded)
        isOwner
        {
            if (pinnsToken.balanceOf(this) != goodwillTokensAmount)
            revert();
            
            day1Bonus = (3000000 * 10 **18)/day1Count;
            day2Bonus = (1000000 * 10 **18)/day2Count;
            day3Bonus = (750000 * 10 **18)/day3Count;
            day4Bonus = (250000 * 10 **18)/day4Count;
            stage = Stages.goodwillDistributionStarted;
        }
        
        function claimGoodwillTokens()
        atStage(Stages.goodwillDistributionStarted)
        public
        {
            if(statusDay1[msg.sender] == true)
            {
                statusDay1[msg.sender] = false;
                pinnsToken.transfer(msg.sender, day1Bonus);
            }
            if(statusDay2[msg.sender] == true)
            {
                statusDay2[msg.sender] = false;
                pinnsToken.transfer(msg.sender, day2Bonus);
            }
            if(statusDay3[msg.sender] == true)
            {
                statusDay3[msg.sender] = false;
                pinnsToken.transfer(msg.sender, day3Bonus);
            }
            if(statusDay4[msg.sender] == true)
            {
                statusDay4[msg.sender] = false;
                pinnsToken.transfer(msg.sender, day4Bonus);
            }
        }
    }