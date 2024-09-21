// SPDX-License-Identifier: Coinleft Public License for BitBay
pragma solidity ^0.8.0;

interface ERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);    
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint256 value) external returns (bool);
    function withdraw(uint256) external;
}

contract TwoPartyEscrow {
    struct Contract {
        address sender;
        address recipient;
        address token;
        address referred;
        uint amount;
        uint depositSender;
        uint depositRecipient;
        uint[2] quantity;
        uint rfee;
        uint[3] timelimit;
        uint[2] status;
        string message;
    }

    mapping(address => mapping(address => uint)) public userBalance;
    bytes32[] public markets;
    uint public marketslength;
    mapping(bytes32 => Contract) public contracts;
    mapping(bytes32 => bool) private initialized;
    mapping(bytes32 => uint) public userMarketID;
    mapping(address => bytes32[]) public openOffers;
    mapping(address => bytes32[]) public privateOffers;
    mapping(address => bytes32[]) public escrows;
    mapping(address => string[]) public userdata;
    mapping(bytes32 => string[]) public tagdata;
    mapping(bytes32 => uint[]) public tagposition;
    mapping(string => bytes32[]) public hashtag; //References for searching
    mapping(string => uint) public taglength;
    mapping(string => uint[]) public openslot;
    mapping(string => uint) private openslotlength;
    mapping(address => uint[3]) public completed;
    mapping(address => address) public referral;
    mapping(address => uint) public customFee; //Users may want to give special offers
    mapping(address => uint) public minimumFeeThreshold;
    mapping(bytes32 => mapping(address => string[])) public messages;
    mapping(address => mapping(address => bool)) public isCustodian; //Users can authorize a cosignee for selected contracts
    mapping(address => mapping(address => bool)) public lockCustodian;
    mapping(address => mapping(address => mapping(bytes32 => bool))) public isAuthorized;
    mapping(address => address[]) public custodianList;
    mapping(address => address[]) public custodianList2;
    mapping(address => uint) public cooldown;
    uint public affiliateFee;
    address public minter;
    string[] public publicdata;
    address public WETH;
    uint lock;

    constructor(address _WETH) {
        WETH = _WETH;
        minter = msg.sender;
        cooldown[address(0)] = 259200;
    }    
    receive() external payable {
        assert(msg.sender == WETH);
    }
    //If no affiliate is set, the fee is burned with up to .1% added to encourage using the system
    function changeAffiliate(address affiliate) public {
        require(completed[affiliate][2] >= 10); //Active users of the markets are the ones to promote it
        require(affiliate != address(0));
        referral[msg.sender] = affiliate;
    }
    function promoteAffiliate(address affiliate) public {
        require(msg.sender == minter);
        require(affiliate != address(0));
        if(completed[affiliate][2] < 10) {
            completed[affiliate][2] = 10;
        }
    }
    function changeMinter(address new_minter) public {
        require(msg.sender == minter);
        minter = new_minter;
    }
    function changeFee(uint newfee) public {
        require(msg.sender == minter);
        require(newfee >= 0 && newfee <= 100); //1% maximum
        affiliateFee = newfee;
    }
    function changeThreshold(address token, uint newfee) public {
        require(msg.sender == minter);
        minimumFeeThreshold[token] = newfee;
    }
    function changeCooldown(uint newtime) public {
        require(msg.sender == minter);
        cooldown[address(0)] = newtime;
    }
    function authorizeCustodian(address custodian, bool status, bool lockThis) public {
        if(isCustodian[msg.sender][custodian] == false && status) {
            custodianList[msg.sender].push(custodian);
            custodianList2[custodian].push(msg.sender);
        }
        if(!lockCustodian[msg.sender][custodian]) {
            isCustodian[msg.sender][custodian] = status;
        }
        if(status && lockThis) {
            lockCustodian[msg.sender][custodian] = true;
        }
    }
    function unlockCustodian(address user) public {
        if(lockCustodian[user][msg.sender]) {
            lockCustodian[user][msg.sender] = false;
        }
    }
    function authorizeContract(address custodian, bytes32 hash, bool status) public {
        isAuthorized[msg.sender][custodian][hash] = status;
    }
    function changeCustomFee(uint newfee) public {
        require(newfee >= affiliateFee && newfee <= 5000);
        customFee[msg.sender] = newfee;
    }
    function deposit(address token, uint amount) public {
        require(lock != 1);
        require(token != WETH);
        lock = 1;
        require(amount > 0);
        ERC20 erc20 = ERC20(token);
        require(erc20.balanceOf(msg.sender) >= amount);
        require(erc20.transferFrom(msg.sender, address(this), amount));
        userBalance[msg.sender][token] += amount;
        lock = 0;
    }
    function depositWETH() public payable {
        require(lock != 1);
        lock = 1;
        uint amount = msg.value;
        IWETH(WETH).deposit{value: amount}();
        require(amount > 0);
        userBalance[msg.sender][WETH] += amount;
        lock = 0;
    }
    function withdraw(address token, uint amount, address destination) public {
        require(lock != 1);
        lock = 1;
        require(amount > 0);
        require(userBalance[msg.sender][token] >= amount);
        if(token != WETH) {
            require(ERC20(token).transfer(destination, amount));
        } else {
            IWETH(WETH).withdraw(amount);
            safeTransferETH(destination, amount);
        }
        userBalance[msg.sender][token] -= amount;
        lock = 0;
    }
    //Note: Only use hash tags for chains that can handle the data cost or use short common word references
    function createContract(Contract memory data, address affiliate, string[] memory _hashtags) public returns (bytes32) {
        require(data.quantity[0] > 0 && data.quantity[1] > 0);
        require(data.sender == msg.sender || data.recipient == msg.sender);
        //0 instant acceptance or counters, 1 no instant with counters, 2 instant no counters, 3 no instant no counters, 4 private offer with recipient custom fee
        require(data.status[0] < 5);
        if(data.sender == msg.sender) {
            if(data.status[0] % 2 == 0) {
                require(userBalance[msg.sender][data.token] >= (data.amount + data.depositSender) * data.quantity[0]);
            } else {
                require(userBalance[msg.sender][data.token] >= (data.amount + data.depositSender));
            }
        } else {
            if(data.status[0] % 2 == 0) {
                require(userBalance[msg.sender][data.token] >= (data.depositRecipient) * data.quantity[0]);
            } else {
                require(userBalance[msg.sender][data.token] >= (data.depositRecipient));
            }
        }
        Contract memory newContract;
        bytes32 hash = keccak256(abi.encodePacked(data.sender, data.recipient, data.token, data.amount, data.depositSender, data.depositRecipient, data.timelimit, data.message, block.timestamp));
        require(initialized[hash] == false);
        newContract = Contract({
            sender: data.sender,
            recipient: data.recipient,
            token: data.token,
            referred: address(0),
            amount: data.amount,
            depositSender: data.depositSender,
            depositRecipient: data.depositRecipient,
            quantity: data.quantity,
            rfee: uint(0),
            timelimit: [data.timelimit[0],data.timelimit[1],block.timestamp],
            status: [data.status[0],uint(0)],
            message: data.message
        });
        if(marketslength == 0) {
            marketslength += 1;
            if(markets.length == 0) {
                markets.push(0x0);
            }
        }        
        if(data.sender != address(0) && data.recipient != address(0)) {
            if(data.sender == msg.sender) {
                if(affiliate != address(0)) {
                    newContract.referred = affiliate;
                    newContract.rfee = affiliateFee;
                    if(data.status[0] == 4 && customFee[data.recipient] > affiliateFee) {
                        newContract.rfee = customFee[data.recipient];
                    }
                }
                newContract.status = [uint(1),uint(0)];
            } else {
                newContract.status = [uint(0),uint(1)];
            }
            privateOffers[data.recipient].push(hash);
            privateOffers[data.sender].push(hash);
        } else {
            if(markets.length == marketslength) {
                markets.push(0x0);
            }
            markets[marketslength] = hash;
            privateOffers[address(0)].push(hash);
            userMarketID[hash] = marketslength;
            marketslength += 1;
            openOffers[msg.sender].push(hash);
        }
        if(_hashtags.length > 0) {
            require(_hashtags.length < 11);
            require(data.sender == address(0) || data.recipient == address(0));
            uint x = 0;
            string memory mytag;            
            while(x < _hashtags.length) {
                mytag = _hashtags[x];
                require(bytes(mytag).length <= 32);
                if(openslotlength[mytag] > 0) {
                    openslotlength[mytag] -= 1;
                    tagposition[hash].push(openslot[mytag][openslotlength[mytag]]);
                    hashtag[mytag][openslot[mytag][openslotlength[mytag]]] = hash;
                } else {
                    tagposition[hash].push(taglength[mytag]);
                    taglength[mytag] += 1;
                    hashtag[mytag].push(hash);
                }
                x += 1;
            }
            tagdata[hash] = _hashtags;
        }
        contracts[hash] = newContract;
        initialized[hash] = true;
        return hash;
    }
    function acceptOffer(bytes32 hash, uint quantity, uint offerlimit, address affiliate) public {
        if(affiliate != address(0) && completed[affiliate][2] >= 10) {
            if(referral[msg.sender] == address(0)) {
                referral[msg.sender] = affiliate;
            }
        } else {
            if(referral[msg.sender] != address(0)) {
                affiliate = referral[msg.sender];
            }
        }
        address sender = contracts[hash].sender;
        address recipient = contracts[hash].recipient;
        bool finalOffer = (sender != address(0) && recipient != address(0));
        require(quantity > 0);
        if(contracts[hash].timelimit[1] != 0) {
            require(block.timestamp < contracts[hash].timelimit[1]); //Offer has expired
        }
        if(finalOffer) {
            require(sender == msg.sender || recipient == msg.sender);
            require(quantity == contracts[hash].quantity[0]);
            if(contracts[hash].status[0] > 0 && msg.sender == sender) {
                require(false);
            }
            if(contracts[hash].status[1] > 0 && msg.sender == recipient) {
                require(false);
            }
            contracts[hash].status = [uint(1),uint(1)];
            if(contracts[hash].rfee == 0) {
                contracts[hash].rfee = affiliateFee;
            }
        }
        Contract memory newContract = contracts[hash];
        uint style = 0;
        if(!finalOffer) { //It's an open offer on the markets
            require(userMarketID[hash] != 0); //Offer is no longer available
            require(quantity <= contracts[hash].quantity[0] && quantity <= contracts[hash].quantity[1]);
            newContract.amount *= quantity;
            newContract.depositSender *= quantity;
            newContract.depositRecipient *= quantity;
            style = newContract.status[0] % 2;
            newContract.referred = affiliate;
            if(newContract.rfee == 0) {
                newContract.rfee = affiliateFee;
                if(sender == address(0)) {
                    if(customFee[recipient] > affiliateFee) {
                        newContract.rfee = customFee[recipient];
                    }
                }
            }
            if(style == 0) {
                contracts[hash].quantity[0] -= quantity;
                if(contracts[hash].quantity[0] == 0) {
                    if(tagdata[hash].length > 0) {
                        removeTags(hash);
                    }
                    uint marketId = userMarketID[hash];
                    require(markets[marketId] == hash);
                    marketslength -= 1;
                    userMarketID[markets[marketslength]] = marketId;
                    userMarketID[markets[marketId]] = 0;
                    markets[marketId] = markets[marketslength];
                    markets[marketslength] = 0;
                }
                newContract.status = [uint(1),uint(1)];
                if(sender == address(0)) {
                    sender = msg.sender;
                } else {
                    recipient = msg.sender;
                }
            } else {                
                if(sender == address(0)) {
                    newContract.status = [uint(1),uint(0)];
                    sender = msg.sender;
                } else {
                    newContract.status = [uint(0),uint(1)];
                    recipient = msg.sender;
                }
            }
            require(sender != recipient);
        }
        newContract.quantity[0] = quantity;
        newContract.sender = sender;
        newContract.recipient = recipient;
        if(style == 0) {
            newContract.timelimit[0] += block.timestamp;
            require(userBalance[recipient][newContract.token] >= (newContract.depositRecipient)); //Insufficient recipient balance
            userBalance[recipient][newContract.token] -= (newContract.depositRecipient);
            require(userBalance[sender][newContract.token] >= (newContract.amount + newContract.depositSender)); //Insufficient sender balance
            userBalance[sender][newContract.token] -= (newContract.amount + newContract.depositSender);
            bytes32 acceptedhash = keccak256(abi.encodePacked(sender, recipient, newContract.token, newContract.amount, newContract.depositSender, newContract.depositRecipient, newContract.timelimit[0], newContract.message));
            require(initialized[acceptedhash] == false);
            initialized[acceptedhash] = true;
            newContract.timelimit[1] = 0;
            newContract.timelimit[2] = 0;
            contracts[acceptedhash] = newContract;
            escrows[sender].push(acceptedhash);
            escrows[recipient].push(acceptedhash);
        } else {
            bytes32 counterhash = keccak256(abi.encodePacked(sender, recipient, newContract.token, newContract.amount, newContract.depositSender, newContract.depositRecipient, newContract.timelimit[0], newContract.message, block.timestamp));
            require(initialized[counterhash] == false);
            initialized[counterhash] = true;
            newContract.timelimit[1] = offerlimit;
            newContract.timelimit[2] = 0;
            contracts[counterhash] = newContract;
            privateOffers[sender].push(counterhash);
            privateOffers[recipient].push(counterhash);
        }
    }
    function depositAndCreateContract(address dtoken, uint256 damount, Contract memory data, address affiliate, string[] memory _hashtags) public payable returns (bytes32) {
        if(dtoken == WETH) {
            depositWETH();
        } else {
            deposit(dtoken, damount);
        }
        bytes32 result;
        result = createContract(data, affiliate,_hashtags);
        return result;
    }
    function depositAndAcceptOffer(address dtoken, uint256 damount, bytes32 hash, uint quantity, uint offerlimit, address affiliate) public payable {
        if(dtoken == WETH) {
            depositWETH();
        } else {
            deposit(dtoken, damount);
        }
        acceptOffer(hash, quantity, offerlimit, affiliate);
    }
    function depositAndWithdrawal(address dtoken, uint256 damount, address token, uint amount, address destination) public payable {
        if(dtoken == WETH) {
            depositWETH();
        } else {
            deposit(dtoken, damount);
        }
        withdraw(token, amount, destination);
    }
    function compareStrings(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }
    function removeTags(bytes32 hash) internal {
        uint x = 0;
        uint hashpos = 0;
        string memory mytag;
        mytag = tagdata[hash][tagdata[hash].length - 1];
        if(compareStrings(mytag,"")) { 
            return;
        }
        while(x < tagdata[hash].length) {
            hashpos = tagposition[hash][x];
            mytag = tagdata[hash][x];
            hashtag[mytag][hashpos] = 0x0;
            if(openslotlength[mytag] == openslot[mytag].length) {
                openslot[mytag].push(0);
            }
            openslot[mytag][openslotlength[mytag]] = hashpos;
            openslotlength[mytag] += 1;
            x += 1;
        }
        tagdata[hash].push("");
    }
    function removeExpiredTags(bytes32 hash) public {
        require(contracts[hash].sender == address(0) || contracts[hash].recipient == address(0));
        if(block.timestamp < contracts[hash].timelimit[2] + 31556952) {
            require(contracts[hash].sender == msg.sender || contracts[hash].recipient == msg.sender);
        }
        removeTags(hash);
    }
    function isAuthorizedUser(address user, bytes32 hash) internal view {
        if(msg.sender != user) {
            require(isCustodian[user][msg.sender]);
            require(isAuthorized[user][msg.sender][hash] || isAuthorized[user][msg.sender][bytes32(0)] || isAuthorized[user][address(0)][bytes32(0)]);
        }
    }
    function requestExtension(bytes32 hash, address user, uint timelimit) public {
        isAuthorizedUser(user, hash);
        require(block.timestamp < contracts[hash].timelimit[0]); //Escrow has expired, the funds have been destroyed        
        require(contracts[hash].status[0] < 4 && contracts[hash].status[1] < 4); //The deal has already completed
        require(contracts[hash].status[0] > 0 && contracts[hash].status[1] > 0); //Can only extend in escrow
        require(timelimit > contracts[hash].timelimit[0]);
        require(contracts[hash].sender == user || contracts[hash].recipient == user);
        if(user == contracts[hash].sender) {
            contracts[hash].timelimit[1] = timelimit;
        } else {
            contracts[hash].timelimit[2] = timelimit;
        }
        if(contracts[hash].timelimit[1] == contracts[hash].timelimit[2]) {
            contracts[hash].timelimit[0] = timelimit;
        }
    }
    function cancelEscrow(bytes32 hash, address user) public {
        isAuthorizedUser(user, hash);
        require(block.timestamp < contracts[hash].timelimit[0]); //Escrow has expired, the funds have been destroyed
        require(contracts[hash].status[0] < 4 && contracts[hash].status[1] < 4); //The deal has already completed
        require(contracts[hash].status[0] > 0 && contracts[hash].status[1] > 0);
        address sender = contracts[hash].sender;
        address recipient = contracts[hash].recipient; 
        require(sender == user || recipient == user);
        if(user == sender) {
            require(contracts[hash].status[1] != 2);
            contracts[hash].status[1] += 1;
        } else {
            require(contracts[hash].status[1] != 3);
            contracts[hash].status[1] += 2;
        }
        if(contracts[hash].status[1] == 4) {
            userBalance[recipient][contracts[hash].token] += (contracts[hash].depositRecipient);
            userBalance[sender][contracts[hash].token] += (contracts[hash].amount + contracts[hash].depositSender);
        }
    }
    function completeEscrow(bytes32 hash, address user) public {
        isAuthorizedUser(user, hash);
        require(block.timestamp < contracts[hash].timelimit[0]); //Escrow has expired, the funds have been destroyed
        require(contracts[hash].status[0] < 4 && contracts[hash].status[1] < 4); //The deal has already completed
        require(contracts[hash].status[0] > 0 && contracts[hash].status[1] > 0);
        address sender = contracts[hash].sender;
        address recipient = contracts[hash].recipient; 
        require(sender == user || recipient == user);
        if(user == sender) {
            require(contracts[hash].status[0] != 2);
            contracts[hash].status[0] += 1;
        } else {
            require(contracts[hash].status[0] != 3);
            contracts[hash].status[0] += 2;
        }
        if(contracts[hash].status[0] == 4) {
            uint total = 0;
            uint afee = contracts[hash].rfee;
            if(afee != 0) {
                address theReferred = contracts[hash].referred;
                if(theReferred == address(0)) {
                    theReferred = referral[sender];
                }
                if(theReferred != address(0)) {
                    total = ((contracts[hash].amount) * afee) / 10000;
                    userBalance[theReferred][contracts[hash].token] += total;
                } else {
                    if(afee > 100) {
                        afee = 100;
                    }
                    if(afee < 90) {
                        total = ((contracts[hash].amount) * (afee + 10)) / 10000;
                    } else {
                        total = ((contracts[hash].amount) * 100) / 10000;
                    }
                    userBalance[address(0)][contracts[hash].token] += total;
                }
            }
            userBalance[recipient][contracts[hash].token] += ((contracts[hash].amount - total) + contracts[hash].depositRecipient);
            userBalance[sender][contracts[hash].token] += (contracts[hash].depositSender);
            if(total >= minimumFeeThreshold[contracts[hash].token] && minimumFeeThreshold[contracts[hash].token] != 0) {
                if(cooldown[sender] < block.timestamp) {
                    cooldown[sender] = block.timestamp + cooldown[address(0)];
                    completed[sender][2] += 1;
                }
                if(cooldown[recipient] < block.timestamp) {
                    cooldown[recipient] = block.timestamp + cooldown[address(0)];
                    completed[recipient][2] += 1;
                }
            }
            completed[sender][0] += 1;
            completed[recipient][0] += 1;
        }
    }
    function expireEscrow(bytes32 hash, address user) public { //Useful for a reputation system
        isAuthorizedUser(user, hash);
        require(contracts[hash].sender == user || contracts[hash].recipient == user);
        require(contracts[hash].status[0] < 4 && contracts[hash].status[1] < 4);
        require(contracts[hash].status[0] > 0 && contracts[hash].status[1] > 0);
        require(block.timestamp > contracts[hash].timelimit[0]);
        completed[contracts[hash].sender][1] += 1;
        completed[contracts[hash].recipient][1] += 1;
        contracts[hash].status = [uint(5),uint(5)];
    }
    function sendMessage(bytes32 hash, address user, string memory message) public {
        isAuthorizedUser(user, hash);
        require(contracts[hash].sender == user || contracts[hash].recipient == user);
        require(contracts[hash].status[0] < 4 && contracts[hash].status[1] < 4);
        messages[hash][user].push(message);
    }
    function cancelPrivateOffer(bytes32 hash, address user) public {
        isAuthorizedUser(user, hash);
        require(contracts[hash].sender == user || contracts[hash].recipient == user);
        bool valid;
        if(contracts[hash].status[0] == 1 && contracts[hash].status[1] == 0) {
            valid = true;
        }
        if(contracts[hash].status[0] == 0 && contracts[hash].status[1] == 1) {
            valid = true;
        }
        require(valid);
        contracts[hash].status = [uint(4),uint(4)];
    }
    function removeMarketOffer(bytes32 hash, address user) public {
        uint marketId = userMarketID[hash];
        require(contracts[markets[marketId]].sender == address(0) || contracts[markets[marketId]].recipient == address(0));
        if(block.timestamp < contracts[markets[marketId]].timelimit[2] + 31556952) {
            isAuthorizedUser(user, hash);
            require(contracts[markets[marketId]].sender == user || contracts[markets[marketId]].recipient == user);
        }
        if(tagdata[hash].length > 0) {
            removeTags(hash);
        }
        marketslength -= 1;
        userMarketID[markets[marketslength]] = marketId;
        userMarketID[markets[marketId]] = 0;
        markets[marketId] = markets[marketslength];
        markets[marketslength] = 0;
    }
    function updateQuantity(bytes32 hash, uint[2] memory quantity) public {
        uint marketId = userMarketID[hash];
        require(quantity[0] > 0 && quantity[1] > 0);
        require(contracts[markets[marketId]].sender == address(0) || contracts[markets[marketId]].recipient == address(0));
        require(contracts[markets[marketId]].sender == msg.sender || contracts[markets[marketId]].recipient == msg.sender);
        contracts[markets[marketId]].quantity = quantity;
    }
    function changeReferralFee(bytes32 hash, uint newfee) public {
        require(contracts[hash].sender == address(0) && contracts[hash].recipient == msg.sender);
        require(newfee >= affiliateFee && newfee <= 5000);
        contracts[hash].rfee = newfee;
    }
    function getCompleted(address user) public view returns (uint[3] memory){
        return completed[user];
    }
    function getMarketOffer(uint marketId) public view returns (Contract memory) {
        return contracts[markets[marketId]];
    }
    function getContract(bytes32 hash) public view returns (Contract memory) {
        return contracts[hash];
    }
    function safeTransferETH(address to, uint value) internal {
        (bool success,) = to.call{value:value}(new bytes(0));
        require(success, 'Transfer failed');
    }
    function adddata(string memory data) public {
        publicdata.push(data);
    }
    function adduserdata(string memory data) public {
        userdata[msg.sender].push(data);
    }
    function getArrayLength(address user, uint arrayId) public view returns (uint) {
        if(arrayId == 0) {
            return openOffers[user].length;
        }
        if(arrayId == 1) {
            return privateOffers[user].length;
        }
        if(arrayId == 2) {
            return escrows[user].length;
        }
        if(arrayId == 3) {
            return userdata[user].length;
        } 
        if(arrayId == 4) {
            return custodianList[user].length;
        } 
        if(arrayId == 5) {
            return custodianList2[user].length;
        } else {
            return publicdata.length;
        }
    }
    function getMessageLength(bytes32 hash, address user) public view returns(uint) {
        return messages[hash][user].length;
    }
    function getTags(bytes32 hash) public view returns (string[] memory) {
        return tagdata[hash];
    }
}