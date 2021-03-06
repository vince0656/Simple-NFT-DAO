// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract SimpleNftDAO {

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
        uint256 totalSupply; // total NFT supply at time of proposal (for non-fixed supply NFTs)
        uint256 rejections; // Number of NFT members that have rejected the proposal
        uint256 rejectionDeadline; // Block number after which rejections cannot be submitted
    }

    TxProposal[] public txProposals;

    /// @notice token ID -> proposal ID -> rejected proposal
    mapping(uint256 => mapping(uint256 => bool)) public tokenRejectedProposal;

    ERC721Enumerable public nft;

    constructor(ERC721Enumerable _nft) { nft = _nft; }

    function propose(uint256 _tokenId, address _to, bytes calldata _data, uint256 _value) external {
        require(nft.ownerOf(_tokenId) == msg.sender, "Only owner");
        txProposals.push(TxProposal({
                executed: false,
                to: _to,
                data: _data,
                value: _value,
                proposer: _tokenId,
                totalSupply: nft.totalSupply(),
                rejections: 0,
                rejectionDeadline: block.number + REJECTION_PERIOD_LENGTH
            }));
        emit ProposalSubmitted(txProposals.length - 1);
    }

    function reject(uint256 _proposalId, uint256 _tokenId) external {
        require(nft.ownerOf(_tokenId) == msg.sender, "Only owner");
        require(_proposalId < txProposals.length, "Invalid ID");
        require(!tokenRejectedProposal[_tokenId][_proposalId], "Already rejected");

        TxProposal storage daoTx = txProposals[_proposalId];
        require(block.number < daoTx.rejectionDeadline, "Past deadline");
        require(daoTx.rejections + 1 <= daoTx.totalSupply, "Max rejections reached");

        tokenRejectedProposal[_tokenId][_proposalId] = true;
        daoTx.rejections += 1;

        emit ProposalRejected(_proposalId, _tokenId);
    }

    function execute(uint256 _proposalId, uint256 _tokenId) external payable {
        TxProposal storage daoTx = txProposals[_proposalId];
        require(nft.ownerOf(_tokenId) == msg.sender, "Only owner");
        require(_proposalId < txProposals.length, "Invalid ID");
        require(block.number > daoTx.rejectionDeadline, "Not passed the rejection period");
        require(daoTx.rejections < (daoTx.totalSupply / 2), "Too many rejections");
        require(!txProposals[_proposalId].executed, "Already executed");

        txProposals[_proposalId].executed = true;
        (bool success,) = daoTx.to.call{value: daoTx.value}(daoTx.data);
        require(success, "TX execution failed");

        emit ProposalExecuted(_proposalId);
    }
}
