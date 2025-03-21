//
//  ArtworkRecognitionDemoApp.swift
//  ArtworkRecognitionDemo
//
//  Created by Matteo Seragiotto on 19/03/25.
//

import SwiftUI

@main
struct ArtworkRecognitionApp: App {
  var body: some Scene {
    WindowGroup {
      if #available(iOS 16.0, *) {
        ArtMuseumApp()
      } else {
        Text("This app requires iOS 16.0 or later")
      }
    }
  }
}
