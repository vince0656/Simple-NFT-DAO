// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MolochGodOfNFTs is ERC721("GodOfNFTs", "mNFT") {

    uint256 public constant BLOCKS_PER_DAY = 6600; // rough based on 13s a block
    uint256 public constant REJECTION_PERIOD_LENGTH = BLOCKS_PER_DAY * 14; // 14 days to reject any proposal

    event ProposalSubmitted(uint256 proposalId);
    event ProposalRejected(uint256 proposalId, uint256 tokenId);
    event ProposalExecuted(uint256 proposalId);

    struct TxProposal {
        bool executed; // Whether the tx has been executed or not
        address to; // Target address or zero address for a contract deployment
        bytes data; // Call data that will be attached to the TX
        uint256 value; // Value that will be attached to the TX
        uint256 proposer; // NFT token ID that raised the proposal
        uint256 rejections; // Number of NFT members that have rejected the proposal
        uint256 rejectionDeadline; // Block number after which rejections cannot be submitted
    }

    TxProposal[] public txProposals;

    /// @notice token ID -> proposal ID -> rejected proposal
    mapping(uint256 => mapping(uint256 => bool)) public tokenRejectedProposal;

    mapping(uint256 => uint256) public tokenIdToAmountSacrificed;

    mapping(uint256 => uint256) public tokenIdToLastProposal;

    uint256 public totalSupply;

    uint256 public totalSacrificed;

    uint256 public immutable SACRIFICE_REQUIRED;

    constructor(uint256 _requiredSacrifice) { SACRIFICE_REQUIRED = _requiredSacrifice; }

    function join() external payable {
        require(msg.value % 1 gwei == 0, "Sacrifice must be multiple of 1 GWEI");
        require(totalSacrificed + msg.value <= SACRIFICE_REQUIRED, "Exceeded required sacrifice");
        totalSacrificed += msg.value;

        totalSupply += 1;
        tokenIdToAmountSacrificed[totalSupply] = msg.value;
        _mint(msg.sender, totalSupply);
    }

    function propose(uint256 _tokenId, address _to, bytes calldata _data, uint256 _value) external {
        require(ownerOf(_tokenId) == msg.sender, "Only owner");
        require(block.number > txProposals[tokenIdToLastProposal[_tokenId]].rejectionDeadline / 2, "Not 7 days since last proposal");
        txProposals.push(TxProposal({
                executed: false,
                to: _to,
                data: _data,
                value: _value,
                proposer: _tokenId,
                rejections: 0,
                rejectionDeadline: block.number + REJECTION_PERIOD_LENGTH
            }));
        uint256 proposalId = txProposals.length - 1;
        tokenIdToLastProposal[_tokenId] = proposalId;
        emit ProposalSubmitted(proposalId);
    }

    function reject(uint256 _proposalId, uint256 _tokenId) external {
        require(_proposalId < txProposals.length, "Invalid ID");
        require(ownerOf(_tokenId) == msg.sender, "Only owner");
        require(!tokenRejectedProposal[_tokenId][_proposalId], "Already rejected");

        TxProposal storage daoTx = txProposals[_proposalId];
        require(block.number < daoTx.rejectionDeadline, "Past deadline");
        require(daoTx.rejections + 1 <= totalSupply, "Max rejections reached");

        tokenRejectedProposal[_tokenId][_proposalId] = true;
        daoTx.rejections += 1;

        emit ProposalRejected(_proposalId, _tokenId);
    }

    function execute(uint256 _proposalId, uint256 _tokenId) external {
        require(_proposalId < txProposals.length, "Invalid ID");
        require(ownerOf(_tokenId) == msg.sender, "Only owner");

        TxProposal storage daoTx = txProposals[_proposalId];
        require(block.number > daoTx.rejectionDeadline, "Not passed the rejection period");
        require(daoTx.rejections < (totalSupply / 2), "Too many rejections");
        require(!txProposals[_proposalId].executed, "Already executed or was cancelled");

        txProposals[_proposalId].executed = true;
        (bool success,) = daoTx.to.call{value: daoTx.value}(daoTx.data);
        require(success, "TX execution failed");

        emit ProposalExecuted(_proposalId);
    }

    function cancel(uint256 _proposalId, uint256 _tokenId) external {
        require(_proposalId < txProposals.length, "Invalid ID");
        require(ownerOf(_tokenId) == msg.sender, "Only owner");
        require(
            block.number > (txProposals[_proposalId].rejectionDeadline + REJECTION_PERIOD_LENGTH),
            "Not passed the cancel period"
        );
        txProposals[_proposalId].executed = true;
    }
}
