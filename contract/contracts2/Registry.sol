// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./interface/Iregistry.sol";
import "./interface/Isettings.sol";
import "./interface/Ibridge.sol";
import "./interface/Icontroller.sol";



contract  Registry is Ownable {
    using ECDSA for bytes32;

    struct Transaction{
       uint256 chainId;
       address assetAddress;
       uint256 amount;
       address receiver;
       uint256 nounce;
       bool  isCompleted;
   }
   struct validation {
       uint256 validationCount;
       bool validated;
   }
   enum transactionType {send , burn , mint ,claim}

   mapping (address => uint256) public assetTotalTransactionCount;
   mapping (address => mapping( uint256 => uint256 )) public assetTransactionTypeCount;
   mapping(address => mapping( uint256 => uint256 )) public assetChainBalance;
   mapping(address => uint256) public getUserNonce; 
   mapping (bytes32 => bool)  public isSendTransaction;
   mapping (bytes32 => Transaction)  public sendTransactions;
   mapping (bytes32 => bool)  public isClaimTransaction;
   mapping (bytes32 => Transaction)  public claimTransactions;
   mapping(bytes32 => Transaction) public mintTransactions;
   mapping(bytes32 => bool) public isMintTransaction;
   mapping(bytes32 => Transaction) public burnTransactions;
   mapping(bytes32 => bool) public isburnTransaction;
   mapping(bytes32 => validation ) public transactionValidations;
   mapping(bytes32 => address[] ) public TransactionValidators;
   mapping(bytes32 => mapping(address => bool)) public hasValidatedTransaction;
   uint256 public totalTransactions;

   event TransactionValidated(bytes32 indexed transactionID);
   event SendTransactionCompleted(bytes32 indexed transactionID);
   event BurnTransactionCompleted(bytes32 indexed transactionID);
   event MintTransactionCompleted(bytes32 indexed transactionID);
   event ClaimTransactionCompleted(bytes32 indexed transactionID);

   constructor(){}
  

  function completeSendTransaction(bytes32 transactionID) external {
      require(isSendTransaction[transactionID] ,"invalid Transaction");
      emit SendTransactionCompleted(transactionID);
      sendTransactions[transactionID].isCompleted = true;
  }


  function completeBurnTransaction(bytes32 transactionID) external {
       require(isburnTransaction[transactionID] ,"invalid Transaction");
       emit BurnTransactionCompleted(transactionID);
       burnTransactions[transactionID].isCompleted = true ;
  }


  function completeMintTransaction(bytes32 transactionID) external {
       require(isMintTransaction[transactionID] ,"invalid Transaction");
       emit MintTransactionCompleted(transactionID);
       mintTransactions[transactionID].isCompleted = true;
  }


  function completeClaimTransaction(bytes32 transactionID) external {
      require(isClaimTransaction[transactionID] ,"invalid Transaction");
      emit ClaimTransactionCompleted(transactionID);
      assetChainBalance[claimTransactions[transactionID].assetAddress][claimTransactions[transactionID].chainId] -= claimTransactions[transactionID].amount;
       claimTransactions[transactionID].isCompleted = true;
  }


   


  function registerTransaction(
       bytes32 transactionID,
       uint256 chainId,
       address assetAddress,
       uint256 amount,
       address receiver,
       uint256 nounce,
       transactionType _transactionType
  ) 
        public 
        onlyOwner 
  {
      if (_transactionType  == transactionType.send) {
          sendTransactions[transactionID] = Transaction(chainId , assetAddress ,amount , receiver ,nounce, false);
          isSendTransaction[transactionID] = true;
          getUserNonce[receiver]++;
          assetChainBalance[assetAddress][chainId] += amount;
      } else if (_transactionType  == transactionType.burn) {
          burnTransactions[transactionID] = Transaction(chainId , assetAddress ,amount , receiver ,nounce, false);
          isburnTransaction[transactionID] = true;
          getUserNonce[receiver]++;
      }
      assetTotalTransactionCount[assetAddress]++;
      totalTransactions++;
  }
  
  
  function _registerTransaction(
       bytes32 transactionID,
       uint256 chainId,
       address assetAddress,
       uint256 amount,
       address receiver,
       uint256 nounce,
       transactionType _transactionType
  ) 
      internal
  {
      if (_transactionType  == transactionType.mint) {
          mintTransactions[transactionID] = Transaction(chainId , assetAddress ,amount , receiver ,nounce, false);
          isMintTransaction[transactionID] = true;
      } else if (_transactionType  == transactionType.claim) {
          claimTransactions[transactionID] = Transaction(chainId , assetAddress ,amount , receiver ,nounce, false);
          isClaimTransaction[transactionID] = true;
      }
  }
  
  
  function registerClaimTransaction(
      bytes32 claimID,
      uint256 chainFrom,
      address assetAddress,
      uint256 amount,
      address receiver,
      uint256 nounce
    ) 
      external 
    {
        require(IController(Ibridge(owner()).controller()).isOracle(msg.sender),"U_A");
        require(!isClaimTransaction[claimID], "registerred");
        require(Ibridge(owner()).isAssetSupportedChain(assetAddress ,chainFrom), "chain_err");
        bytes32 requiredClaimID = keccak256(abi.encodePacked(
            chainFrom,
            Ibridge(owner()).chainId(),
            assetAddress,
            amount,
            receiver,
            nounce
            ));

        require(claimID  == requiredClaimID , "claimid_err");
        _registerTransaction(claimID ,chainFrom , assetAddress, amount , receiver ,nounce, transactionType.claim );
   }


   function registerMintTransaction(
       bytes32 mintID,
       uint256 chainFrom,
       address assetAddress,
       uint256 amount,
       address receiver,
       uint256 nounce
    ) 
       external 
    {
        require(IController(Ibridge(owner()).controller()).isOracle(msg.sender),"U_A");
        require(!isMintTransaction[mintID], "registerred");
        Ibridge  bridge = Ibridge(owner());
        address wrappedAddress = bridge.wrappedForiegnPair(assetAddress ,chainFrom);
        require(wrappedAddress != address(0), "I_A");
        if(!bridge.isDirectSwap(assetAddress , chainFrom)){
            Ibridge.asset memory  foriegnAsset = bridge.foriegnAssets(wrappedAddress);
            require(foriegnAsset.isSet , "asset_err");
            require(bridge.foriegnAssetChainID(wrappedAddress) == chainFrom , "chain_err");
        }
        
        bytes32 requiredmintID = keccak256(abi.encodePacked(
            chainFrom,
            bridge.chainId(),
            assetAddress,
            amount,
            receiver,
            nounce
            ));
        require(mintID  == requiredmintID, "mint: error validation mint ID");
        _registerTransaction(mintID ,chainFrom , wrappedAddress, amount , receiver ,nounce, transactionType.mint);
   }



   function validateTransaction(bytes32 transactionId , bytes[] memory signatures ,bool mintable) external  {
       // Registry contract's owner() is Bridge Contract, bridge's controller
       // check if msg.sender is validator or not
       require(IController(Ibridge(owner()).controller()).isValidator(msg.sender) , "U_A");
       // validation is 0
       require(Isettings(Ibridge(owner()).settings()).minValidations() != 0 , "minvalidator_err");
       
       Transaction memory transaction;
       if (mintable) {
           require(isMintTransaction[transactionId] , "mintID_err"); 
           transaction =  mintTransactions[transactionId];
           if(!Ibridge(owner()).isDirectSwap(transaction.assetAddress , transaction.chainId)){
               (,uint256 max) =  Ibridge(owner()).assetLimits(transaction.assetAddress, false);
               require(transaction.amount <= max , "Amount_limit_Err");
           }
        } else {
            require(isClaimTransaction[transactionId] , "caimID_err"); 
            transaction =  claimTransactions[transactionId]; 
            (,uint256 max) =  Ibridge(owner()).assetLimits(transaction.assetAddress , true);
            require(transaction.amount <= max && transaction.amount <= assetChainBalance[transaction.assetAddress][transaction.chainId]   , "Amount_limit_Err");
        }
       require(!transaction.isCompleted, "completed");
       uint256 validSignatures;
       
       // this part of the code was removed to access if you can recreate it to verify the signatures for a transaction

       // the message that was signed by the validators is a hash of derived as shown bellow
        
        
        // keccak256(abi.encodePacked(
        //     "\x19Ethereum Signed Message:\n32",
        //     keccak256(abi.encodePacked(
        //         chainID,   // this is goten from Ibridge(owner()).chainId()
        //         interfacingChainId,
        //         assetAddress,
        //         amount,
        //         receiver,
        //         nounce
        //     ))))

    // to all you need to do here is verify each of this signatures to accertain if they are from a valid signer
        
        // -- start -- 
        uint256 chainId = Ibridge(owner()).chainId();
        for (uint256 i; i < signatures.length; i++)
        {
            bytes32 signedHash = keccak256(abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(abi.encodePacked(
                    chainId,   // this is goten from Ibridge(owner()).chainId()
                    transaction.chainId,
                    transaction.assetAddress,
                    transaction.amount,
                    transaction.receiver,
                    transaction.nounce
                ))));
            bytes memory sig = signatures[i];
            if(sig.length != 65)
                break;

            address signer = signedHash.recover(sig);
            if(IController(Ibridge(owner()).controller()).isValidator(signer)) {
                validSignatures++;
            }
        }
        // -- end -- 

       //
       require(validSignatures >= Isettings(Ibridge(owner()).settings()).minValidations() ,"insuficient_signers");
       transactionValidations[transactionId].validationCount = validSignatures; 
       transactionValidations[transactionId].validated  = true;
        emit TransactionValidated(transactionId);
       if (mintable) {
           Ibridge(owner()).mint(transactionId);
       } else {
           Ibridge(owner()).claim(transactionId);
       }
      
   }


   

    function transactionValidated(bytes32 transactionID) external  view returns (bool) {
      return transactionValidations[transactionID].validated;
  }

}

  
