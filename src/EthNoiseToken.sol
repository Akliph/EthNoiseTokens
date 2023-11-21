pragma solidity ^0.8.13;

import "./ERC721.sol";

contract EthNoiseToken is ERC721{
    uint256 public count;
    uint256 public seed;

    // Mapping from address to unique integer identifiers
    mapping(address => uint256[]) public addressToTokenIds;

    // Mapping from int identifier to address
    mapping(uint256 => address) public tokenIdToAddress;

    // Mapping from uniqie integer identifier to bounds of the noise that the token represents
    mapping(uint256 => int256[]) public tokenIdToBound;

    // Approved token manager
    mapping(uint256 => address) public tokenIdToApproved;

    // Approved operators for a given address
    mapping(address => address[]) public addressToOperators;

    int[][] public registeredMappings;

    /// @notice Constructs a new contract
    /// @param _seed the seed for the noise in the contract
    constructor(uint256 _seed)
    {
        count = 1;
        seed = _seed;
    }

    /*
    // PRIVATE FUNCTIONS
    */

    /// @notice common code for all ERC721 endpoints involving transfers
    /// @param _from the current owner of the token
    /// @param _to the address to transfer the token to
    /// @param _tokenId the id of the token
    function _transfer(address _from, address _to, uint256 _tokenId) private
    {
        // The transfer must be from the owner, approved address,
        // OR an approved operator
        require(msg.sender == tokenIdToAddress[_tokenId] ||
                msg.sender == tokenIdToApproved[_tokenId] ||
                _isOperator(msg.sender, tokenIdToAddress[_tokenId]));

        // The token must exist
        require(tokenIdToAddress[_tokenId] != address(0));

        // _from must be the current owner
        require(_from == tokenIdToAddress[_tokenId]);
        
        // The address being sent to is not 0
        require(_to != address(0));

        // Get the token index
        uint tokenIndex = 0;
        for(uint i = 0; i < addressToTokenIds[_from].length; i++)
        {
            if(addressToTokenIds[_from][i] == _tokenId)
                tokenIndex = i;
        }

        // Remove token from _from
        delete addressToTokenIds[_from][tokenIndex];

        // Add token to _to
        addressToTokenIds[_to].push(_tokenId);

        // Set token address to address
        tokenIdToAddress[_tokenId] = _to;

        // Emit transfer
        emit Transfer(_from, _to, _tokenId);
    }
    
    /// @notice performs a linear search through an addresses assigned operators
    /// @param _owner the address who is being managed
    /// @param _operator the address too check for operator status
    /// @return bool true if _operator is an operator
    function _isOperator(address _owner, address _operator) private view returns(bool)
    {
        bool isOperator = false;
        for(uint i = 0; i < addressToOperators[_owner].length; i++)
        {
            if(addressToOperators[_owner][i] == _operator)
            {
                isOperator = true;
                break;
            }
        }

        return isOperator;
    }

    /// @notice absolute value conditional
    /// @return int the abval of an int
    function _abs(int x) private pure returns (int) 
    {
        return x >= 0 ? x : -x;
    }

    /// @notice checks the collision between two bounds defining tokens
    /// @return bool true if there is a collision
    function _checkCollision(int[] memory a, int[] memory b) private pure returns (bool)
    {
        // Check collision between the minimum coordinate
        if( (a[0] >= b[0] && a[0] <= b[2]) &&
            (a[1] >= b[1] && a[1] <= b[3]) ) return true;
        
        if( (a[2] >= b[0] && a[2] <= b[2]) &&
            (a[3] >= b[1] && a[3] <= b[3]) ) return true;

        return false;
    }

    /*
    // ERC721 Implemenations
    */
    function balanceOf(address _owner) external view returns (uint256)
    {
        require(_owner != address(0), "Cannot query for address 0");

        return addressToTokenIds[_owner].length;
    }

    function ownerOf(uint256 _tokenId) external view returns (address)
    {
        if(tokenIdToAddress[_tokenId] != address(0))
            return tokenIdToAddress[_tokenId];
        else
            revert("Cannot query for address 0");
    }

    function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes memory _data) external payable
    {
        _transfer(_from, _to, _tokenId);

        // If the _to address is a smart contract it must implement ERC721TokenReceiver or the transaction will be reverted
        // This is why the transaction is considered safe, because all contract addresses that do not implement this will return the wrong value and 
        // revert the changes as a resut
        if(bytes32(_to.code) != 0)
            require(ERC721TokenReceiver(_to).onERC721Received(msg.sender, _from, _tokenId, _data) == bytes4(keccak256("onERC721Received(address,address,uint256,bytes)")));
    }

    function safeTransferFrom(address _from, address _to, uint256 _tokenId) external payable
    {
        _transfer(_from, _to, _tokenId);
        if(bytes32(_to.code) != 0)
            require(ERC721TokenReceiver(_to).onERC721Received(msg.sender, _from, _tokenId, bytes("")) == bytes4(keccak256("onERC721Received(address,address,uint256,bytes)")));
    }

    function transferFrom(address _from, address _to, uint256 _tokenId) external payable
    {
        _transfer(_from, _to, _tokenId);
    }

    function approve(address _approved, uint256 _tokenId) external payable
    {
        require(msg.sender == tokenIdToAddress[_tokenId] || 
                _isOperator(msg.sender, tokenIdToAddress[_tokenId]));

        tokenIdToApproved[_tokenId] = _approved;
    }

    function setApprovalForAll(address _operator, bool _approved) external
    {
        if(_approved)
            addressToOperators[msg.sender].push(_operator);
        // If false search for and delete the operator
        else
        {
            for(uint i = 0; i < addressToOperators[msg.sender].length; i++)
                if(addressToOperators[msg.sender][i] == _operator)
                {
                    delete addressToOperators[msg.sender][i];
                }
        }

        emit ApprovalForAll(msg.sender, _operator, _approved);
    }

    function getApproved(uint256 _tokenId) external view returns (address)
    {
        // Require that token exists
        require(tokenIdToAddress[_tokenId] != address(0));

        return tokenIdToApproved[_tokenId];
    }

    function isApprovedForAll(address _owner, address _operator) external view returns (bool)
    {
        return _isOperator(_owner, _operator);
    }

    /*
    // Functions to turn noise into token
    */

    /// @notice contains the noise function used in the contract
    /// @param x the x coordinate of the noise value
    /// @param y the y coordinate of the noise value
    /// @return uint8 the color value 0-255 of the point at x, y in the noise map
    function getValueAtPoint(uint256 x, uint256 y) external view returns(uint8)
    {
        return uint8(((x*seed) - (y*seed) + (x+y) * (x*y)) % 255);
    }

    /// @notice allows a user to claim a region of the noise map with some eth which is then tokenized and transferable
    /// @param xMin the minimum x region of the rectangle
    /// @param yMin the minimum y region of the rectangle
    /// @param xMax the maximum x region of the rectangle
    /// @param yMax the maximum y region of the rectangle
    function claimReigon(int256 xMin, int256 yMin, int256 xMax, int256 yMax) external payable
    {
        int[] memory v = new int[](4);
        v[0] = xMin;
        v[1] = yMin;
        v[2] = xMax;
        v[3] = yMax;

        // Check for collision with already registered tokens
        for(uint i = 0; i < registeredMappings.length; i++)
        {
            if(_checkCollision(v, registeredMappings[i])) revert("Collision with preexisting token");
        }

        // If not collision calculate value based on area
        uint256 area = uint256(_abs(xMax - xMin) * _abs(yMax - yMin));

        // If msg.value > cost of noise then 
        require(msg.value / 10^9 >= area, "Insufficient funds!");

        tokenIdToBound[count] = v;
        tokenIdToAddress[count] = msg.sender;
        addressToTokenIds[msg.sender].push(count);
        registeredMappings.push(v);
        count++;
    }
}