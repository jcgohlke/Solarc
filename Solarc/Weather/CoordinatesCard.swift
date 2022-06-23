//
//  CoordinatesCard.swift
//  Solarc
//
//  Created by Joben Gohlke on 6/22/22.
//

import SwiftUI
import CoreLocation

struct CoordinatesCard: View {
  var location: AnnotatedItem
  
  var body: some View {
    Text("\(location.coordinate.latitude), \(location.coordinate.longitude)")
      .font(.system(size: 17, weight: .semibold, design: .rounded))
      .foregroundStyle(.secondary)
      .padding()
      .background(
        .white,
          in: RoundedRectangle(
            cornerRadius: 20,
            style: .continuous
          )
        )
  }
}

struct CoordinatesCard_Previews: PreviewProvider {
  static var previews: some View {
    CoordinatesCard(
      location: AnnotatedItem(
        name: "Orlando, FL",
        coordinate: CLLocationCoordinate2D(
          latitude: 28.538336,
          longitude: -81.379234
        )
      )
    )
  }
}
