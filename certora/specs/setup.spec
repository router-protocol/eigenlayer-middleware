using ServiceManagerMock as serviceManager;
using StakeRegistryHarness as stakeRegistry;
using BLSApkRegistryHarness as blsApkRegistry;
using IndexRegistryHarness as indexRegistry;
// using DelegationManager as delegation;
// using BN254;
use builtin rule sanity;

methods {
    function _.isValidSignature(bytes32 hash, bytes signature) external => NONDET; // isValidSignatureCVL(hash,signature) expect bytes4;
    function _.unpauser() external => unpauser expect address;
    function _.isPauser(address user) external => isPauserCVL(user) expect bool;
    
    // BN254 Library
    function BN254.pairing(BN254.G1Point memory, BN254.G2Point memory, BN254.G1Point memory, BN254.G2Point memory) internal returns (bool) => NONDET;
    function BN254.hashToG1(bytes32 x) internal returns (BN254.G1Point memory) => hashToG1Ghost(x);
    // function BN254.pairing(BN254.G1Point memory, BN254.G2Point memory, BN254.G1Point memory, BN254.G2Point memory) internal returns (bool) => NONDET;

    // external calls to ServiceManager
    function _.registerOperatorToAVS(address, ISignatureUtils.SignatureWithSaltAndExpiry) external => NONDET;
    function _.deregisterOperatorFromAVS(address) external => NONDET;

    // Registry contracts
    function StakeRegistryHarness.totalStakeHistory(uint8) external returns (IStakeRegistry.StakeUpdate[]) envfree;
    function StakeRegistry._weightOfOperatorForQuorum(uint8 quorumNumber, address operator) internal returns (uint96, bool) => weightOfOperatorGhost(quorumNumber, operator);

    function IndexRegistryHarness.operatorCountHistory(uint8) external returns (IIndexRegistry.QuorumUpdate[]) envfree;
    
    function BLSApkRegistryHarness.getApkHistory(uint8) external returns (IBLSApkRegistry.ApkUpdate[]) envfree;
    function BLSApkRegistryHarness.registerBLSPublicKey(address, IBLSApkRegistry.PubkeyRegistrationParams, BN254.G1Point) external returns (bytes32) => PER_CALLEE_CONSTANT;


    // RegistryCoordinator
    function getOperatorStatus(address operator) external returns (IRegistryCoordinator.OperatorStatus) envfree;
    function getOperatorId(address operator) external returns (bytes32) envfree;
    function RegistryCoordinator._verifyChurnApproverSignature(address, bytes32, IRegistryCoordinator.OperatorKickParam[] memory, ISignatureUtils.SignatureWithSaltAndExpiry memory) internal => NONDET;
    function RegistryCoordinator._validateChurn(uint8, uint96, address, uint96, IRegistryCoordinator.OperatorKickParam memory, IRegistryCoordinator.OperatorSetParam memory) internal => NONDET;

    // harnessed functions
    function bytesArrayContainsDuplicates(bytes bytesArray) external returns (bool) envfree;
    function bytesArrayIsSubsetOfBitmap(uint256 referenceBitmap, bytes arrayWhichShouldBeASubsetOfTheReference) external returns (bool) envfree;
    function quorumInBitmap(uint256 bitmap, uint8 numberToCheckForInclusion) external returns (bool) envfree;
    function hashToG1Harness(bytes32 x) external returns (BN254.G1Point memory) envfree;
}
ghost address unpauser;
ghost mapping(address => bool) pausers;
ghost mapping(uint8 => mapping(address => uint96)) operatorWeight;

function isPauserCVL(address user) returns bool {
    return pausers[user];
}

function hashToG1Ghost(bytes32 x) returns BN254.G1Point {
    return hashToG1Harness(x);
}

function weightOfOperatorGhost(uint8 quorumNumber, address operator) returns (uint96, bool) {
    bool val;
    return (operatorWeight[quorumNumber][operator], val);
}

// If my Operator status is REGISTERED ⇔ my quorum bitmap MUST BE nonzero
invariant registeredOperatorsHaveNonzeroBitmaps(env e, address operator)
    getOperatorStatus(operator) == IRegistryCoordinator.OperatorStatus.REGISTERED <=>
        getCurrentQuorumBitmap(e, getOperatorId(operator)) != 0;

invariant initializedQuorumHistories(uint8 quorumNumber)
    quorumNumber < currentContract.quorumCount <=> 
        stakeRegistry.totalStakeHistory(quorumNumber).length != 0 && 
        indexRegistry.operatorCountHistory(quorumNumber).length != 0 &&
        blsApkRegistry.getApkHistory(quorumNumber).length != 0;

/// @notice unique address <=> unique operatorId
invariant oneIdPerOperator(address operator1, address operator2)
    operator1 != operator2 && getOperatorId(operator1) != to_bytes32(0)
        => getOperatorId(operator1) != getOperatorId(operator2);

/// @notice one way implication as IndexRegistry.currentOperatorIndex does not get updated on operator deregistration
invariant operatorIndexWithinRange(env e, address operator, uint8 quorumNumber, uint256 blocknumber, uint256 index)
    getOperatorStatus(operator) == IRegistryCoordinator.OperatorStatus.REGISTERED && 
    quorumInBitmap(assert_uint256(getCurrentQuorumBitmap(e, getOperatorId(operator))), quorumNumber) =>
        indexRegistry.currentOperatorIndex(e, quorumNumber, getOperatorId(operator)) < indexRegistry.totalOperatorsForQuorum(e, quorumNumber)
    {
        preserved deregisterOperator(bytes quorumNumbers) with (env e2) {
            requireInvariant oneIdPerOperator(operator, e2.msg.sender);
        }
    }

// Operator cant go from registered to NEVER_REGISTERED. Can write some parametric rule
rule registeredOperatorCantBeNeverRegistered(address operator) {
    require(getOperatorStatus(operator) != IRegistryCoordinator.OperatorStatus.NEVER_REGISTERED);

    calldataarg arg;
    env e;
    method f;
    f(e, arg);

    assert(getOperatorStatus(operator) != IRegistryCoordinator.OperatorStatus.NEVER_REGISTERED);
}

// if operator is registered for quorum number then 
// operator has stake weight >= minStakeWeight(quorumNumber)
invariant operatorHasNonZeroStakeWeight(env e, address operator, uint8 quorumNumber)
    quorumInBitmap(assert_uint256(getCurrentQuorumBitmap(e, getOperatorId(operator))), quorumNumber) =>
        stakeRegistry.weightOfOperatorForQuorum(e, quorumNumber, operator) >= stakeRegistry.minimumStakeForQuorum(e, quorumNumber);