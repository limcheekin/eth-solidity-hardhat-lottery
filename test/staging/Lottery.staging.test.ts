import { assert, expect } from "chai"
import { BigNumber } from "ethers"
import { network, ethers, getNamedAccounts } from "hardhat"
import { Lottery } from "../../typechain-types"

network.config.chainId == 31337
    ? describe.skip
    : describe("Lottery Staging Tests", function () {
          let lottery: Lottery
          let lotteryEntranceFee: BigNumber
          let deployer: string
          beforeEach(async function () {
              deployer = (await getNamedAccounts()).deployer
              lottery = await ethers.getContract("Lottery", deployer)
              lotteryEntranceFee = await lottery.getEntranceFee()
          })

          describe("fulfillRandomWords", function () {
              it("works with live Chainlink Automation and Chainlink VRF, we get a random winner", async function () {
                  // enter the lottery
                  console.log("Setting up test...")
                  const startingTimeStamp = await lottery.getLastTimestamp()
                  const accounts = await ethers.getSigners()

                  console.log("Setting up Listener...")
                  await new Promise<void>(async (resolve, reject) => {
                      // setup listener before we enter the lottery
                      // Just in case the blockchain moves REALLY fast
                      lottery.once("LotteryWinnerPicked", async () => {
                          console.log("LotteryWinnerPicked event fired!")
                          try {
                              // add our asserts here
                              const lastWinner = await lottery.getLastWinner()
                              const lotteryStatus = await lottery.getLotteryStatus()
                              const winnerEndingBalance = await accounts[0].getBalance()
                              const endingTimeStamp = await lottery.getLastTimestamp()

                              await expect(lottery.getPlayer(0)).to.be.reverted
                              assert.equal(lastWinner.toString(), accounts[0].address)
                              assert.equal(lotteryStatus, 0)
                              assert.equal(
                                  winnerEndingBalance.toString(),
                                  winnerStartingBalance.add(lotteryEntranceFee).toString()
                              )
                              assert(endingTimeStamp > startingTimeStamp)
                              resolve()
                          } catch (error) {
                              console.log(error)
                              reject(error)
                          }
                      })
                      // Then entering the lottery
                      console.log("Entering Lottery...")
                      const tx = await lottery.enterLottery({
                          value: lotteryEntranceFee,
                      })
                      await tx.wait(1)
                      console.log("Ok, time to wait...")
                      const winnerStartingBalance = await accounts[0].getBalance()

                      // and this code WONT complete until our listener has finished listening!
                  })
              })
          })
      })
