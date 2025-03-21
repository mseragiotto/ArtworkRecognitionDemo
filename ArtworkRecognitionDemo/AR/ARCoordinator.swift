//
//  ARCoordinator.swift
//  ArtworkRecognitionDemo
//
//  Created by Matteo Seragiotto on 19/03/25.
//

import SwiftUI
import ARKit
import MARS
import Combine

@available(iOS 16.0, *)
class ARCoordinator: ObservableObject, @unchecked Sendable {
  // AR Components
  let arView = ARSCNView()
  let artworkRecognizer: ArtworkRecognitionDelegate
  var marsPositionProvider: PositionProvider?
  
  // Published state
  @Published var currentRoom: String = "Not located"
  @Published var currentArtwork: String?
  @Published var isNavigating: Bool = false
  
  // Museum loading state
  @Published var museums: [Museum] = []
  @Published var isLoading = false
  @Published var errorMessage: String?
  @Published var selectedMuseum: Museum?
  @Published var appFolderURL: URL?
  
  // Store subscriptions
  private var cancellables = Set<AnyCancellable>()
  
  init(artworks: [ArtworkReference]) {
    // Initialize the artwork recognizer
    self.artworkRecognizer = ArtworkRecognitionDelegate(artworkImages: artworks)
    
    // Set up the delegate multiplexer to handle both artwork and MARS callbacks
    let delegateMultiplexer = ARSCNDelegateMultiplexer()
    delegateMultiplexer.addDelegate(artworkRecognizer)
    
    // Assign the multiplexer to the AR view
    arView.delegate = delegateMultiplexer
    
    // Configure basic AR settings
    let configuration = ARWorldTrackingConfiguration()
    configuration.planeDetection = [.horizontal, .vertical]
    configuration.detectionImages = artworkRecognizer.artworkImages
    configuration.maximumNumberOfTrackedImages = 10
    arView.session.run(configuration)
    
    // Subscribe to artwork recognition events
    artworkRecognizer.recognitionPublisher
      .receive(on: RunLoop.main)
      .sink { [weak self] artworkName in
        self?.artworkRecognized(artworkName)
      }
      .store(in: &cancellables)
    
    // Load museums from local storage
    setupAppFolder()
    loadLocalMuseums()
  }
  
  // MARK: - App Folder Setup
  
  func setupAppFolder() {
    // Get the app's name for the folder name
    let appName = Bundle.main.infoDictionary?[kCFBundleNameKey as String] as? String ?? "ARMuseumApp"
    
    // Create the app folder in Documents
    if let folder = FileManager.getOrCreateAppFolder(named: appName) {
      self.appFolderURL = folder
      
      // Make it visible in the Files app
      FileManager.makeAppFolderVisible(named: appName)
      
      // Add a README.txt file to help users
      let readmePath = folder.appendingPathComponent("README.txt")
      let readmeText = """
          This folder is for museum data files.
          
          Please copy your museum folders here.
          Each museum folder should contain floor folders.
          
          Example structure:
          - Museum1/
            - Floor1/
            - Floor2/
          - Museum2/
            - Floor1/
            - Floor2/
          """
      
      if !FileManager.default.fileExists(atPath: readmePath.path) {
        try? readmeText.write(to: readmePath, atomically: true, encoding: .utf8)
      }
    } else {
      errorMessage = "Failed to create app folder"
    }
  }
  // MARK: - Museum Loading Functions
  
