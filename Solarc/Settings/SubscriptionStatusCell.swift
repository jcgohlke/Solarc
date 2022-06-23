//
//  SubscriptionStatusCell.swift
//  Solarc
//
//  Created by Joben Gohlke on 6/23/22.
//

import SwiftUI
import StoreKit

struct SubscriptionStatusCell: View {
  @EnvironmentObject var store: IAPSubscriptionManager
  
  let product: Product?
  let status: SubStatus?
  
  var body: some View {
    HStack {
      Text("Solarc Pro")
        .foregroundColor(.primary)
      
      Spacer()
      
      statusImage
    }
    .background(Color.white)
  }
  
  var subscribed: Bool {
    if let status = status,
       status.state == .subscribed {
      return true
    } else {
      return false
    }
  }
  
  @ViewBuilder
  var statusImage: some View {
    if let status = status {
      switch status.state {
        case .subscribed:
          Image(systemName: "checkmark.circle.fill")
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(Color.blue)
            .font(.system(size: 22, weight: .regular))
        case .expired, .revoked:
          Image(systemName: "exclamationmark.triangle.fill")
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, .red)
            .font(.system(size: 18, weight: .regular))
        case .inGracePeriod, .inBillingRetryPeriod:
          Image(systemName: "exclamationmark.triangle.fill")
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, .yellow)
            .font(.system(size: 18, weight: .regular))
        default:
          Text("Not subscribed")
            .foregroundColor(.primary)
      }
    } else {
      Text("Not subscribed")
        .foregroundColor(.primary)
    }
  }
}
