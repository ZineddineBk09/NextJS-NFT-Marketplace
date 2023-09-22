const { ethers } = require('hardhat')
const { expect } = require('chai')


contract('NFTMarketplace', async (accounts) => {
  const NFTMarketplace = await ethers.getContract('NFTMarketplace') // Import the contract artifact
  let nftMarketplace // Declare the contract instance

  // Deploy the contract before each test
  beforeEach(async () => {
    nftMarketplace = await NFTMarketplace.new()
  })

  it('should list an item for sale', async () => {
    const tokenId = 1
    const price = web3.utils.toWei('1', 'ether')

    // Call the listIem function
    await nftMarketplace.listIem(tokenId, price, { from: accounts[0] })

    // Check if the item has been listed
    const listing = await nftMarketplace.getListing(tokenId)
    expect(listing.price).to.be.equal(price)
    expect(listing.seller).to.be.equal(accounts[0])
  })

  it('should allow buying a listed item', async () => {
    const tokenId = 1
    const price = web3.utils.toWei('1', 'ether')

    // List the item
    await nftMarketplace.listIem(tokenId, price, { from: accounts[0] })

    // Buy the item
    await nftMarketplace.buyItem(tokenId, { from: accounts[1], value: price })

    // Check if the item has been bought
    const listing = await nftMarketplace.getListing(tokenId)
    expect(listing.price).to.be.equal('0') // The price should be set to 0 after purchase
  })

  // Add more test cases for other contract functions here
})