  func loadLocalMuseums() {
    guard let appFolderURL = self.appFolderURL else {
      errorMessage = "App folder path not available"
      return
    }
    
    isLoading = true
    errorMessage = nil
    
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self = self else { return }
      let localMuseums = self.loadLocalMuseumsFromAppFolder(appFolderURL)
      
      DispatchQueue.main.async {
        self.isLoading = false
        if localMuseums.isEmpty {
          self.errorMessage = "No museums found. Please copy museum data to:\n\(appFolderURL.path)"
        } else {
          self.museums = localMuseums
          // Select the first museum by default
          if let firstMuseum = localMuseums.first {
            self.selectedMuseum = firstMuseum
          }
        }
      }
    }
  }
  
  private func loadLocalMuseumsFromAppFolder(_ appFolderURL: URL) -> [Museum] {
    var result: [Museum] = []
    let fileManager = FileManager.default
    
    do {
      // Get list of subfolders (museums) directly in the app folder
      let museumFolders = try fileManager.contentsOfDirectory(
        at: appFolderURL,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles]
      )
      
      for museumURL in museumFolders {
        // Check if it's a directory
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: museumURL.path, isDirectory: &isDirectory) && isDirectory.boolValue {
          let museumName = museumURL.lastPathComponent
          
          // Load floors for each museum
          let floors = try loadFloors(in: museumURL)
          
          let museum = Museum(name: museumName, floors: floors)
          result.append(museum)
          print("✅ Found museum: \(museumName) with \(floors.count) floors")
        }
      }
      
    } catch {
      print("❌ Error enumerating museums: \(error)")
    }
    
    return result
  }
  
  // MARK: Obtain floors from file storage
  private func loadFloors(in museumURL: URL) throws -> [Floor] {
    var floors: [Floor] = []
    
    let floorFolders = try FileManager.default.contentsOfDirectory(
      at: museumURL,
      includingPropertiesForKeys: [.isDirectoryKey],
      options: [.skipsHiddenFiles]
    )
    
    for floorURL in floorFolders {
      var isDirectory: ObjCBool = false
      if FileManager.default.fileExists(atPath: floorURL.path, isDirectory: &isDirectory) && isDirectory.boolValue {
        let floorName = floorURL.lastPathComponent
        // Create ARLFile
        let arlFile = ARLFile(floorName: floorName, floorFolderURL: floorURL)
        
        let floor = Floor(name: floorName, arlFile: arlFile)
        floors.append(floor)
        print("✅ Found floor: \(floorName) at: \(floorURL.path)")
      }
    }
    
    return floors
  }
  
  // MARK: - MARS Initialization
  
  @MainActor func initializeMARS() {
    guard let appFolderURL = self.appFolderURL else {
      errorMessage = "App folder path not available"
      return
    }
    
    print("🔄 Initializing MARS with app folder URL: \(appFolderURL.path)")
    
    // Initialize MARS with our configuration handler
    marsPositionProvider = PositionProvider(
      data: appFolderURL,
      arSCNView: arView,
      worldMapConfigurationHandler: { [weak self] config in
        // This handler is called whenever MARS changes rooms
        // It preserves our artwork recognition configuration
        
        guard let self = self else { return }
        
        // Set the detection images if MARS cleared them
        if config.detectionImages == nil {
          config.detectionImages = self.artworkRecognizer.artworkImages
        } else {
          // Merge with existing images
          var combinedImages = config.detectionImages ?? Set<ARReferenceImage>()
          combinedImages = combinedImages.union(self.artworkRecognizer.artworkImages)
          config.detectionImages = combinedImages
        }
        
        // Configure other AR settings as needed
        config.planeDetection = [.horizontal, .vertical]
        config.maximumNumberOfTrackedImages = 10
        config.environmentTexturing = .automatic
      }
    )
    
    // Start MARS positioning
    marsPositionProvider?.start()
    
    // Subscribe to MARS room updates
    NotificationCenter.default.addObserver(
      forName: NSNotification.Name("MARSRoomChanged"),
      object: nil,
      queue: .main
    ) { [weak self] notification in
      if let roomName = notification.userInfo?["roomName"] as? String {
        self?.currentRoom = roomName
      }
    }
  }
  
  private func artworkRecognized(_ artworkName: String) {
    // Process the recognized artwork
    self.currentArtwork = artworkName
  }
  
  @MainActor func showMap() -> some View {
    if let provider = marsPositionProvider {
      return AnyView(provider.showMap())
    } else {
      return AnyView(Text("MARS not initialized").padding())
    }
  }
  
  // MARK: - Path Sharing Helper
  
  func getAppFolderPath() -> String {
      return appFolderURL?.path ?? "App folder not available"
  }
}
