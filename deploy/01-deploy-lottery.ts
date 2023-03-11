import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import { networkConfig, VERIFICATION_BLOCK_CONFIRMATIONS, LINE } from "../helper-hardhat-config"
import verify from "../utils/verify"

const FUND_AMOUNT = "1000000000000000000000"

const deployLottery: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts, network, ethers } = hre
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()
    const chainId = network.config.chainId!

    let vrfCoordinatorV2Address: string | undefined
    let subscriptionId: string | undefined
    let waitBlockConfirmations: number | undefined
    let vrfCoordinatorV2Mock: any | undefined

    if (chainId == 31337) {
        // create VRFV2 Subscription
        vrfCoordinatorV2Mock = await ethers.getContract("VRFCoordinatorV2Mock")
        vrfCoordinatorV2Address = vrfCoordinatorV2Mock.address
        const transactionResponse = await vrfCoordinatorV2Mock.createSubscription()
        const transactionReceipt = await transactionResponse.wait()
        subscriptionId = transactionReceipt.events[0].args.subId
        waitBlockConfirmations = 1
        // Fund the subscription
        // Our mock makes it so we don't actually have to worry about sending fund
        await vrfCoordinatorV2Mock.fundSubscription(subscriptionId, FUND_AMOUNT)
    } else {
        vrfCoordinatorV2Address = networkConfig[chainId]["vrfCoordinatorV2"]
        subscriptionId = networkConfig[chainId]["subscriptionId"]
        waitBlockConfirmations = VERIFICATION_BLOCK_CONFIRMATIONS
    }

    const args: any[] = [
        vrfCoordinatorV2Address,
        subscriptionId,
        networkConfig[chainId]["gasLane"],
        networkConfig[chainId]["callbackGasLimit"],
        networkConfig[chainId]["keepersUpdateInterval"],
        networkConfig[chainId]["lotteryEntranceFee"],
    ]
    const lottery = await deploy("Lottery", {
        from: deployer,
        args: args,
        log: true,
        autoMine: true,
        waitConfirmations: waitBlockConfirmations,
        // speed up deployment on local network (ganache, hardhat), no effect on live networks
    })

    /*
     * REF: reverted with custom error 'InvalidConsumer()' error
     * https://github.com/smartcontractkit/full-blockchain-solidity-course-js/discussions/1375
     */
    if (chainId == 31337) {
        await vrfCoordinatorV2Mock.addConsumer(subscriptionId, lottery.address)
    }
    log(LINE)

    // Verify the deployment
    if (chainId != 31337 && process.env.ETHERSCAN_API_KEY) {
        log("Verifying...")
        await verify(lottery.address, args)
    }
}
export default deployLottery
deployLottery.tags = ["lottery"]
