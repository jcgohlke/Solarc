//
//  AnnotatedItem.swift
//  Solarc
//
//  Created by Joben Gohlke on 6/22/22.
//

import Foundation
import CoreLocation

struct AnnotatedItem: Identifiable {
  let id = UUID()
  var name: String
  var coordinate: CLLocationCoordinate2D
}
