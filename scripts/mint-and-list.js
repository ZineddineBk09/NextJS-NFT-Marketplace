// this script is to mint an nft and list it on opensea

const { ethers } = require('hardhat')

const PRICE = ethers.parseEther('0.1').toString()

async function mintAndList() {
  // Contracts
  const nftMarketplace = await ethers.getContract('NFTMarketplace')
  const basicNft = await ethers.getContract('BasicNFT')

  // Minting
  console.log('Minting NFT...')
  const mintTx = await basicNft.mintNft()
  const mintTxReceipt = await mintTx.wait(1)
  // get the tokenId from the event emitted by the BasicNFT contract inside the mintNft function
  console.log('events: ', mintTxReceipt.events)
  const tokenId = mintTxReceipt.events[0].args.tokenId || 0
  console.log(`NFT minted with tokenId: ${tokenId}`)

  // Approving
  console.log('Approving NFT...')
  const approvlTx = await basicNft.approve(nftMarketplace.address, tokenId)
  await approvlTx.wait(1)

  // Listing
  console.log('Listing NFT...')
  const tx = await nftMarketplace.listItem(basicNft.address, tokenId,PRICE)
  await tx.wait(1)
  console.log('NFT listed! 🎉🎉')
}

mintAndList()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })