// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

pragma solidity ^0.8.0;


/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _setOwner(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _setOwner(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

library Roles {
    struct Role {
        mapping (address => bool) bearer;
    }

    /**
     * @dev Give an account access to this role.
     */
    function add(Role storage role, address account) internal {
        require(!has(role, account), "Roles: account already has role");
        role.bearer[account] = true;
    }

    /**
     * @dev Remove an account's access to this role.
     */
    function remove(Role storage role, address account) internal {
        require(has(role, account), "Roles: account does not have role");
        role.bearer[account] = false;
    }

    /**
     * @dev Check if an account has this role.
     * @return bool
     */
    function has(Role storage role, address account) internal view returns (bool) {
        require(account != address(0), "Roles: account is the zero address");
        return role.bearer[account];
    }
}


contract AdminControl is Ownable {

    using Roles for Roles.Role;

    Roles.Role private _controllerRoles;


    modifier onlyMinterController() {
      require (
        hasRole(msg.sender), 
        "AdminControl: sender must has minting role"
      );
      _;
    }

    modifier onlyMinter() {
      require (
        hasRole(msg.sender), 
        "AdminControl: sender must has minting role"
      );
      _;
    }

    constructor() {
      _grantRole(msg.sender);
    }

    function grantMinterRole (address account) public  onlyOwner {
      _grantRole(account);
    }

    function revokeMinterRole (address account) public  onlyOwner {
      _revokeRole(account);
    }

    function hasRole(address account) public view returns (bool) {
      return _controllerRoles.has(account);
    }
    
    function _grantRole (address account) internal {
      _controllerRoles.add(account);
    }

    function _revokeRole (address account) internal {
      _controllerRoles.remove(account);
    }

}

interface IERC20
{

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);


}

contract FaucetTokenController is AdminControl {

    uint256 public amount = 1000000000000000000;
	
    uint256 public waitTime = 60 minutes;
    
    mapping(address => uint256) public lastAccessTime;
        
    address public tokenAdress; // This is the token address

	constructor(address _tokenAdress)
	{
		tokenAdress = _tokenAdress; 
	}
	
	function setAmount(uint256 _amount) external onlyOwner {
        amount = _amount;
    }
	
	function setTokenAddress(address _tokenAdress) external onlyOwner {
        tokenAdress = _tokenAdress;
    }
	
	function setWaitTime(uint256 _waitTime) external onlyOwner {
        waitTime = _waitTime;
    }

	function getBalance() external view returns (uint256){
        uint256 _amount = IERC20(tokenAdress).balanceOf(address(this));
        return _amount;
    }
	
	function approve(uint256 _amount) external returns(bool)
	{
        return IERC20(tokenAdress).approve(address(this), _amount);
    }
        
    function allowance() external view returns (uint256)
	{
         return IERC20(tokenAdress).allowance(msg.sender, address(this));
    }
        
    function request(address to) external {
	
        require(to!= address(0), "To address is null");
		
		require(allowed(to), "Wait to request again");
		
		require(IERC20(tokenAdress).balanceOf(address(this)) >= amount, "Insufficient or Token value sent is not correct");
		
		IERC20(tokenAdress).transfer(to, amount);
		
        lastAccessTime[to] = block.timestamp + waitTime;
    }
	
    function deposit(uint256 amountFund) external payable returns (uint256)
	{
		require(msg.value >= amountFund, "Insufficient or Token value sent is not correct");
		
		uint256 _allowance = IERC20(tokenAdress).allowance(msg.sender, address(this));
		
		require(_allowance >= amountFund, "Check the token allowance");
		
        IERC20(tokenAdress).transferFrom(msg.sender, address(this), amountFund);
		
		return amountFund;
    }

    function allowed(address _address) public view returns (bool) 
	{
        if(lastAccessTime[_address] == 0) {
            return true;
        } else if(block.timestamp >= lastAccessTime[_address]) {
            return true;
        }
        return false;
    }
}