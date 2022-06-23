//
//  OfferCell.swift
//  Solarc
//
//  Created by Joben Gohlke on 6/23/22.
//

import SwiftUI
import StoreKit

struct OfferCell: View {
  @EnvironmentObject var subMgr: IAPSubscriptionManager
  
  var product: Product?
  
  @State var isPurchased: Bool = false
  @State var inProgress: Bool = false
  @State var errorTitle = ""
  @State var isShowingError: Bool = false
  
  var offerDescription: String {
    if let product = product {
      return subMgr.offerDescription(for: product)
    }
    
    return ""
  }
  
  var offerPeriodUnit: String {
    if let product = product {
      return subMgr.offerPeriodUnit(for: product)
    }
    
    return ""
  }
  
  var price: String {
    if let product = product {
      return subMgr.price(for: product)
    }
    
    return ""
  }
  
  var periodUnit: String {
    if let product = product {
      return subMgr.periodUnit(for: product)
    }
    
    return ""
  }
  
  var body: some View {
    VStack(spacing: 20) {
      VStack(alignment: .leading, spacing: 10) {
        Text("Weather Pro")
          .font(.title).bold()
          .foregroundColor(.primary)

        HStack {
          Text(offerDescription)
            .foregroundColor(.secondary)
            .font(.subheadline)
          .lineLimit(3)

          Spacer(minLength: 60)
        }
      }
      
      VStack(spacing: 10) {
        Button("Redeem Your Free \(offerPeriodUnit)", action: {
          inProgress.toggle()
          Task {
            await buy()
          }
        })
        .disabled(inProgress || isPurchased)

        Text("Then \(price) every \(periodUnit)")
          .foregroundColor(.primary)
      }
    }
    .background(Color.white)
    .alert(isPresented: $isShowingError, content: {
      Alert(title: Text(errorTitle), message: nil, dismissButton: .default(Text("OK")))
    })
  }
  
  func buy() async {
    do {
      if try await subMgr.purchaseProduct(for: .proYearly) == true {
        isPurchased = true
        inProgress.toggle()
      }
    } catch StoreError.productNotAvailable {
      errorTitle = "Product not available on the App Store."
      isShowingError = true
      inProgress.toggle()
    } catch {
      print("Failed purchase for yearly: \(error)")
    }
  }
}
