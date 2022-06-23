//
//  MyWeatherView.swift
//  Solarc
//
//  Created by Joben Gohlke on 6/19/22.
//

import SwiftUI
import MapKit
import CoreLocationUI
import WeatherKit

struct MyWeatherView: View {
  let annotations: [AnnotatedItem] = [
      AnnotatedItem(name: "Orlando, FL", coordinate: CLLocationCoordinate2D(latitude: 28.538336, longitude: -81.379234))
    ]
  
  @StateObject var subscriptionMgr: IAPSubscriptionManager = IAPSubscriptionManager()
  
  // Orlando, FL
  @State var region = MKCoordinateRegion(
    center:  CLLocationCoordinate2D(
      latitude: 28.538336,
      longitude: -81.379234
    ),
    span: MKCoordinateSpan(
      latitudeDelta: 0.25,
      longitudeDelta: 0.25
    )
  )
  @State private var condition: WeatherCondition?
  @State private var cloudCover: Double?
  @State private var temperature: Measurement<UnitTemperature>?
  @State private var apparentTemperature: Measurement<UnitTemperature>?
  @State private var symbolName: String?
  
  @State private var attributionLink: URL?
  @State private var attributionLogo: URL?
  
  @State var isPresentingSettings: Bool = false
  
  @Environment(\.colorScheme) var colorScheme: ColorScheme
  
  var body: some View {
    ZStack {
      Map(
        coordinateRegion: $region,
        annotationItems: annotations,
        annotationContent: { item in
          MapMarker(coordinate: item.coordinate, tint: .purple)
        }
      )
      .ignoresSafeArea()
      
      VStack {
        CoordinatesCard(location: annotations[0])
        Spacer()
        
        CurrentConditionsCard(
          temperature: temperature ?? Measurement(value: 72, unit: .fahrenheit),
          symbolName: symbolName ?? "sun.max",
          apparentTemperature: apparentTemperature ?? Measurement(value: 79, unit: .fahrenheit),
          currentCondition: condition ?? .clear,
          cloudCover: cloudCover ?? 0.2
        )
        
        Button {
          isPresentingSettings.toggle()
        } label: {
          Label("Settings", systemImage: "gear")
        }
        .buttonStyle(.borderedProminent)
        
        // TODO: Insert logo (https://weather-data.apple.com/assets/branding/combined-mark-light.png currently 404's)
        
//        Link("Other data sources", destination: attributionLink ?? URL(string: "https://weather-data.apple.com/legal-attribution.html")!)
//          .font(.footnote)
      }
      .padding()
      .task {
        do {
          let location = CLLocation(latitude: annotations[0].coordinate.latitude, longitude: annotations[0].coordinate.longitude)
          let weather = try await WeatherService.shared.weather(for: location)
          condition = weather.currentWeather.condition
          cloudCover = weather.currentWeather.cloudCover
          temperature = weather.currentWeather.temperature
          apparentTemperature = weather.currentWeather.apparentTemperature
          symbolName = weather.currentWeather.symbolName
            
          let attribution = try await WeatherService.shared.attribution
          attributionLink = attribution.legalPageURL
          attributionLogo = colorScheme == .light ? attribution.combinedMarkLightURL : attribution.combinedMarkDarkURL
        } catch {
          print("Could not gather weather information...", error.localizedDescription)
          condition = .clear
          cloudCover = 0.15
        }
      }
      .sheet(isPresented: $isPresentingSettings) {
        SettingsView(isPresenting: $isPresentingSettings)
          .environmentObject(subscriptionMgr)
      }
    }
  }
}

struct MyWeatherView_Previews: PreviewProvider {
  static var previews: some View {
    MyWeatherView()
  }
}
