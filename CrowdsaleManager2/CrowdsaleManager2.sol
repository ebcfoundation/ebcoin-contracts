pragma solidity ^0.4.11;


library SafeMath {
  function mul(uint256 a, uint256 b) internal pure returns (uint256) 
  {
    uint256 c = a * b;
    assert(a == 0 || c / a == b);
    return c;
  }

  function div(uint256 a, uint256 b) internal pure returns (uint256) 
  {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  function sub(uint256 a, uint256 b) internal pure returns (uint256) 
  {
    assert(b <= a);
    return a - b;
  }

  function add(uint256 a, uint256 b) internal pure returns (uint256) 
  {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }

}


/**
 * @title Ownable
 */
contract Ownable 
{
  address public owner;

  event OwnerChanged(address indexed _oldOwner, address indexed _newOwner);
	
	function Ownable() public
  {
    owner = msg.sender;
  }

  modifier onlyOwner() 
  {
    require(msg.sender == owner);
    _;
  }

  function changeOwner(address _newOwner) onlyOwner public 
  {
    require(_newOwner != address(0));
    
    address oldOwner = owner;
    if (oldOwner != _newOwner)
    {
    	owner = _newOwner;
    	
    	OwnerChanged(oldOwner, _newOwner);
    }
  }

}


/**
 * @title Manageable
 */
contract Manageable is Ownable
{
	address public manager;
	
	event ManagerChanged(address indexed _oldManager, address _newManager);
	
	function Manageable() public
	{
		manager = msg.sender;
	}
	
	modifier onlyManager()
	{
		require(msg.sender == manager);
		_;
	}
	
	modifier onlyOwnerOrManager() 
	{
		require(msg.sender == owner || msg.sender == manager);
		_;
	}
	
	function changeManager(address _newManager) onlyOwner public 
	{
		require(_newManager != address(0));
		
		address oldManager = manager;
		if (oldManager != _newManager)
		{
			manager = _newManager;
			
			ManagerChanged(oldManager, _newManager);
		}
	}
	
}


/**
 * @title CrowdsaleToken
 */
contract CrowdsaleToken is Manageable
{
  using SafeMath for uint256;

  string public constant name     = "EBCoin";
  string public constant symbol   = "EBC";
  uint8  public constant decimals = 18;
  
  uint256 public totalSupply;
  mapping(address => uint256) balances;
  mapping (address => mapping (address => uint256)) internal allowed;
  mapping (address => uint256) public releaseTime;
  bool public released;

  event Transfer(address indexed _from, address indexed _to, uint256 _value);
  event Approval(address indexed _owner, address indexed _spender, uint256 _value);
  event Mint(address indexed _to, uint256 _value);
  event ReleaseTimeChanged(address indexed _owner, uint256 _oldReleaseTime, uint256 _newReleaseTime);
  event ReleasedChanged(bool _oldReleased, bool _newReleased);

  modifier canTransfer(address _from)
  {
  	if (releaseTime[_from] == 0)
  	{
  		require(released);
  	}
  	else
  	{
  		require(releaseTime[_from] <= now);
  	}
  	_;
  }

  function balanceOf(address _owner) public constant returns (uint256)
  {
    return balances[_owner];
  }

  function transfer(address _to, uint256 _value) canTransfer(msg.sender) public returns (bool) 
  {
    require(_to != address(0));
    require(_value <= balances[msg.sender]);

    balances[msg.sender] = balances[msg.sender].sub(_value);
    balances[_to] = balances[_to].add(_value);
    
    Transfer(msg.sender, _to, _value);
    
    return true;
  }

  function allowance(address _owner, address _spender) public constant returns (uint256) 
  {
    return allowed[_owner][_spender];
  }
  
  function transferFrom(address _from, address _to, uint256 _value) canTransfer(_from) public returns (bool) 
  {
    require(_to != address(0));
    require(_value <= balances[_from]);
    require(_value <= allowed[_from][msg.sender]);

    balances[_from] = balances[_from].sub(_value);
    balances[_to] = balances[_to].add(_value);
    allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
    
    Transfer(_from, _to, _value);
    
    return true;
  }
  
  function allocate(address _sale, address _investor, uint256 _value) onlyOwnerOrManager public 
  {
  	require(_sale != address(0));
  	Crowdsale sale = Crowdsale(_sale);
  	address pool = sale.pool();

    require(_investor != address(0));
    require(_value <= balances[pool]);
    require(_value <= allowed[pool][msg.sender]);

    balances[pool] = balances[pool].sub(_value);
    balances[_investor] = balances[_investor].add(_value);
    allowed[pool][_sale] = allowed[pool][_sale].sub(_value);
    
    Transfer(pool, _investor, _value);
  }
  
  function deallocate(address _sale, address _investor, uint256 _value) onlyOwnerOrManager public 
  {
  	require(_sale != address(0));
  	Crowdsale sale = Crowdsale(_sale);
  	address pool = sale.pool();
  	
    require(_investor != address(0));
  	require(_value <= balances[_investor]);
  	
  	balances[_investor] = balances[_investor].sub(_value);
  	balances[pool] = balances[pool].add(_value);
  	allowed[pool][_sale] = allowed[pool][_sale].add(_value);
  	
  	Transfer(_investor, pool, _value);
  }

 	function approve(address _spender, uint256 _value) public returns (bool) 
 	{
    allowed[msg.sender][_spender] = _value;
    
    Approval(msg.sender, _spender, _value);
    
    return true;
  }

  function mint(address _to, uint256 _value, uint256 _releaseTime) onlyOwnerOrManager public returns (bool) 
  {
  	require(_to != address(0));
  	
    totalSupply = totalSupply.add(_value);
    balances[_to] = balances[_to].add(_value);
    
    Mint(_to, _value);
    Transfer(0x0, _to, _value);
    
    setReleaseTime(_to, _releaseTime);
    
    return true;
  }

  function setReleaseTime(address _owner, uint256 _newReleaseTime) onlyOwnerOrManager public
  {
    require(_owner != address(0));
    
  	uint256 oldReleaseTime = releaseTime[_owner];
  	if (oldReleaseTime != _newReleaseTime)
  	{
  		releaseTime[_owner] = _newReleaseTime;
    
    	ReleaseTimeChanged(_owner, oldReleaseTime, _newReleaseTime);
    }
  }
  
  function setReleased(bool _newReleased) onlyOwnerOrManager public
  {
  	bool oldReleased = released;
  	if (oldReleased != _newReleased)
  	{
  		released = _newReleased;
  	
  		ReleasedChanged(oldReleased, _newReleased);
  	}
  }
  
}


/**
 * @title Crowdsale
 */
contract Crowdsale is Manageable
{
  using SafeMath for uint256;

  // The token being sold
  CrowdsaleToken public token;

  // start and end timestamps where investments are allowed (both inclusive)
  uint256 public startTime;
  uint256 public endTime  ;

  // how many token units a buyer gets per wei
  uint256 public rate;
  
  uint256 public constant decimals = 18;
  
  uint256 public tokenSaleWeiCap;		
  uint256 public tokenSaleWeiGoal;	
  uint256 public tokenSaleWeiMax;		
  uint256 public tokenSaleWeiMin;		
  
  address public pool; 
  address public wallet;

  bool public isFinalized = false;

  enum State { Created, Active, Closed }

  uint256 public totalAllocated;
  mapping (address => uint256) public allocated;
  
  uint256 public totalDeposited;
  mapping (address => uint256) public deposited;

  State public state;

  event Closed();
  event Finalized();
  event FundWithdrawed(uint256 ethAmount);
  event TokenPurchased(address indexed _purchaser, address indexed _investor, uint256 _value, uint256 _amount, bytes _data);
  event TokenReturned(address indexed _investor, uint256 _value);

  function Crowdsale() public
  {
  	state = State.Created;
  }
  
  function initCrowdsale(address _pool, address _token, uint256 _startTime, uint256 _endTime, uint256 _rate, uint256 _tokenSaleWeiCap, uint256 _tokenSaleWeiGoal, uint256 _tokenSaleWeiMax, uint256 _tokenSaleWeiMin, address _wallet) onlyOwnerOrManager public
  {
    require(state == State.Created);
  	require(_pool != address(0));
    require(_token != address(0));
    require(_startTime >= now);
    require(_endTime >= _startTime);
    require(_endTime >= now);
    require(_rate > 0);
    require(_tokenSaleWeiCap >= _tokenSaleWeiGoal);
    require(_wallet != 0x0);
    
    state = State.Active;
    
    pool             = _pool;
    token            = CrowdsaleToken(_token);
    startTime        = _startTime;
    endTime          = _endTime;
    rate             = _rate;
    tokenSaleWeiCap  = _tokenSaleWeiCap;
    tokenSaleWeiGoal = _tokenSaleWeiGoal;
    tokenSaleWeiMax  = _tokenSaleWeiMax;
    tokenSaleWeiMin  = _tokenSaleWeiMin;
    wallet           = _wallet;
  }

  function allocation(address _investor) public constant returns (uint256)
  {
  	return allocated[_investor];
  }

  function () payable public
  {
    buyTokens(msg.sender);
  }

  function buyTokens(address _investor) public payable 
  {
    require(_investor != 0x0);
    require(startTime <= now && now <= endTime);
    require(msg.value != 0);
    require(state == State.Active);
    
    // 투자전, 투자조건을 만족하는지 체크한다.
    require(totalAllocated <= tokenSaleWeiCap);		// 투자전, 전체 최대투자금 이하
    
    // 투자된 ETH을 구한다.
    uint256 ethWeiAmount = msg.value;
    
    // 할당된 EBC을 변환율을 적용하여 구한다.
    uint256 tokenWeiAmount = ethWeiAmount.mul(rate);
    
    // 동일 투자자의 누적 할당된 EBC을 구한다.
    uint256 personTokenWeiAmount = allocated[_investor].add(tokenWeiAmount);
    
    // 투자후, 투자조건을 만족하는지 체크한다.
    require(tokenSaleWeiMin <= personTokenWeiAmount);		// 투자후, 1인 최소투자금 이상
    require(personTokenWeiAmount <= tokenSaleWeiMax);		// 투자후, 1인 최대투자금 이하
    
    // 전체 투자자의 누적 할당된 EBC을 구하여 저장한다.
    totalAllocated = totalAllocated.add(tokenWeiAmount);

    // 전체 투자자의 누적 투자된 ETH을 구하여 저장한다.
    totalDeposited = totalDeposited.add(ethWeiAmount);
    
		// 동일 투자자의 누적 할당된 EBC을 저장한다.
    allocated[_investor] = personTokenWeiAmount;
    
    // 동일 투자자의 누적 투자된 ETH을 구하여 저장한다.
    deposited[_investor] = deposited[_investor].add(ethWeiAmount);
    
    // 토큰을 추가로 할당한다.
    token.allocate(this, _investor, tokenWeiAmount);
    
    TokenPurchased(msg.sender, _investor, ethWeiAmount, tokenWeiAmount, msg.data);
  }

  function deallocate(address _investor, uint256 _value) onlyOwnerOrManager public 
  {
  	require(_investor != address(0));
  	require(_value > 0);
    require(_value <= allocated[_investor]);

		// 전체 투자자의 누적 할당된 EBC을 구하여 저장한다.
		totalAllocated = totalAllocated.sub(_value);
		
		// 동일 투자자의 누적 할당된 EBC을 구하여 저장한다.
		allocated[_investor] = allocated[_investor].sub(_value);
		
		// 토큰을 추가로 회수한다.
		token.deallocate(this, _investor, _value);
		
		TokenReturned(_investor, _value);
  }

  function goalReached() public constant returns (bool)
  {
    return totalAllocated >= tokenSaleWeiGoal;
  }

  function hasEnded() public constant returns (bool) 
  {
    bool capReached = (totalAllocated >= tokenSaleWeiCap);
    return (now > endTime) || capReached;
  }

  function finalize() onlyOwnerOrManager public 
  {
    require(!isFinalized);
    require(hasEnded());

    if (goalReached()) 
    {
      close();
    } 
    
    Finalized();

    isFinalized = true;
  }

  function close() onlyOwnerOrManager public
  {
    require(state == State.Active);
    
    state = State.Closed;
    
    Closed();
  }

  function withdraw() onlyOwnerOrManager public
  {
  	require(state == State.Closed);
  	
  	uint256 depositedValue = this.balance;
  	if (depositedValue > 0)
  	{
  		wallet.transfer(depositedValue);
  	
  		FundWithdrawed(depositedValue);
  	}
  }
  
}

/* -------------------------------------------------------------------------------- */

/**
 * @title CrowdsaleManager2
 */
contract CrowdsaleManager2 is Manageable 
{
  using SafeMath for uint256;
  
  uint256 public constant decimals = 18;

  CrowdsaleToken public token;
  Crowdsale      public sale2;
  Crowdsale      public sale3;
  Crowdsale      public sale4;
  
  address public constant withdrawWallet2       = 0x6f4aF515ECcE22EA0D1AB82F8742E058Ac4d9cb3;					
  address public constant withdrawWallet3       = 0xd172E0DEe60Af67dA3019Ad539ce3190a191d71D;					
  address public constant withdrawWallet4       = 0x39164D5889767ac44503dD422a418bEACeA1699D;					

  function CrowdsaleManager2() public
  {
  }
  
  function assignToken(address _token) onlyOwnerOrManager public
  {
  	require(_token != address(0));
  	
  	// 토큰 지정
  	token = CrowdsaleToken(_token);
  }
  
  function changeTokenReleaseTime(address _owner, uint256 _releaseTime) onlyOwnerOrManager public
  {
  	token.setReleaseTime(_owner, _releaseTime);
  }
  
  function mintToken(address _to, uint256 _value, uint256 _releaseTime) onlyOwnerOrManager public
  {
    // 토큰 발행
    token.mint(_to, _value, _releaseTime);
  }
  
  function initSale(address _sale, uint256 _startTime, uint256 _endTime, uint256 _rate, uint256 _cap, uint256 _goal, uint256 _max, uint256 _min, address _wallet) onlyOwnerOrManager public
  {
    require(_sale != address(0));
    Crowdsale sale = Crowdsale(_sale);
    
    // 세일 초기화
    sale.initCrowdsale(this, token, _startTime, _endTime, _rate, _cap, _goal, _max, _min, _wallet);
    
    // 매니저2의 토큰을 세일에게 할당 승인
    token.approve(sale, _cap.add(_max));
  }
  
  function createSale2() onlyOwnerOrManager public
  {
  	// 프리세일2 생성
    sale2 = new Crowdsale();
  }
  
  function initSale2(uint256 _startTime, uint256 _endTime, uint256 _rate, uint256 _cap, uint256 _goal, uint256 _max, uint256 _min) onlyOwnerOrManager public
  {
  	initSale(sale2, _startTime, _endTime, _rate, _cap, _goal, _max, _min, withdrawWallet2);
  }
  
  function finalizeSale2() onlyOwnerOrManager public
  {
  	sale2.finalize();
  }
  
  function closeSale2() onlyOwnerOrManager public
  {
  	sale2.close();
  }
  
  function withdrawSale2() onlyOwnerOrManager public
  {
  	sale2.withdraw();
  }
  
  function createSale3() onlyOwnerOrManager public
  {
  	// 본세일 생성
    sale3 = new Crowdsale();
  }
  
  function initSale3(uint256 _startTime, uint256 _endTime, uint256 _rate, uint256 _cap, uint256 _goal, uint256 _max, uint256 _min) onlyOwnerOrManager public
  {
  	initSale(sale3, _startTime, _endTime, _rate, _cap, _goal, _max, _min, withdrawWallet3);
  }
  
  function finalizeSale3() onlyOwnerOrManager public
  {
  	sale3.finalize();
  }
  
  function closeSale3() onlyOwnerOrManager public
  {
  	sale3.close();
  }
  
  function withdrawSale3() onlyOwnerOrManager public
  {
  	sale3.withdraw();
  }
  
  function createSale4() onlyOwnerOrManager public
  {
  	// 추가세일 생성
    sale4 = new Crowdsale();
  }
  
  function initSale4(uint256 _startTime, uint256 _endTime, uint256 _rate, uint256 _cap, uint256 _goal, uint256 _max, uint256 _min) onlyOwnerOrManager public
  {
  	initSale(sale4, _startTime, _endTime, _rate, _cap, _goal, _max, _min, withdrawWallet4);
  }
  
  function finalizeSale4() onlyOwnerOrManager public
  {
  	sale4.finalize();
  }
  
  function closeSale4() onlyOwnerOrManager public
  {
  	sale4.close();
  }
  
  function withdrawSale4() onlyOwnerOrManager public
  {
  	sale4.withdraw();
  }
  
  function changeSaleOwner(address _sale, address _newOwner) onlyOwnerOrManager public
  {
  	require(_sale != address(0));
  	Crowdsale sale = Crowdsale(_sale);
  	
  	sale.changeOwner(_newOwner);
  }
  
  function changeSaleManager(address _sale, address _newManager) onlyOwnerOrManager public
  {
  	require(_sale != address(0));
  	Crowdsale sale = Crowdsale(_sale);
  	
  	sale.changeManager(_newManager);
  }
  
  function deallocate(address _sale, address _investor) onlyOwnerOrManager public
  {
  	require(_sale != address(0));
  	Crowdsale sale = Crowdsale(_sale);
  	
  	uint256 allocatedValue = sale.allocation(_investor);
  	
  	sale.deallocate(_investor, allocatedValue);
  }
  
  function promotionAllocate(address _investor, uint256 _value) onlyOwnerOrManager public
  {
  	token.transfer(_investor, _value);
  }
  
}
