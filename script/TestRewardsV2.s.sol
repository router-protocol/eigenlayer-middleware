// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.12;

import {Script, stdJson} from "forge-std/Script.sol";

import {IRewardsCoordinator} from "lib/eigenlayer-contracts/src/contracts/interfaces/IRewardsCoordinator.sol";
import {IServiceManager} from "src/interfaces/IServiceManager.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IStrategy} from "lib/eigenlayer-contracts/src/contracts/interfaces/IStrategy.sol";

contract TestRewardsV2 is Script {
    IRewardsCoordinator rewardsCoordinator =
        IRewardsCoordinator(0xAcc1fb458a1317E886dB376Fc8141540537E68fE);
    IServiceManager eigenDAServiceManager =
        IServiceManager(0xD4A7E1Bd8015057293f0D0A557088c286942e84b);

    IERC20 WETH = IERC20(0x94373a4919B3240D86eA41593D5eBa789FEF3848);

    // operators
    address OPERATOR_STAKELY = 0x06Fb6C463cC68100355624B6006471A960704126;
    address OPERATOR_EIGENYIELDS = 0x5ACCC90436492F24E6aF278569691e2c942A676d;
    address OPERATOR_XYZ = 0x758E016468E5E90cDB42e743881C2e921d8e7bF8;
    address OPERATOR_GALAXY = 0x0a3e3d83C99B27cA7540720b54105C79Cd58dbdD;
    address OPERATOR_SINOPMM = 0xB25430A1Ba8F2033834Ba30AAB8279CB1Cb6c9a6;

    //strategies
    IStrategy STRATEGY_WETH =
        IStrategy(0x80528D6e9A2BAbFc766965E0E26d5aB08D9CFaF9);
    IStrategy STRATEGY_STETH =
        IStrategy(0x7D704507b76571a51d9caE8AdDAbBFd0ba0e63d3);

    function _setupStrategyAndMultiplier()
        internal
        view
        returns (IRewardsCoordinator.StrategyAndMultiplier[] memory)
    {
        IRewardsCoordinator.StrategyAndMultiplier[]
            memory defaultStrategyAndMultipliers = new IRewardsCoordinator.StrategyAndMultiplier[](
                2
            );

        defaultStrategyAndMultipliers[0] = IRewardsCoordinator
            .StrategyAndMultiplier({
                strategy: STRATEGY_STETH,
                multiplier: 1e18
            });

        defaultStrategyAndMultipliers[1] = IRewardsCoordinator
            .StrategyAndMultiplier({strategy: STRATEGY_WETH, multiplier: 2e18});

        return defaultStrategyAndMultipliers;
    }

    // Test Rewards v1 submission: 1. Operator-avs split left unset,  2. Operator-avs split activated before startTimestamp
    // forge script script/TestRewardsV2.s.sol:TestRewardsV2 --rpc-url '<HOLESKY_RPC_URL>' --sig 'tx_1()' --private-key '<0xDA29BB71669f46F2a779b4b62f03644A84eE3479_PRIV_KEY>' -vvvv --broadcast
    function tx_1() public {
        IRewardsCoordinator.StrategyAndMultiplier[]
            memory strategyAndMultipliers = _setupStrategyAndMultiplier();

        IRewardsCoordinator.RewardsSubmission[]
            memory rewardsSubmissions = new IRewardsCoordinator.RewardsSubmission[](
                1
            );
        rewardsSubmissions[0] = IRewardsCoordinator.RewardsSubmission({
            strategiesAndMultipliers: strategyAndMultipliers,
            token: WETH,
            amount: 1e18, // 1 WETH
            startTimestamp: uint32(1734220800), // 2024-12-15 00:00:00 UTC
            duration: uint32(86400) // 1 day
        });

        vm.broadcast();
        eigenDAServiceManager.createAVSRewardsSubmission(rewardsSubmissions);
    }

    // Test Rewards v1 submission: Operator-avs split activated after startTimestamp and before duration end
    // forge script script/TestRewardsV2.s.sol:TestRewardsV2 --rpc-url '<HOLESKY_RPC_URL>' --sig 'tx_2()' --private-key '<0xDA29BB71669f46F2a779b4b62f03644A84eE3479_PRIV_KEY>' -vvvv --broadcast
    function tx_2() public {
        IRewardsCoordinator.StrategyAndMultiplier[]
            memory strategyAndMultipliers = _setupStrategyAndMultiplier();

        IRewardsCoordinator.RewardsSubmission[]
            memory rewardsSubmissions = new IRewardsCoordinator.RewardsSubmission[](
                1
            );
        rewardsSubmissions[0] = IRewardsCoordinator.RewardsSubmission({
            strategiesAndMultipliers: strategyAndMultipliers,
            token: WETH,
            amount: 1.2e18, // 1.2 WETH
            startTimestamp: uint32(1733788800), // 2024-12-10 00:00:00 UTC
            duration: uint32(518400) // 6 days
        });

        vm.broadcast();
        eigenDAServiceManager.createAVSRewardsSubmission(rewardsSubmissions);
    }

    // Test PI v1 submission: 1. Operator-avs split left unset,  2. Operator-avs split activated before startTimestamp
    // forge script script/TestRewardsV2.s.sol:TestRewardsV2 --rpc-url '<HOLESKY_RPC_URL>' --sig 'tx_3()' --private-key '<0xDA29BB71669f46F2a779b4b62f03644A84eE3479_PRIV_KEY>' -vvvv --broadcast
    function tx_3() public {
        IRewardsCoordinator.StrategyAndMultiplier[]
            memory strategyAndMultipliers = _setupStrategyAndMultiplier();

        IRewardsCoordinator.RewardsSubmission[]
            memory rewardsSubmissions = new IRewardsCoordinator.RewardsSubmission[](
                1
            );
        rewardsSubmissions[0] = IRewardsCoordinator.RewardsSubmission({
            strategiesAndMultipliers: strategyAndMultipliers,
            token: WETH,
            amount: 1e18, // 1 WETH
            startTimestamp: uint32(1734220800), // 2024-12-15 00:00:00 UTC
            duration: uint32(86400) // 1 day
        });

        vm.broadcast();
        rewardsCoordinator.createRewardsForAllEarners(rewardsSubmissions);
    }

    // Test PI v1 submission: 1. Operator-avs split left unset,  2. Operator-avs split activated before startTimestamp
    // forge script script/TestRewardsV2.s.sol:TestRewardsV2 --rpc-url '<HOLESKY_RPC_URL>' --sig 'tx_4()' --private-key '<0xDA29BB71669f46F2a779b4b62f03644A84eE3479_PRIV_KEY>' -vvvv --broadcast
    function tx_4() public {
        IRewardsCoordinator.StrategyAndMultiplier[]
            memory strategyAndMultipliers = _setupStrategyAndMultiplier();

        IRewardsCoordinator.RewardsSubmission[]
            memory rewardsSubmissions = new IRewardsCoordinator.RewardsSubmission[](
                1
            );
        rewardsSubmissions[0] = IRewardsCoordinator.RewardsSubmission({
            strategiesAndMultipliers: strategyAndMultipliers,
            token: WETH,
            amount: 1.2e18, // 1.2 WETH
            startTimestamp: uint32(1733788800), // 2024-12-10 00:00:00 UTC
            duration: uint32(518400) // 6 days
        });

        vm.broadcast();
        rewardsCoordinator.createRewardsForAllEarners(rewardsSubmissions);
    }

    // Test Operator Directed Rewards Submission: 1. Operator-avs split left unset,  2. Operator-avs split activated before startTimestamp
    // forge script script/TestRewardsV2.s.sol:TestRewardsV2 --rpc-url '<HOLESKY_RPC_URL>' --sig 'tx_5()' --private-key '<0xDA29BB71669f46F2a779b4b62f03644A84eE3479_PRIV_KEY>' -vvvv --broadcast
    function tx_5() public {
        IRewardsCoordinator.StrategyAndMultiplier[]
            memory strategyAndMultipliers = _setupStrategyAndMultiplier();

        IRewardsCoordinator.OperatorReward[]
            memory operatorRewards = new IRewardsCoordinator.OperatorReward[](
                2
            );
        operatorRewards[0] = IRewardsCoordinator.OperatorReward({
            operator: OPERATOR_STAKELY,
            amount: 1e18 // 1 WETH
        });
        operatorRewards[1] = IRewardsCoordinator.OperatorReward({
            operator: OPERATOR_EIGENYIELDS,
            amount: 1e18 // 1 WETH
        });

        IRewardsCoordinator.OperatorDirectedRewardsSubmission[]
            memory rewardsSubmissions = new IRewardsCoordinator.OperatorDirectedRewardsSubmission[](
                1
            );
        rewardsSubmissions[0] = IRewardsCoordinator
            .OperatorDirectedRewardsSubmission({
                strategiesAndMultipliers: strategyAndMultipliers,
                token: WETH,
                operatorRewards: operatorRewards,
                startTimestamp: uint32(1734220800), // 2024-12-15 00:00:00 UTC
                duration: uint32(86400), // 1 day
                description: ""
            });

        vm.broadcast();
        eigenDAServiceManager.createOperatorDirectedAVSRewardsSubmission(
            rewardsSubmissions
        );
    }

    // Test Operator Directed Rewards Submission: Operator-avs split activated after startTimestamp and before duration end
    // forge script script/TestRewardsV2.s.sol:TestRewardsV2 --rpc-url '<HOLESKY_RPC_URL>' --sig 'tx_6()' --private-key '<0xDA29BB71669f46F2a779b4b62f03644A84eE3479_PRIV_KEY>' -vvvv --broadcast
    function tx_6() public {
        IRewardsCoordinator.StrategyAndMultiplier[]
            memory strategyAndMultipliers = _setupStrategyAndMultiplier();

        IRewardsCoordinator.OperatorReward[]
            memory operatorRewards = new IRewardsCoordinator.OperatorReward[](
                1
            );
        operatorRewards[0] = IRewardsCoordinator.OperatorReward({
            operator: OPERATOR_EIGENYIELDS,
            amount: 1e18 // 1 WETH
        });

        IRewardsCoordinator.OperatorDirectedRewardsSubmission[]
            memory rewardsSubmissions = new IRewardsCoordinator.OperatorDirectedRewardsSubmission[](
                1
            );
        rewardsSubmissions[0] = IRewardsCoordinator
            .OperatorDirectedRewardsSubmission({
                strategiesAndMultipliers: strategyAndMultipliers,
                token: WETH,
                operatorRewards: operatorRewards,
                startTimestamp: uint32(1733788800), // 2024-12-10 00:00:00 UTC
                duration: uint32(518400), // 6 days
                description: ""
            });

        vm.broadcast();
        eigenDAServiceManager.createOperatorDirectedAVSRewardsSubmission(
            rewardsSubmissions
        );
    }

    // Test Operator Directed Rewards Submission: Operator not registered to avs for entire duration
    // forge script script/TestRewardsV2.s.sol:TestRewardsV2 --rpc-url '<HOLESKY_RPC_URL>' --sig 'tx_7()' --private-key '<0xDA29BB71669f46F2a779b4b62f03644A84eE3479_PRIV_KEY>' -vvvv --broadcast
    function tx_7() public {
        IRewardsCoordinator.StrategyAndMultiplier[]
            memory strategyAndMultipliers = _setupStrategyAndMultiplier();

        IRewardsCoordinator.OperatorReward[]
            memory operatorRewards = new IRewardsCoordinator.OperatorReward[](
                1
            );
        operatorRewards[0] = IRewardsCoordinator.OperatorReward({
            operator: OPERATOR_XYZ,
            amount: 1e18 // 1 WETH
        });

        IRewardsCoordinator.OperatorDirectedRewardsSubmission[]
            memory rewardsSubmissions = new IRewardsCoordinator.OperatorDirectedRewardsSubmission[](
                1
            );
        rewardsSubmissions[0] = IRewardsCoordinator
            .OperatorDirectedRewardsSubmission({
                strategiesAndMultipliers: strategyAndMultipliers,
                token: WETH,
                operatorRewards: operatorRewards,
                startTimestamp: uint32(1734048000), // 2024-12-13 00:00:00 UTC
                duration: uint32(259200), // 3 days
                description: ""
            });

        vm.broadcast();
        eigenDAServiceManager.createOperatorDirectedAVSRewardsSubmission(
            rewardsSubmissions
        );
    }
}
