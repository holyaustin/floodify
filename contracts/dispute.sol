// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ISP } from "@ethsign/sign-protocol-evm/src/interfaces/ISP.sol";
import { Attestation } from "@ethsign/sign-protocol-evm/src/models/Attestation.sol";
import { DataLocation } from "@ethsign/sign-protocol-evm/src/models/DataLocation.sol";
import "hardhat/console.sol";

/**
 * @title dispute
 * @author holyaustin
 * @notice A contract for managing court cases using the Sign Protocol.
 */
contract dispute is Ownable {
    ISP public spInstance;
    uint64 public schemaId;

    mapping(uint64 => ECaseData) public cases;
    mapping(address => uint64[]) public userCases;

    struct ECaseData {
        address plaintiff;
        address defendant;
        string caseDetails;
        bool isSettled;
        uint64 attestationId;
        uint256 filingFee;
        uint256 settlementFee;
        bytes verdict;
        bytes[] evidenceList;
    }

    error CaseAlreadySettled();
    error CaseNotFound();
    error NotAuthorized();
    error InsufficientFunds();

    event CaseOpened(uint64 caseId, address plaintiff, address defendant, string caseDetails);
    event CaseSettled(uint64 caseId, bytes verdict);
    event EvidenceSubmitted(uint64 caseId, address submitter, bytes evidence);
    event FeesPaid(uint64 caseId, address payer, uint256 amount);

    /**
     * @notice Initializes the contract and sets the contract owner.
     */
    constructor() Ownable(_msgSender()) {}

    /**
     * @notice Sets the Sign Protocol instance address.
     * @dev Only the contract owner can call this function.
     * @param instance The address of the Sign Protocol instance.
     */
    function setSPInstance(address instance) external onlyOwner {
        spInstance = ISP(instance);
    }

    /**
     * @notice Sets the schema ID for creating attestations.
     * @dev Only the contract owner can call this function.
     * @param schemaId_ The schema ID to be used for attestations.
     */
    function setSchemaID(uint64 schemaId_) external onlyOwner {
        schemaId = schemaId_;
    }

    /**
     * @notice Opens a new court case.
     * @dev The caller must send the required filing fee along with the transaction.
     * @param defendant The address of the defendant in the case.
     * @param caseDetails A string containing the details of the case.
     * @param filingFee The filing fee required to open the case.
     */
    function openCase(address defendant, string memory caseDetails, uint256 filingFee) external payable {
        console.log ("message value",msg.value);
        console.log("filingFee ",filingFee);

        require(msg.value >= filingFee, "Insufficient funds for filing fee");
console.log("_msgSender ",_msgSender());
console.log("defendent ",defendant);
        bytes32 caseIdBytes32 = keccak256(abi.encodePacked(_msgSender(), defendant, caseDetails));
        uint caseIdUint = uint(caseIdBytes32);
        uint64 caseId = uint64(caseIdUint);
        console.log("caseId ", caseId);
        require(cases[caseId].attestationId == 0, "Case already exists");

        bytes[] memory recipients = new bytes[](2);
        recipients[0] = abi.encode(_msgSender());
        recipients[1] = abi.encode(defendant);
console.log("After recipeints");

        Attestation memory a = Attestation({
            schemaId: schemaId,
            linkedAttestationId: 0,
            attestTimestamp: 0,
            revokeTimestamp: 0,
            attester: address(this),
            validUntil: 0,
            dataLocation: DataLocation.ONCHAIN,
            revoked: false,
            recipients: recipients,
            data: abi.encode(caseDetails)
        });
        console.log("After Attestation1");
        uint64 attestationId = spInstance.attest(a, "", "", "");

        console.log("After Attestation2");
        cases[caseId] = ECaseData({
            plaintiff: _msgSender(),
            defendant: defendant,
            caseDetails: caseDetails,
            isSettled: false,
            attestationId:attestationId,
            filingFee: filingFee,
            settlementFee: 0,
            verdict: bytes(""),
            evidenceList: new bytes[](0)
        });
console.log("After cases");

        userCases[_msgSender()].push(caseId);
        userCases[defendant].push(caseId);
        console.log("Close to emit");
        emit CaseOpened(caseId, _msgSender(), defendant, caseDetails);
        emit FeesPaid(caseId, _msgSender(), filingFee);
    }

    /**
     * @notice Settles a court case with a verdict.
     * @dev Only the contract owner can call this function. The caller must send the required settlement fee along with the transaction.
     * @param caseId The ID of the case to be settled.
     * @param verdict The verdict for the case.
     * @param settlementFee The settlement fee required to settle the case.
     */
    function settleCase(uint64 caseId, bytes memory verdict, uint256 settlementFee) external onlyOwner payable {
        ECaseData storage caseData = cases[caseId];
        require(caseData.attestationId != 0, "Case not found");
        require(!caseData.isSettled, "Case already settled");
        require(msg.value >= settlementFee, "Insufficient funds for settlement fee");

        // Instead of updating the existing attestation, we create a new one with the verdict data
        bytes[] memory recipients = new bytes[](2);
        recipients[0] = abi.encode(caseData.plaintiff);
        recipients[1] = abi.encode(caseData.defendant);

        Attestation memory newAttestation = Attestation({
            schemaId: schemaId,
            linkedAttestationId: caseData.attestationId,
            attestTimestamp: 0,
            revokeTimestamp: 0,
            attester: address(this),
            validUntil: 0,
            dataLocation: DataLocation.ONCHAIN,
            revoked: false,
            recipients: recipients,
            data: verdict
        });

        uint64 newAttestationId = spInstance.attest(newAttestation, "", "", "");
console.log("newAttestationId  is", newAttestationId );
        caseData.isSettled = true;
        caseData.settlementFee = settlementFee;
        caseData.verdict = verdict;

        emit CaseSettled(caseId, verdict);
        emit FeesPaid(caseId, _msgSender(), settlementFee);
    }

    /**
     * @notice Submits evidence for a court case.
     * @dev Only the plaintiff or defendant can submit evidence for a case.
     * @param caseId The ID of the case for which evidence is being submitted.
     * @param evidence The evidence data to be submitted.
     */
    function submitEvidence(uint64 caseId, bytes memory evidence) external {
        ECaseData storage caseData = cases[caseId];
        require(caseData.attestationId != 0, "Case not found");
        require(!caseData.isSettled, "Case already settled");
        require(_msgSender() == caseData.plaintiff || _msgSender() == caseData.defendant, "Not authorized");

        // Instead of updating the existing attestation, we store the evidence in the contract
        caseData.evidenceList.push(evidence);

        emit EvidenceSubmitted(caseId, _msgSender(), evidence);
    }
/**
     * @notice Retrieves the details of a court case.
     * @param caseId The ID of the case for which details are requested.
     * @return The `ECaseData` struct containing the case details.
     */
    function getCaseDetails(uint64 caseId) external view returns (ECaseData memory) {
        ECaseData storage caseData = cases[caseId];
        require(caseData.attestationId != 0, "Case not found");
        return caseData;
    }

    /**
     * @notice Retrieves the list of case IDs for a given user.
     * @param user The address of the user for which case IDs are requested.
     * @return An array of case IDs associated with the user.
     */
    function getUserCases(address user) external view returns (uint64[] memory) {
        return userCases[user];
    }

    /**
     * @notice Withdraws funds from the contract balance to a specified recipient.
     * @dev Only the contract owner can call this function.
     * @param recipient The address to which the funds will be transferred.
     * @param amount The amount of funds to be withdrawn.
     */
    function withdrawFunds(address payable recipient, uint256 amount) external onlyOwner {
        require(address(this).balance >= amount, "Insufficient contract balance");
        recipient.transfer(amount);
    }

    /**
     * @notice Fallback function to receive Ether sent to the contract.
     */
    receive() external payable {}
    fallback() external payable {}
}