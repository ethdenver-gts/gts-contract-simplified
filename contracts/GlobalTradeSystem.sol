pragma solidity ^0.5.0;

contract GlobalTradeSystem {

    // ------------------------------------------------------------------------------------------ //
    // STRUCTS / ENUMS
    // ------------------------------------------------------------------------------------------ //

    // Potential states of a TradeOffer
    enum TradeOfferState {
        PENDING,     // offer is valid and awaits confirmation or rejection
        CANCELLED, // offer was cancelled by the sender
        ACCEPTED,    // offer was accepted and assets were successfully
        DECLINED      // offer was declined by recipient
    }

    // Defines a single asset metadata
    struct AssetMetadata {
        address emitter; // address of the trusted third party who emitted the asset
        bytes data;            // defines asset's metadata. Format [int, json, keccak256]
    }
    
    // Defines that asset with certain metadata is owner by someone
    struct Asset {
        address owner;
        AssetMetadata metadata;
    }


    // Defines a single trade offer
    struct TradeOffer {
        address sender;                // sender's address 
        address recipient;         // offer recipient address (0x0 if public)
        uint[] my_assets;
        uint[] their_assets;
        TradeOfferState state; // offer state
    }

    // ------------------------------------------------------------------------------------------ //
    // EVENTS
    // ------------------------------------------------------------------------------------------ //

    // Event which fires when a new asset is emitted    
    event AssetAssign (
        uint id,                 // asset id stored in global mapping
        address owner,        // address of user whom an asset has been assigned
        address emitter, // address which emitted the asset
        bytes data             // data associated with the asset
    );

    // Event which fires when an asset is burned
    event AssetBurn (
        uint id // id of burned asset
    );

    // Event which fires when an asset changes its owner
    event AssetMove (
        uint id,            // id of the moved asset
        address from, // previous owner of the asset
        address to        // new owner of the asset
    );

    // Event which fires when a trade offer has been sent
    event TradeOfferSend (
        uint id,                                    // id of the offer
        address indexed sender,     // address of the offer's sender
        address indexed receiver, // address of the offer's recipient
        uint[] my_assets,
        uint[] their_assets
    );
    
    // Event fires when a trade offer has been modified
    event TradeOfferModify (
        uint indexed id,            // id of modified offer 
        TradeOfferState state // new state of the offer
    );

    // ------------------------------------------------------------------------------------------ //
    // FIELDS
    // ------------------------------------------------------------------------------------------ //    

    mapping(uint => Asset) assets;            // stores all Assets
    mapping(uint => TradeOffer) offers; // stores all TradeOffers
    uint last_asset_id;                                 // stores last asset id
    uint last_offer_id;                                 // stores last offer id
    mapping(address => uint) assetCount;
    mapping(address => uint[]) receivedTradeOffers;
    mapping(address => uint[]) sentTradeOffers;

    // ------------------------------------------------------------------------------------------ //
    // INTERNAL FUNCTIONS
    // ------------------------------------------------------------------------------------------ //

    // Changes the owner of an Asset    
    function setAssetOwner(uint _id, address _new_owner) internal {
        assetCount[assets[_id].owner]--;
        assetCount[_new_owner]++;
        emit AssetMove(_id, assets[_id].owner, _new_owner);
        assets[_id].owner = _new_owner;
    }

    // ------------------------------------------------------------------------------------------ //
    // EXTERNAL VIEW FUNCTIONS
    // ------------------------------------------------------------------------------------------ //

    // Gets information about an Asset
    function getAsset(uint _id) external view returns(
        address owner,
        address emitter,
        bytes memory data
    ) {
        return (assets[_id].owner, assets[_id].metadata.emitter, assets[_id].metadata.data);
    }

    // Returns TradeOffer details by its id
    function getTradeOffer(uint _id) external view returns(
        address sender,
        address recipient,
        uint[] memory my_assets,
        uint[] memory their_assets,
        TradeOfferState state
    ) {
        return (
            offers[_id].sender,
            offers[_id].recipient,
            offers[_id].my_assets,
            offers[_id].their_assets,
            offers[_id].state
        );
    }

    // ------------------------------------------------------------------------------------------ //
    // EXTERNAL STATE-CHANGING FUNCTIONS
    // ------------------------------------------------------------------------------------------ //

    // Assigns a new asset to given address
    function assign(address _owner, bytes calldata _data) external {
        last_asset_id++;
        assetCount[_owner]++;
        assets[last_asset_id] = Asset(_owner, AssetMetadata(msg.sender, _data));
        emit AssetAssign(last_asset_id, _owner, msg.sender, _data);
    }


    // Burns an asset by its id
    function burn(uint _id) external {
        require(
            assets[_id].metadata.emitter == msg.sender,
            "In order to burn an asset, you need to be the one who emitted it."
        );

        assetCount[assets[_id].owner]--;
        delete assets[_id];
        emit AssetBurn(_id);

    }

    // Sends a TradeOffer to other user
    function sendTradeOffer(
        address _partner,
        uint[] calldata _my_assets,
        uint[] calldata _their_assets
    ) external returns(uint) {
        last_offer_id++;
        offers[last_offer_id] = TradeOffer(
            msg.sender,
            _partner,
            _my_assets,
            _their_assets,
            TradeOfferState.PENDING
        );
        emit TradeOfferSend(
            last_offer_id,
            msg.sender,
            _partner,
            _my_assets,
            _their_assets
        );

        receivedTradeOffers[_partner].push(last_offer_id);
        sentTradeOffers[msg.sender].push(last_offer_id);

        return last_offer_id;
    }

    // Cancels a sent TradeOffer
    function cancelTradeOffer(uint offer_id) external {
        require(offers[offer_id].sender == msg.sender, "This is not your offer.");
        require(offers[offer_id].state == TradeOfferState.PENDING, "This offer is not pending.");
        offers[offer_id].state = TradeOfferState.CANCELLED;
        emit TradeOfferModify(
            offer_id,
            TradeOfferState.CANCELLED
        );
    }

    // Accepts a TradeOffer with given id
    function acceptTradeOffer(uint _offer_id) external {
        require(
            offers[_offer_id].recipient == msg.sender,
            "You are not the recipient of given trade offer."
        );
        require(
            offers[_offer_id].state == TradeOfferState.PENDING,
            "This offer is not pending."
        );
        for (uint i = 0; i < offers[_offer_id].my_assets.length; i++) {
            require(
                assets[offers[_offer_id].my_assets[i]].owner == offers[_offer_id].sender,
                "Offer sender no longer owns mentioned assets."
            );
            setAssetOwner(offers[_offer_id].my_assets[i], msg.sender);
        }
        for (uint i = 0; i < offers[_offer_id].their_assets.length; i++) {
            require(
                assets[offers[_offer_id].their_assets[i]].owner == msg.sender,
                "You no longer own mentioned assets."
            );
            setAssetOwner(
                offers[_offer_id].their_assets[i],
                offers[_offer_id].sender
            );
        }
        offers[_offer_id].state = TradeOfferState.ACCEPTED;
        emit TradeOfferModify(_offer_id, TradeOfferState.ACCEPTED);
    }

    // Declines a TradeOffer with given id
    function declineTradeOffer(uint _offer_id) external {
        require(
            offers[_offer_id].recipient == msg.sender,
            "You are not the recipient of given trade offer."
        );
        require(
            offers[_offer_id].state == TradeOfferState.PENDING,
            "This offer is not pending."
        );
        offers[_offer_id].state = TradeOfferState.DECLINED;
        emit TradeOfferModify(_offer_id, TradeOfferState.DECLINED);
    }
    
    function getMyInventory() external view returns (uint[] memory) {
        uint[] memory asset_ids = new uint[](assetCount[msg.sender]);
        uint last = 0;
        for(uint i = 0; i <= last_asset_id; i++)
        {
            if(assets[i].owner == msg.sender)
            {
                asset_ids[last++] = i;
            }
        }
        return asset_ids;
    }

    function getMyReceivedTradeOffers() external view returns(uint[] memory) {
        return receivedTradeOffers[msg.sender];
    }

    function getMySentTradeOffers() external view returns(uint[] memory) {
        return sentTradeOffers[msg.sender];
    }
    
    function getUserInventory(address user) external view returns (uint[] memory) {
        uint[] memory asset_ids = new uint[](assetCount[user]);
        uint last = 0;
        for(uint i = 0; i <= last_asset_id; i++)
        {
            if(assets[i].owner == user)
            {
                asset_ids[last++] = i;
            }
        }
        return asset_ids;
    }

}