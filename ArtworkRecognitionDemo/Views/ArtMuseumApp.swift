//
//  ArtMuseumApp.swift
//  ArtworkRecognitionDemo
//
//  Created by Matteo Seragiotto on 20/03/25.
//

import SwiftUI
import ARKit
import MARS

@available(iOS 16.0, *)
struct ArtMuseumApp: View {
  @StateObject private var coordinator = ARCoordinator(artworks: [
    ArtworkReference(
      name: "Mona Lisa",
      image: UIImage(named: "mona_lisa")!,
      physicalWidth: 0.53, // in meters
      description: "Painted by Leonardo da Vinci between 1503 and 1506"
    ),
    ArtworkReference(
      name: "Starry Night",
      image: UIImage(named: "starry_night")!,
      physicalWidth: 0.74, // in meters
      description: "Painted by Vincent van Gogh in 1889"
    )
  ])
  
  @State private var showMap = false
  @State private var showArtworkInfo = false
  @State private var showMuseumPicker = false
  @State private var showAppFolderPath = false
  
  var body: some View {
    ZStack {
      // AR View
      ARSCNViewWrapper(arView: coordinator.arView)
        .edgesIgnoringSafeArea(.all)
      
      // Status Overlay
      VStack {
        // Top status bar
        HStack {
          VStack(alignment: .leading) {
            if let museum = coordinator.selectedMuseum {
              Text("Museum: \(museum.name)")
                .font(.headline)
            }
            
            Text("Room: \(coordinator.currentRoom)")
              .font(.headline)
            
            if let artwork = coordinator.currentArtwork {
              Text("Artwork: \(artwork)")
                .font(.headline)
                .foregroundColor(.green)
            }
          }
          .padding()
          .background(Color.black.opacity(0.7))
          .foregroundColor(.white)
          .cornerRadius(10)
          
          Spacer()
          
          Button(action: {
            showMap.toggle()
          }) {
            Image(systemName: "map")
              .font(.title)
              .padding()
              .background(Color.black.opacity(0.7))
              .foregroundColor(.white)
              .cornerRadius(10)
          }
        }
        .padding(.top, 40)
        .padding(.horizontal)
        
        // Display loading indicator or error messages in the center
        if coordinator.isLoading {
          Spacer()
          ProgressView("Loading museums...")
            .padding()
            .background(Color.black.opacity(0.7))
            .foregroundColor(.white)
            .cornerRadius(10)
          Spacer()
        } else if let error = coordinator.errorMessage {
          Spacer()
          VStack {
            Text("Museum Data Not Found")
              .font(.headline)
            
            Text(error)
              .font(.subheadline)
              .multilineTextAlignment(.center)
            
            Button("Show App Folder Path") {
              showAppFolderPath = true
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            .padding(.top)
            
            Button("Refresh") {
              coordinator.loadLocalMuseums()
            }
            .padding()
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(10)
          }
          .padding()
          .background(Color.black.opacity(0.8))
          .foregroundColor(.white)
          .cornerRadius(10)
          Spacer()
        }
        
        Spacer()
        
        // Bottom controls
        HStack {
          // Only show museum controls if we have museums
          if !coordinator.museums.isEmpty {
            Button("Select Museum") {
              showMuseumPicker = true
            }
            .padding()
            .background(Color.purple)
            .foregroundColor(.white)
            .cornerRadius(10)
            
            Button("Initialize MARS") {
              coordinator.initializeMARS()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            .disabled(coordinator.selectedMuseum == nil)
          }
          
          if coordinator.currentArtwork != nil {
            Button("Artwork Info") {
              showArtworkInfo = true
            }
            .padding()
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(10)
          }
        }
        .padding(.bottom, 30)
      }
      
      // Show MARS map when requested
      if showMap {
        coordinator.showMap()
          .transition(.opacity)
          .onTapGesture {
            showMap = false
          }
      }
    }
    .sheet(isPresented: $showArtworkInfo) {
      if let artworkName = coordinator.currentArtwork {
        ArtworkInfoView(artworkName: artworkName)
      }
    }
    .sheet(isPresented: $showMuseumPicker) {
      MuseumPickerView(
        museums: coordinator.museums,
        selectedMuseum: $coordinator.selectedMuseum
      )
    }
    .alert("App Folder Path", isPresented: $showAppFolderPath) {
      Button("Copy Path", role: .none) {
        UIPasteboard.general.string = coordinator.getAppFolderPath()
      }
      Button("OK", role: .cancel) {}
    } message: {
      Text("Copy this path to find where to place your museum folders:\n\n\(coordinator.getAppFolderPath())")
    }
  }
}
