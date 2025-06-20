// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Decentralized Autonomous Organization (DAO)
 * @dev A smart contract that implements a basic DAO with proposal creation, voting, and execution
 * @author DAO Team
 */
contract Project {
    // State variables
    address public owner;
    uint256 public proposalCount;
    uint256 public memberCount;
    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public constant MINIMUM_QUORUM = 50; // 50% of members must vote
    
    // Structs
    struct Proposal {
        uint256 id;
        string title;
        string description;
        address proposer;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 createdAt;
        uint256 deadline;
        bool executed;
        bool exists;
        mapping(address => bool) hasVoted;
    }
    
    struct Member {
        address memberAddress;
        uint256 joinedAt;
        uint256 votingPower;
        bool isActive;
    }
    
    // Mappings
    mapping(uint256 => Proposal) public proposals;
    mapping(address => Member) public members;
    mapping(address => bool) public isMember;
    
    // Events
    event MemberAdded(address indexed member, uint256 votingPower);
    event ProposalCreated(uint256 indexed proposalId, string title, address indexed proposer);
    event VoteCast(uint256 indexed proposalId, address indexed voter, bool support, uint256 votingPower);
    event ProposalExecuted(uint256 indexed proposalId, bool success);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier onlyMember() {
        require(isMember[msg.sender], "Only members can call this function");
        _;
    }
    
    modifier proposalExists(uint256 _proposalId) {
        require(proposals[_proposalId].exists, "Proposal does not exist");
        _;
    }
    
    modifier votingActive(uint256 _proposalId) {
        require(block.timestamp <= proposals[_proposalId].deadline, "Voting period has ended");
        _;
    }
    
    modifier votingEnded(uint256 _proposalId) {
        require(block.timestamp > proposals[_proposalId].deadline, "Voting period is still active");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        
        // Add owner as first member with full voting power
        members[msg.sender] = Member({
            memberAddress: msg.sender,
            joinedAt: block.timestamp,
            votingPower: 100,
            isActive: true
        });
        isMember[msg.sender] = true;
        memberCount = 1;
        
        emit MemberAdded(msg.sender, 100);
    }
    
    /**
     * @dev Core Function 1: Add new members to the DAO
     * @param _member Address of the new member
     * @param _votingPower Voting power assigned to the member (1-100)
     */
    function addMember(address _member, uint256 _votingPower) external onlyOwner {
        require(_member != address(0), "Invalid member address");
        require(!isMember[_member], "Address is already a member");
        require(_votingPower > 0 && _votingPower <= 100, "Voting power must be between 1 and 100");
        
        members[_member] = Member({
            memberAddress: _member,
            joinedAt: block.timestamp,
            votingPower: _votingPower,
            isActive: true
        });
        
        isMember[_member] = true;
        memberCount++;
        
        emit MemberAdded(_member, _votingPower);
    }
    
    /**
     * @dev Core Function 2: Create a new proposal for voting
     * @param _title Title of the proposal
     * @param _description Detailed description of the proposal
     */
    function createProposal(string memory _title, string memory _description) external onlyMember {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_description).length > 0, "Description cannot be empty");
        
        proposalCount++;
        uint256 proposalId = proposalCount;
        
        Proposal storage newProposal = proposals[proposalId];
        newProposal.id = proposalId;
        newProposal.title = _title;
        newProposal.description = _description;
        newProposal.proposer = msg.sender;
        newProposal.forVotes = 0;
        newProposal.againstVotes = 0;
        newProposal.createdAt = block.timestamp;
        newProposal.deadline = block.timestamp + VOTING_PERIOD;
        newProposal.executed = false;
        newProposal.exists = true;
        
        emit ProposalCreated(proposalId, _title, msg.sender);
    }
    
    /**
     * @dev Core Function 3: Vote on a proposal
     * @param _proposalId ID of the proposal to vote on
     * @param _support true for supporting, false for opposing
     */
    function vote(uint256 _proposalId, bool _support) external 
        onlyMember 
        proposalExists(_proposalId) 
        votingActive(_proposalId) 
    {
        Proposal storage proposal = proposals[_proposalId];
        require(!proposal.hasVoted[msg.sender], "Member has already voted on this proposal");
        
        uint256 voterPower = members[msg.sender].votingPower;
        proposal.hasVoted[msg.sender] = true;
        
        if (_support) {
            proposal.forVotes += voterPower;
        } else {
            proposal.againstVotes += voterPower;
        }
        
        emit VoteCast(_proposalId, msg.sender, _support, voterPower);
    }
    
    /**
     * @dev Execute a proposal after voting period ends
     * @param _proposalId ID of the proposal to execute
     */
    function executeProposal(uint256 _proposalId) external 
        proposalExists(_proposalId) 
        votingEnded(_proposalId) 
    {
        Proposal storage proposal = proposals[_proposalId];
        require(!proposal.executed, "Proposal has already been executed");
        
        uint256 totalVotes = proposal.forVotes + proposal.againstVotes;
        uint256 totalVotingPower = getTotalVotingPower();
        
        // Check if quorum is met (minimum 50% of total voting power must participate)
        bool quorumMet = (totalVotes * 100) >= (totalVotingPower * MINIMUM_QUORUM);
        
        // Check if proposal passed (more for votes than against votes)
        bool proposalPassed = proposal.forVotes > proposal.againstVotes;
        
        proposal.executed = true;
        bool success = quorumMet && proposalPassed;
        
        emit ProposalExecuted(_proposalId, success);
    }
    
    /**
     * @dev Get proposal details
     * @param _proposalId ID of the proposal
     */
    function getProposal(uint256 _proposalId) external view 
        proposalExists(_proposalId) 
        returns (
            uint256 id,
            string memory title,
            string memory description,
            address proposer,
            uint256 forVotes,
            uint256 againstVotes,
            uint256 createdAt,
            uint256 deadline,
            bool executed
        ) 
    {
        Proposal storage proposal = proposals[_proposalId];
        return (
            proposal.id,
            proposal.title,
            proposal.description,
            proposal.proposer,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.createdAt,
            proposal.deadline,
            proposal.executed
        );
    }
    
    /**
     * @dev Get member details
     * @param _member Address of the member
     */
    function getMember(address _member) external view returns (
        address memberAddress,
        uint256 joinedAt,
        uint256 votingPower,
        bool isActive
    ) {
        require(isMember[_member], "Address is not a member");
        Member storage member = members[_member];
        return (
            member.memberAddress,
            member.joinedAt,
            member.votingPower,
            member.isActive
        );
    }
    
    /**
     * @dev Check if an address has voted on a proposal
     * @param _proposalId ID of the proposal
     * @param _voter Address of the voter
     */
    function hasVoted(uint256 _proposalId, address _voter) external view 
        proposalExists(_proposalId) 
        returns (bool) 
    {
        return proposals[_proposalId].hasVoted[_voter];
    }
    
    /**
     * @dev Get total voting power of all active members
     */
    function getTotalVotingPower() public view returns (uint256) {
        // In a more complex implementation, this would iterate through all members
        // For simplicity, we'll return memberCount * average voting power
        return memberCount * 50; // Assuming average voting power of 50
    }
    
    /**
     * @dev Get current timestamp (useful for testing)
     */
    function getCurrentTime() external view returns (uint256) {
        return block.timestamp;
    }
}
