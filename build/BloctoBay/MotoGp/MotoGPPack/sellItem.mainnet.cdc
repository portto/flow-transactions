import FungibleToken from 0xf233dcee88fe0abe
import NonFungibleToken from 0x1d7e57aa55817448
import NFTStorefront from 0x5b82f21c0edf76e3
import Marketplace from 0xdc5127882cacf8d9
import FlowToken from 0x1654653399040a61
import MotoGPPack from 0xa49cc0ee46c54bfb

transaction(saleItemID: UInt64, saleItemPrice: UFix64) {
    let flowTokenReceiver: Capability<&FlowToken.Vault{FungibleToken.Receiver}>
    let motoGPPackProvider: Capability<&MotoGPPack.Collection{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>
    let storefront: &NFTStorefront.Storefront
    let storefrontPublic: Capability<&NFTStorefront.Storefront{NFTStorefront.StorefrontPublic}>

    prepare(signer: AuthAccount) {
        // Create Storefront if it doesn't exist
        if signer.borrow<&NFTStorefront.Storefront>(from: NFTStorefront.StorefrontStoragePath) == nil {
            let storefront <- NFTStorefront.createStorefront() as! @NFTStorefront.Storefront
            signer.save(<-storefront, to: NFTStorefront.StorefrontStoragePath)
            signer.link<&NFTStorefront.Storefront{NFTStorefront.StorefrontPublic}>(
                NFTStorefront.StorefrontPublicPath,
                target: NFTStorefront.StorefrontStoragePath)
        }

        // We need a provider capability, but one is not provided by default so we create one if needed.
        let motoGPPackCollectionProviderPrivatePath = /private/motoGPPackCollectionProviderForNFTStorefront
        if !signer.getCapability<&MotoGPPack.Collection{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(motoGPPackCollectionProviderPrivatePath)!.check() {
            signer.link<&MotoGPPack.Collection{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(motoGPPackCollectionProviderPrivatePath, target: /storage/motogpPackCollection)
        }

        self.flowTokenReceiver = signer.getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver)!
        assert(self.flowTokenReceiver.borrow() != nil, message: "Missing or mis-typed FlowToken receiver")

        self.motoGPPackProvider = signer.getCapability<&MotoGPPack.Collection{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(motoGPPackCollectionProviderPrivatePath)!
        assert(self.motoGPPackProvider.borrow() != nil, message: "Missing or mis-typed MotoGPPack.Collection provider")

        self.storefront = signer.borrow<&NFTStorefront.Storefront>(from: NFTStorefront.StorefrontStoragePath)
            ?? panic("Missing or mis-typed NFTStorefront Storefront")

        self.storefrontPublic = signer.getCapability<&NFTStorefront.Storefront{NFTStorefront.StorefrontPublic}>(NFTStorefront.StorefrontPublicPath)
        assert(self.storefrontPublic.borrow() != nil, message: "Could not borrow public storefront from address")
    }

    execute {
        // Remove old listing
        if let listingID = Marketplace.getListingID(nftType: Type<@MotoGPPack.NFT>(), nftID: saleItemID) {
            let listingIDs = self.storefront.getListingIDs()
            if listingIDs.contains(listingID) {
                self.storefront.removeListing(listingResourceID: listingID)
            }
            Marketplace.removeListing(id: listingID)
        }

        // Create SaleCuts
        var saleCuts: [NFTStorefront.SaleCut] = []
        let requirements = Marketplace.getSaleCutRequirements(nftType: Type<@MotoGPPack.NFT>())
        var remainingPrice = saleItemPrice
        for requirement in requirements {
            let price = saleItemPrice * requirement.ratio
            saleCuts.append(NFTStorefront.SaleCut(
                receiver: requirement.receiver,
                amount: price
            ))
            remainingPrice = remainingPrice - price
        }
        saleCuts.append(NFTStorefront.SaleCut(
            receiver: self.flowTokenReceiver,
            amount: remainingPrice
        ))

        // Add listing
        let id = self.storefront.createListing(
            nftProviderCapability: self.motoGPPackProvider,
            nftType: Type<@MotoGPPack.NFT>(),
            nftID: saleItemID,
            salePaymentVaultType: Type<@FlowToken.Vault>(),
            saleCuts: saleCuts
        )
        Marketplace.addListing(id: id, storefrontPublicCapability: self.storefrontPublic)
    }
}