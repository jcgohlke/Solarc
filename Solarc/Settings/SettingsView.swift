//
//  SettingsView.swift
//  Solarc
//
//  Created by Joben Gohlke on 6/23/22.
//

import SwiftUI
import StoreKit

struct SettingsView: View {
  @Binding var isPresenting: Bool
  
  @EnvironmentObject var subscriptionMgr: IAPSubscriptionManager
  @State private var currentSubscription: Product?
  @State private var status: SubStatus?
  
  init(isPresenting: Binding<Bool>) {
    self._isPresenting = isPresenting
    UITableView.appearance().backgroundColor = .clear
  }
  
  var body: some View {
    NavigationView {
      List {
        if currentSubscription == nil {
          Section {
            OfferCell(product: subscriptionMgr.yearlyProduct)
              .padding(.vertical, 10)
          }
        }
        
        Section {
          NavigationLink(destination: getSubscriptionDestination()) {
            SubscriptionStatusCell(product: currentSubscription, status: status)
          }
        } header: {
          Text("Account")
            .foregroundColor(.secondary)
        }
      }
      .background(Color.white.ignoresSafeArea())
      .navigationTitle("Settings")
      .toolbar(content: {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Done", action: {
            isPresenting.toggle()
          })
        }
      })
      .onAppear {
        Task {
          await updateSubscriptionStatus()
        }
      }
      .onChange(of: subscriptionMgr.purchasedIdentifiers) { _ in
        Task {
          await updateSubscriptionStatus()
        }
      }
    }
  }
  
  @MainActor
  func updateSubscriptionStatus() async {
    do {
      // Since we only have 1 subscription group, the status returned applies to every sub in the group.
      guard let product = subscriptionMgr.subscriptions.first,
            let statuses = try await product.subscription?.status else {
        return
      }
      
      var highestStatus: SubStatus? = nil
      var highestProduct: Product? = nil
      
      //Iterate through `statuses` for this subscription group and find
      //the `Status` with the highest level of service which isn't
      //expired or revoked.
      for status in statuses {
        switch status.state {
          case .expired, .revoked:
            continue
          default:
            let renewalInfo = try subscriptionMgr.checkVerified(status.renewalInfo)
            
            guard let newSubscription = subscriptionMgr.subscriptions.first(where: { $0.id == renewalInfo.currentProductID }) else {
              continue
            }
            
            guard let currentProduct = highestProduct else {
              highestStatus = status
              highestProduct = newSubscription
              continue
            }
            
            let highestTier = subscriptionMgr.tier(for: currentProduct.id)
            let newTier = subscriptionMgr.tier(for: renewalInfo.currentProductID)
            
            if newTier > highestTier {
              highestStatus = status
              highestProduct = newSubscription
            }
        }
      }
      
      status = highestStatus
      currentSubscription = highestProduct
    } catch {
      NSLog("Could not update subscription status \(error)")
    }
  }
  
  func getSubscriptionDestination() -> AnyView {
    if let currentSubscription = currentSubscription,
       let status = status {
      return AnyView(SubscriptionInfoView(currentSubscription: currentSubscription, status: status))
    } else {
      return AnyView(Text("Not currently subscribed"))
    }
  }
}

struct SettingsView_Previews: PreviewProvider {
  static var previews: some View {
    SettingsView(isPresenting: .constant(true))
      .environmentObject(IAPSubscriptionManager())
  }
}
