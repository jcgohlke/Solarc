//
//  IAPSubscriptionManager.swift
//  TradeLike
//
//  Modified by Joben Gohlke on 5/26/22 from demo Apple code.
//
//  The Store is responsible for requesting products from the App Store and starting purchases; other parts of
//  the app query the store to learn what products have been purchased.
//
//  Copyright © 2021 Apple Inc.
//
/*  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

import Foundation
import StoreKit

typealias Transaction = StoreKit.Transaction
typealias SubStatus = StoreKit.Product.SubscriptionInfo.Status
typealias RenewalInfo = StoreKit.Product.SubscriptionInfo.RenewalInfo
typealias RenewalState = StoreKit.Product.SubscriptionInfo.RenewalState

public enum StoreError: Error {
  case failedVerification
  case productNotAvailable
}

public enum SubscriptionTier: Int, Comparable {
  case none = 0
  case proMonthly = 1
  case proYearly = 2
  
  public static func < (lhs: Self, rhs: Self) -> Bool {
    return lhs.rawValue < rhs.rawValue
  }
}

class IAPSubscriptionManager: ObservableObject {
  @Published private(set) var subscriptions: [Product] = []
  @Published private(set) var purchasedIdentifiers = Set<String>()
  
  @Published private(set) var monthlyProduct: Product?
  @Published private(set) var yearlyProduct: Product?
  
  private static let subscriptionTier: [SubscriptionTier: String] = [
    .proMonthly: "subscription.pro.monthly",
    .proYearly: "subscription.pro.yearly"
  ]
  
  var updateListenerTask: Task<Void, Error>? = nil
  
  init() {
    //Start a transaction listener as close to app launch as possible so you don't miss any transactions.
    updateListenerTask = listenForTransactions()
    
    Task {
      //Initialize the store by starting a product request.
      await requestProducts()
    }
  }
  
  deinit {
    updateListenerTask?.cancel()
  }
  
  func listenForTransactions() -> Task<Void, Error> {
    return Task.detached {
      //Iterate through any transactions which didn't come from a direct call to `purchase()`.
      for await update in Transaction.updates {
        do {
//          let transaction = try self.checkVerified(update)
          let transaction = try update.payloadValue
          
          if let revocationDate   = transaction.revocationDate,
             let revocationReason = transaction.revocationReason {
            print("\(transaction.productID) revoked on \(revocationDate)")
            
            switch revocationReason {
              case .developerIssue:
                print("Revoked for developer issue")
              case .other:
                print("Revoked for other issue")
              default:
                print("Revoked for unknown reason")
            }
            
            // TODO: revoke entitlement
          }
          
          //Deliver content to the user.
          await self.updatePurchasedIdentifiers(transaction)
          
          //Always finish a transaction.
          await transaction.finish()
        } catch {
          //StoreKit has a receipt it can read but it failed verification. Don't deliver content to the user.
          print("Transaction failed verification")
        }
      }
    }
  }
  
  @MainActor
  func requestProducts() async {
    do {
      let foundSubscriptions = try await Product.products(for: IAPSubscriptionManager.subscriptionTier.values)
      subscriptions = sortByPrice(foundSubscriptions)
      monthlyProduct = getProduct(with: .proMonthly)
      yearlyProduct = getProduct(with: .proYearly)
    } catch {
      print("Failed product request: \(error)")
    }
  }
  
  func getProduct(with tier: SubscriptionTier) -> Product? {
    subscriptions.first(where: { $0.id == IAPSubscriptionManager.subscriptionTier[tier] })
  }
  
  @MainActor
  func purchaseProduct(for tier: SubscriptionTier) async throws -> Bool {
    guard let product = getProduct(with: tier) else {
      throw StoreError.productNotAvailable
    }
    
    if try await purchase(product) != nil {
      return true
    }
    
    return false
  }
  
  func hasOffer(for product: Product) -> Bool {
    if product.subscription?.introductoryOffer != nil {
      return true
    } else {
      return false
    }
  }
  
  func offerDescription(for product: Product) -> String {
    return "Solarc includes \(offerPeriod(for: product)) of Solarc Pro to try for free."
  }
  
  func offerPeriod(for product: Product) -> String {
    if let periodValue = product.subscription?.introductoryOffer?.period.value,
       let periodUnit = product.subscription?.introductoryOffer?.period.unit {
      return "\(periodValue) \(periodUnit)".lowercased()
    }
    
    return ""
  }
  
  func offerPeriodUnit(for product: Product) -> String {
    if let periodUnit = product.subscription?.introductoryOffer?.period.unit {
      return "\(periodUnit)"
    }
    
    return ""
  }
  
  func price(for product: Product) -> String {
    return "\(product.displayPrice)"
  }
  
  func priceAndPeriod(for product: Product) -> String {
    return "\(product.displayPrice)/\(periodUnit(for: product))"
  }
  
  func period(for product: Product) -> String {
    if let period = product.subscription?.subscriptionPeriod.value,
       let periodUnit = product.subscription?.subscriptionPeriod.unit {
      return "\(period) \(periodUnit)"
    }
    
    return ""
  }
  
  func periodUnit(for product: Product) -> String {
    if let period = product.subscription?.subscriptionPeriod.unit {
      return "\(period)".lowercased()
    }
    
    return ""
  }
  
  func purchase(_ product: Product) async throws -> Transaction? {
    //Begin a purchase.
    let result = try await product.purchase(options: []) // can add user's ID here
    
    switch result {
      case .success(let verification):
        let transaction = try checkVerified(verification)
        
        //Deliver content to the user.
        await updatePurchasedIdentifiers(transaction)
        
        //Always finish a transaction.
        await transaction.finish()
        
        return transaction
      case .userCancelled, .pending:
        // account verification needed, or parental approval needed
        return nil
      default:
        return nil
    }
  }
  
  func isPurchased(_ productIdentifier: String) async throws -> Bool {
    //Get the most recent transaction receipt for this `productIdentifier`.
    guard let result = await Transaction.latest(for: productIdentifier) else {
      //If there is no latest transaction, the product has not been purchased.
      return false
    }
    
    let transaction = try checkVerified(result)
    
    //Ignore revoked transactions, they're no longer purchased.
    
    //For subscriptions, a user can upgrade in the middle of their subscription period. The lower service
    //tier will then have the `isUpgraded` flag set and there will be a new transaction for the higher service
    //tier. Ignore the lower service tier transactions which have been upgraded.
    return transaction.revocationDate == nil && !transaction.isUpgraded
  }
  
  func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
    //Check if the transaction passes StoreKit verification.
    switch result {
      case .unverified:
        //StoreKit has parsed the JWS but failed verification. Don't deliver content to the user.
        throw StoreError.failedVerification
      case .verified(let safe):
        //If the transaction is verified, unwrap and return it.
        return safe
    }
  }
  
  @MainActor
  func updatePurchasedIdentifiers(_ transaction: Transaction) async {
    if transaction.revocationDate == nil {
      //If the App Store has not revoked the transaction, add it to the list of `purchasedIdentifiers`.
      purchasedIdentifiers.insert(transaction.productID)
    } else {
      //If the App Store has revoked this transaction, remove it from the list of `purchasedIdentifiers`.
      purchasedIdentifiers.remove(transaction.productID)
    }
  }
  
  func sortByPrice(_ products: [Product]) -> [Product] {
    products.sorted(by: { return $0.price > $1.price })
  }
  
  func tier(for productId: String) -> SubscriptionTier {
    switch productId {
      case "subscription.pro.monthly":
        return .proMonthly
      case "subscription.pro.yearly":
        return .proYearly
      default:
        return .none
    }
  }
}
