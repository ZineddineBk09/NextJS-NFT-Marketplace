const { network } = require('hardhat')
const { verify } = require('../utils/verify')

const developmentChains = ['hardhat', 'localhost']

module.exports = async function ({ getNamedAccounts, deployments }) {
  const { deploy, log } = deployments
  const { deployer } = await getNamedAccounts()

  log(
    '========================= Deploying NFT Markeplace Contract =========================='
  )

  const args = []
  const nftMarketplace = await deploy('NFTMarketplace', {
    from: deployer,
    args: args,
    logs: true,
    waitConfirmations: network.config.blockConfirmations || 1,
  })

  // Verify Contract if not on development chain
  if (
    !developmentChains.includes(network.name) &&
    process.env.ETHERSCAN_API_KEY
  ) {
    log(`Verifying NFT Markeplace Contract on ${network.name} network...⌛⌛`)
    await verify(nftMarketplace.address, args)
    log(`NFT Markeplace Contract verified! ✅✅`)
  }

  log(
    `========================= Done Deploying NFT Markeplace Contract ✅ =========================`
  )
}
