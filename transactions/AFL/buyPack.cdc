import AFLAdmin from 0xAFL_ADDRESS
import AFLPack from 0xAFL_ADDRESS
import FungibleToken from 0xFUNGIBLE_TOKEN_ADDRESS
import FiatToken from 0xFIAT_TOKEN_ADDRESS

transaction(templateIds: [UInt64], packTemplateId: UInt64, price:UFix64, receiptAddress: Address) {
  let adminRef: &AFLPack.Pack
  let temporaryVault : @FungibleToken.Vault
  prepare(adminAccount: AuthAccount, tokenRecipientAccount: AuthAccount){
      self.adminRef = adminAccount.borrow<&AFLPack.Pack>(from: AFLPack.PackStoragePath)
          ??panic("could not borrow admin reference")
      let vaultRef = tokenRecipientAccount.borrow<&FiatToken.Vault>(from: FiatToken.VaultStoragePath)
              ??panic("could not borrow vault")
      self.temporaryVault <- vaultRef.withdraw(amount: price)
  }
  execute{
      self.adminRef.buyPack(templateIds: templateIds, packTemplateId: packTemplateId, receiptAddress: receiptAddress, price: price, flowPayment: <- self.temporaryVault)
  }
}