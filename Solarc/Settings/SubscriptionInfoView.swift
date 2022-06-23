//
//  SubscriptionInfoView.swift
//  Solarc
//
//  Created by Joben Gohlke on 6/23/22.
//

import SwiftUI
import StoreKit

struct SubscriptionInfoView: View {
  @EnvironmentObject var subMgr: IAPSubscriptionManager
  
  let currentSubscription: Product
  let status: SubStatus
  
  @State var planName: String = ""
  @State var planStatus: String = ""
  @State var renewsExpiresLabelString: String = "Renews"
  @State var renewalExpireDateDescription: String = ""
  
  var body: some View {
    List {
      VStack(alignment: .leading, spacing: 20) {
        Text("Trade Like is the best place to get the jump on how insiders are trading their company's stocks.")
        
        Text("We make it easy to cancel anytime, right here without talking to anyone.")
      }
      .font(.callout)
      .padding()
      .foregroundColor(.primary)
      .listRowBackground(Color.white)
      
      Section {
        HStack {
          Text("Current Plan")
            .foregroundColor(.secondary)
          
          Spacer()
          
          Text("\(planName)")
        }
        
        HStack {
          Text(renewsExpiresLabelString)
            .foregroundColor(.secondary)
          
          Spacer()
          
          Text(renewalExpireDateDescription)
        }
        
        Text(planStatus)
          .padding(5)
      }
      
      Section {
        Button("Manage subscription", action: {
          if let url = URL(string: "https://apps.apple.com/account/subscriptions"),
             UIApplication.shared.canOpenURL(url) {
              UIApplication.shared.open(url, options: [:])
          }
        })
      }
    }
    .navigationTitle("Solarc Pro")
    .onAppear {
      determinePlanState()
    }
  }
  
  /// Determine the subscription status of the current plan and populate relevant state variables for display.
  fileprivate func determinePlanState() {
    guard case .verified(let renewalInfo) = status.renewalInfo,
          case .verified(let transaction) = status.transaction else {
      planName = "N/A"
      renewsExpiresLabelString = "Expires"
      renewalExpireDateDescription = "N/A"
      planStatus = "The App Store could not verify your subscription status."
      return
    }
    
    switch status.state {
      case .subscribed:
        configureRenewalData(renewalInfo, transaction)
      case .expired:
        configureExpirationData(renewalInfo, transaction)
      case .revoked:
        if let revokedDate = transaction.revocationDate {
          planName = "None"
          renewsExpiresLabelString = "Expires"
          renewalExpireDateDescription = "N/A"
          planStatus = "The App Store refunded your subscription to \(currentSubscription.displayName) on \(revokedDate.formattedDate())."
        }
      case .inGracePeriod:
        configureGracePeriodData(renewalInfo)
      case .inBillingRetryPeriod:
        configureBillingRetryData()
      default:
        break
    }
  }
  
  /// Configure the view state to reflect a subscription experiencing billing issues.
  fileprivate func configureBillingRetryData() {
    planName = currentSubscription.displayName
    renewsExpiresLabelString = "Expires"
    renewalExpireDateDescription = "N/A"
    
    var description = "The App Store could not confirm your billing information for \(currentSubscription.displayName)."
    description += " Please verify your billing information to resume service."
    
    planStatus = description
  }
  
  /// Configure the view state to reflect a subscription experiencing billing issues, but in an active grace period.
  fileprivate func configureGracePeriodData(_ renewalInfo: RenewalInfo) {
    planName = currentSubscription.displayName
    renewsExpiresLabelString = "Expires"
    
    var description = "The App Store could not confirm your billing information for \(currentSubscription.displayName)."
    
    if let untilDate = renewalInfo.gracePeriodExpirationDate {
      renewalExpireDateDescription = untilDate.formattedDate()
      description += " Please verify your billing information to continue service after \(untilDate.formattedDate())"
    } else {
      renewalExpireDateDescription = "N/A"
    }
    
    planStatus = description
  }
  
  /// Configure the view state to reflect a renewing, active subscription.
  fileprivate func configureRenewalData(_ renewalInfo: RenewalInfo, _ transaction: Transaction) {
    planName = currentSubscription.displayName
    renewsExpiresLabelString = renewalInfo.willAutoRenew ? "Renews" : "Expires"
    if let expirationDate = transaction.expirationDate {
      renewalExpireDateDescription = expirationDate.formattedDate()
    
      var description = ""
    
      if let newProductID = renewalInfo.autoRenewPreference {
        if let newProduct = subMgr.subscriptions.first(where: { $0.id == newProductID }) {
          if newProduct != currentSubscription {
            description += "Your subscription to \(newProduct.displayName)"
            description += " will begin when your current subscription expires on \(expirationDate.formattedDate())."
          } else {
            description += "Your subscription to \(newProduct.displayName)"
            description += " is active and renews on \(expirationDate.formattedDate())."
          }
        }
      } else if renewalInfo.willAutoRenew {
        description += "\nNext billing date: \(expirationDate.formattedDate())."
      } else {
        description += "Your subscription to \(currentSubscription.displayName) will expire on \(expirationDate.formattedDate())."
      }
      
      planStatus = description
    }
  }
  
  /// Configure view state to reflect an expiring subscription.
  fileprivate func configureExpirationData(_ renewalInfo: RenewalInfo, _ transaction: Transaction) {
    planName = currentSubscription.displayName
    
    if let expirationDate = transaction.expirationDate,
       let expirationReason = renewalInfo.expirationReason {
    
      var description: String
      
      switch expirationReason {
        case .autoRenewDisabled:
          if expirationDate > Date() {
            description = "Your subscription to \(currentSubscription.displayName) will expire on \(expirationDate.formattedDate())."
          } else {
            description = "Your subscription to \(currentSubscription.displayName) expired on \(expirationDate.formattedDate())."
          }
        case .billingError:
          description = "Your subscription to \(currentSubscription.displayName) was not renewed due to a billing error."
        case .didNotConsentToPriceIncrease:
          description = "Your subscription to \(currentSubscription.displayName) was not renewed due to a price increase that you disapproved."
        case .productUnavailable:
          description = "Your subscription to \(currentSubscription.displayName) was not renewed because the product is no longer available."
        default:
          description = "Your subscription to \(currentSubscription.displayName) was not renewed."
      }
      
      renewalExpireDateDescription = expirationDate.formattedDate()
      planStatus = description
    } else {
      renewalExpireDateDescription = "N/A"
      planStatus = "Your subscription has expired."
    }
  }
}

extension Date {
  init(dateString: String) {
    let df = DateFormatter()
    df.dateFormat = "yyyy-MM-dd HH:mm:ss"
    df.locale = .current
    let d = df.date(from: dateString)!
    self.init(timeInterval: 0, since: d)
  }
  
  func formattedDate() -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "MMM dd, yyyy"
    return dateFormatter.string(from: self)
  }
}
