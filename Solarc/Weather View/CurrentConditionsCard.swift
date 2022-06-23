//
//  CurrentConditionsCard.swift
//  Solarc
//
//  Created by Joben Gohlke on 6/22/22.
//

import SwiftUI
import WeatherKit

struct CurrentConditionsCard: View {
  var cityState = "Orlando, FL"
  var temperature: Measurement<UnitTemperature>
  var symbolName: String
  var apparentTemperature: Measurement<UnitTemperature>
  var currentCondition: WeatherCondition
  var cloudCover: Double
  
  var body: some View {
    VStack(alignment: .leading) {
      Text(cityState.uppercased())
        .font(.subheadline)
        .foregroundStyle(.secondary)
      
      
      HStack {
        Label(temperature.formatted(), systemImage: "thermometer")
        
        Spacer()
        
        Label("feels like: \(apparentTemperature.formatted())", systemImage: "thermometer.sun")
        
        Spacer()
        
        Label(currentCondition.description, systemImage: symbolName)
        
        Spacer()
        
        Label("\(Int(cloudCover * 100))% cloud cover", systemImage: "cloud")
      }
      .labelStyle(CurrentConditionsCardLabelStyle())
    }
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

struct CurrentConditionsCard_Previews: PreviewProvider {
  static var previews: some View {
    CurrentConditionsCard(
      temperature: Measurement(value: 72, unit: .fahrenheit),
      symbolName: "sun.max",
      apparentTemperature: Measurement(value: 79, unit: .fahrenheit),
      currentCondition: .clear,
      cloudCover: 0.4
    )
  }
}

struct CurrentConditionsCardLabelStyle: LabelStyle {
  func makeBody(configuration: Configuration) -> some View {
    VStack {
      configuration.icon
        .font(.system(size: 18))
        .imageScale(.large)
        .frame(width: 30, height: 30)
        .foregroundStyle(.secondary)
      
      configuration.title
        .foregroundStyle(.primary)
        .font(.footnote)
    }
  }
}
