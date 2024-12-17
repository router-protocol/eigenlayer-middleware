// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";

import {console2 as console} from "forge-std/Test.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IStakeRegistry} from "../../src/interfaces/IStakeRegistry.sol";
import {IRegistryCoordinator} from "../../src/RegistryCoordinator.sol";
import {OperatorStateRetriever} from "../../src/OperatorStateRetriever.sol";
import {IStrategyManager} from "eigenlayer-contracts/src/contracts/interfaces/IStrategyManager.sol";
import {IStrategy} from "eigenlayer-contracts/src/contracts/interfaces/IStrategy.sol";
import {IDelegationManager} from "eigenlayer-contracts/src/contracts/interfaces/IDelegationManager.sol";
import {ISignatureUtils} from "eigenlayer-contracts/src/contracts/interfaces/ISignatureUtils.sol";
import {IAVSDirectory} from "eigenlayer-contracts/src/contracts/interfaces/IAVSDirectory.sol";
import {IStrategyFactory} from "eigenlayer-contracts/src/contracts/interfaces/IStrategyFactory.sol";
import {PauserRegistry} from "eigenlayer-contracts/src/contracts/permissions/PauserRegistry.sol";
import {UpgradeableProxyLib} from "./UpgradeableProxyLib.sol";
import {CoreDeploymentLib} from "./CoreDeploymentLib.sol";
import {ERC20Mock} from "./MiddlewareDeploymentLib.sol";
import {BN254} from "../../src/libraries/BN254.sol";
import {BN256G2} from "./BN256G2.sol";


library OperatorLib {
    using BN254 for *;
    using Strings for uint256;

    struct Wallet {
        uint256 privateKey;
        address addr;
    }

    struct BLSWallet {
        uint256 privateKey;
        BN254.G2Point publicKeyG2;
        BN254.G1Point publicKeyG1;
    }

    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    struct Operator {
        Wallet key;
        BLSWallet signingKey;
    }

    function createBLSWallet(uint256 index) internal returns (BLSWallet memory) {
        uint256 privateKey = uint256(keccak256(abi.encodePacked(index + 1)));
        BN254.G1Point memory publicKeyG1 = BN254.generatorG1().scalar_mul(privateKey);
        BN254.G2Point memory publicKeyG2 = mul(privateKey);

        return BLSWallet({
            privateKey: privateKey,
            publicKeyG2: publicKeyG2,
            publicKeyG1: publicKeyG1
        });
    }

    function createWallet(uint256 index) internal pure returns (Wallet memory) {
        uint256 privateKey = uint256(keccak256(abi.encodePacked(index)));
        address addr = vm.addr(privateKey);

        return Wallet({
            privateKey: privateKey,
            addr: addr
        });
    }

    function createOperator(uint256 index) internal returns (Operator memory) {
        Wallet memory vmWallet = createWallet(index);
        BLSWallet memory blsWallet = createBLSWallet(index);

        return Operator({
            key: vmWallet,
            signingKey: blsWallet
        });
    }


    function mul(uint256 x) internal returns (BN254.G2Point memory g2Point) {
        string[] memory inputs = new string[](5);
        inputs[0] = "go";
        inputs[1] = "run";
        inputs[2] = "test/ffi/go/g2mul.go";
        inputs[3] = x.toString();

        inputs[4] = "1";
        bytes memory res = vm.ffi(inputs);
        g2Point.X[1] = abi.decode(res, (uint256));

        inputs[4] = "2";
        res = vm.ffi(inputs);
        g2Point.X[0] = abi.decode(res, (uint256));

        inputs[4] = "3";
        res = vm.ffi(inputs);
        g2Point.Y[1] = abi.decode(res, (uint256));

        inputs[4] = "4";
        res = vm.ffi(inputs);
        g2Point.Y[0] = abi.decode(res, (uint256));
    }

    function signWithOperatorKey(
        Operator memory operator,
        bytes32 digest
    ) internal pure returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(operator.key.privateKey, digest);
        return abi.encodePacked(r, s, v);
    }

    function signWithSigningKey(
        Operator memory operator,
        bytes32 digest
    ) internal pure returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(operator.signingKey.privateKey, digest);
        return abi.encodePacked(r, s, v);
    }

    function aggregate(
        BN254.G2Point memory pk1,
        BN254.G2Point memory pk2
    ) internal view returns (BN254.G2Point memory apk) {
        (apk.X[0], apk.X[1], apk.Y[0], apk.Y[1]) =
            BN256G2.ECTwistAdd(pk1.X[0], pk1.X[1], pk1.Y[0], pk1.Y[1], pk2.X[0], pk2.X[1], pk2.Y[0], pk2.Y[1]);
    }

    function mintMockTokens(Operator memory operator, address token, uint256 amount) internal {
        ERC20Mock(token).mint(operator.key.addr, amount);
    }

    function depositTokenIntoStrategy(
        Operator memory operator,
        address strategyManager,
        address strategy,
        address token,
        uint256 amount
    ) internal returns (uint256) {
        /// TODO :make sure strategy associated with token
        IStrategy strategy = IStrategy(strategy);
        require(address(strategy) != address(0), "Strategy was not found");
        IStrategyManager strategyManager = IStrategyManager(strategyManager);

        ERC20Mock(token).approve(address(strategyManager), amount);
        uint256 shares = strategyManager.depositIntoStrategy(strategy, IERC20(token), amount);

        return shares;
    }

    function registerAsOperator(
        Operator memory operator,
        address delegationManager
    ) internal {
        IDelegationManager delegationManagerInstance = IDelegationManager(delegationManager);

        delegationManagerInstance.registerAsOperator(
            operator.key.addr,
            0,
            ""
        );
    }

    function registerOperatorToAVS_M2(
        Operator memory operator,
        address avsDirectory,
        address serviceManager
    ) internal {
        IAVSDirectory avsDirectory = IAVSDirectory(avsDirectory);

        bytes32 salt = keccak256(abi.encodePacked(block.timestamp, operator.key.addr));
        uint256 expiry = block.timestamp + 1 hours;

        bytes32 operatorRegistrationDigestHash = avsDirectory
            .calculateOperatorAVSRegistrationDigestHash(
            operator.key.addr, serviceManager, salt, expiry
        );

        bytes memory signature = signWithOperatorKey(operator, operatorRegistrationDigestHash);

        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature = ISignatureUtils
            .SignatureWithSaltAndExpiry({signature: signature, salt: salt, expiry: expiry});

        /// TODO: call the registry
    }

    function deregisterOperatorFromAVS_M2() internal {
        /// TODO: call the registry

    }

    function registerOperatorFromAVS_OpSet() internal {
        /// TODO: call the ALM
    }

    function deregisterOperatorFromAVS_OpSet() internal {
        /// TODO: call the ALM
    }

    function createAndAddOperator(uint256 salt) internal returns (Operator memory) {
        Wallet memory operatorKey =
            createWallet(salt);
        /// TODO: BLS Key for signing key.  Integrate G2Operations.sol
        BLSWallet memory signingKey =
            createBLSWallet(salt);

        Operator memory newOperator = Operator({key: operatorKey, signingKey: signingKey});

        return newOperator;
    }
}