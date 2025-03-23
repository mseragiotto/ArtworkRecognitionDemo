//
//  ARViewController.swift
//  ArtworkRecognitionDemo
//
//  Created by Matteo Seragiotto on 20/03/25.
//
import SwiftUI
import ARKit
import MARS
import Combine

class ARViewController: UIViewController {
    // AR Components
    let arView = ARSCNView()
    let delegateMultiplexer = ARSCNDelegateMultiplexer()
    
    // MARS components
    var marsPositionProvider: PositionProvider?
    private var roomCheckTimer: Timer?
    
    // Artwork Recognition components
    var artworkRecognizer: ArtworkRecognitionDelegate?
    private var selectedRoom: String?
    
    // State
    var currentRoomArtworks: [ArtworkReference] = []
    @Published var currentArtwork: String?
    @Published var currentRoom: String = "Not located"
    @Published var isPositioned: Bool = false
    @Published var isDebugModeActive = false
    
    // Debug view
    private var debugViewController: UIViewController?
    
    // Callback for events
    var onArtworkDetected: ((String) -> Void)?
    var onRoomDetected: ((String) -> Void)?
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupAR()
    }
    
    deinit {
        roomCheckTimer?.invalidate()
    }
    
    private func setupAR() {
        print("🔧 Setting up AR view")
        
        // Set up AR view
        arView.frame = view.bounds
        arView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(arView)
        
        // Create instruction label
        let instructionLabel = UILabel()
        instructionLabel.text = "Point camera at a room marker to locate yourself"
        instructionLabel.textAlignment = .center
        instructionLabel.textColor = .white
        instructionLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        instructionLabel.layer.cornerRadius = 10
        instructionLabel.clipsToBounds = true
        instructionLabel.numberOfLines = 0
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(instructionLabel)
        NSLayoutConstraint.activate([
            instructionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            instructionLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            instructionLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            instructionLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),
            instructionLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 50)
        ])
        
        self.instructionLabel = instructionLabel
        
        // Important: DO NOT set up ARKit session here
        // Let MARS handle the ARKit session to avoid conflicts
    }
    
    private var instructionLabel: UILabel?
    
    // MARK: - MARS Integration
    
    func initializeMARS(appFolderURL: URL) {
        print("🔄 Initializing MARS with app folder URL: \(appFolderURL.path)")
        
        // Initialize MARS with the app folder URL
        marsPositionProvider = PositionProvider(
            data: appFolderURL,
            arSCNView: arView,
            worldMapConfigurationHandler: { [weak self] config in
                guard let self = self else { return }
                print("📝 MARS worldMapConfigurationHandler called")
                
                // Keep artwork recognition images if they are set
                if let artworkRecognizer = self.artworkRecognizer,
                   !artworkRecognizer.artworkImages.isEmpty {
                    
                    if config.detectionImages == nil {
                        config.detectionImages = artworkRecognizer.artworkImages
                    } else {
                        var combinedImages = config.detectionImages ?? Set<ARReferenceImage>()
                        combinedImages = combinedImages.union(artworkRecognizer.artworkImages)
                        config.detectionImages = combinedImages
                    }
                }
                
                config.planeDetection = [.horizontal, .vertical]
                config.maximumNumberOfTrackedImages = 10
                config.environmentTexturing = .automatic
            }
        )
        
        // Set up delegate AFTER creating position provider
        arView.delegate = delegateMultiplexer
        
        // Add MARS delegate to multiplexer
        if let marsDelegate = marsPositionProvider?.delegate {
            print("✅ Adding MARS delegate to multiplexer")
            delegateMultiplexer.addDelegate(marsDelegate)
        }
        
        // Log the building and marker information
        if let provider = marsPositionProvider {
            print("\n🏢 Building information:")
            print("   - Name: \(provider.building.name)")
            print("   - Floors: \(provider.building.floors.count)")
            
            print("\n🖼️ Reference markers in building:")
            let detectionImages = provider.building.detectionImages
            print("   - Total detection images: \(detectionImages.count)")
            
            for image in detectionImages {
                print("   - \(image.name ?? "Unnamed") (size: \(image.physicalSize.width)m × \(image.physicalSize.height)m)")
            }
            print("\n")
        }
        
        // Setup timer to periodically check for room changes
        setupRoomChangeMonitoring()
        
        // Listen for MARS notifications
        setupMARSNotifications()
        
        // Start MARS positioning
        print("▶️ Starting MARS positioning")
        marsPositionProvider?.start()
    }
    
    private func setupRoomChangeMonitoring() {
        print("⏱️ Setting up room change monitoring timer")
        
        // Create a timer to check for room changes directly from the MARS provider
        roomCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let provider = self.marsPositionProvider else { return }
            
            // Get the current room name from MARS
            let roomName = provider.activeRoom.name
            
            // If it's a valid room and different from our current room, handle it
            if !roomName.isEmpty && roomName != "Not located" && self.currentRoom != roomName {
                print("🏠 Room detected from polling: \(roomName)")
                self.handleRoomDetected(roomName)
            }
        }
    }
    
    private func setupMARSNotifications() {
        print("🔔 Setting up MARS notifications")
        
        // Monitor room changes
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("MARSRoomChanged"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            print("📣 Received MARSRoomChanged notification")
            
            if let roomName = notification.userInfo?["roomName"] as? String {
                print("🏠 Room detected from notification: \(roomName)")
                self.handleRoomDetected(roomName)
            }
        }
        
        // Handle tracking state changes
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("MARSTrackingStateChanged"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            print("📣 Received MARSTrackingStateChanged notification")
            if let state = notification.userInfo?["state"] as? String {
                print("   - State: \(state)")
            }
        }
    }
    
    private func handleRoomDetected(_ roomName: String) {
        // Don't process empty or "Not located" rooms
        if roomName.isEmpty || roomName == "Not located" {
            return
        }
        
        print("🏠 Handling room detection for: \(roomName)")
        
        // Update current room and notify
        self.currentRoom = roomName
        self.onRoomDetected?(roomName)
        
        // Room detected, now we can enable artwork recognition
        if !self.isPositioned {
            self.isPositioned = true
            self.enableArtworkRecognition(for: roomName)
            
            // Update instruction label
            DispatchQueue.main.async {
                self.instructionLabel?.text = "Position established! Now you can scan artworks."
                
                // Hide label after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    UIView.animate(withDuration: 0.5) {
                        self.instructionLabel?.alpha = 0
                    }
                }
            }
        }
    }
    
    // MARK: - Artwork Recognition
    
    func enableArtworkRecognition(for roomName: String) {
        // Only set up artwork recognition once positioned
        guard isPositioned else {
            print("⚠️ Cannot enable artwork recognition - not positioned yet")
            return
        }
        
        // Prevent duplicates
        if selectedRoom == roomName && artworkRecognizer != nil {
            print("ℹ️ Artwork recognition already enabled for room: \(roomName)")
            return
        }
        
        print("🎨 Enabling artwork recognition for room: \(roomName)")
        selectedRoom = roomName
        
        // Get artworks for the current room
        currentRoomArtworks = getArtworksForRoom(roomName)
        print("🖼️ Found \(currentRoomArtworks.count) artworks for room: \(roomName)")
        
        // Create artwork recognizer with room-specific artworks
        let recognizer = ArtworkRecognitionDelegate(artworkImages: currentRoomArtworks)
        
        // Add to delegate multiplexer
        print("➕ Adding artwork recognizer to delegate multiplexer")
        delegateMultiplexer.addDelegate(recognizer)
        
        // Subscribe to artwork recognition events
        recognizer.recognitionPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] artworkName in
                guard let self = self else { return }
                
                print("🖼️ Artwork recognized: \(artworkName)")
                self.currentArtwork = artworkName
                self.onArtworkDetected?(artworkName)
            }
            .store(in: &cancellables)
        
        // Store the recognizer
        self.artworkRecognizer = recognizer
        
        // Update AR configuration to include artwork images
        updateARConfigurationWithArtworks(recognizer.artworkImages)
    }
    
    private func updateARConfigurationWithArtworks(_ artworkImages: Set<ARReferenceImage>) {
        guard let currentConfiguration = arView.session.configuration as? ARWorldTrackingConfiguration else {
            print("⚠️ Cannot update AR configuration - no current configuration")
            return
        }
        
        print("🔄 Updating AR configuration with artwork images")
        
        // Add artwork images to existing configuration
        var updatedConfiguration = currentConfiguration
        
        if let existingImages = updatedConfiguration.detectionImages {
            print("ℹ️ Existing detection images: \(existingImages.count)")
            updatedConfiguration.detectionImages = existingImages.union(artworkImages)
        } else {
            print("ℹ️ No existing detection images")
            updatedConfiguration.detectionImages = artworkImages
        }
        
        print("ℹ️ Updated detection images: \(updatedConfiguration.detectionImages?.count ?? 0)")
        updatedConfiguration.maximumNumberOfTrackedImages = 10
        
        // Update session with new configuration
        print("▶️ Running updated AR session configuration")
        arView.session.run(updatedConfiguration, options: [])
    }
    
    // Mock database of artworks by room
    private func getArtworksForRoom(_ roomName: String) -> [ArtworkReference] {
        // In a real app, this would come from a database or API
        switch roomName {
        case "Camera di sotto", "camera di sotto":
            return [
                ArtworkReference(
                    name: "Mona Lisa",
                    image: UIImage(named: "mona_lisa") ?? UIImage(),
                    physicalWidth: 0.53,
                    description: "Painted by Leonardo da Vinci between 1503 and 1506, the Mona Lisa is one of the most famous paintings in the world."
                )
            ]
        case "Salotto", "salotto":
            return [
                ArtworkReference(
                    name: "Starry Night",
                    image: UIImage(named: "starry_night") ?? UIImage(),
                    physicalWidth: 0.74,
                    description: "Painted by Vincent van Gogh in 1889, The Starry Night depicts the view from his asylum room window."
                )
            ]
        default:
            // Default artworks for testing
            return [
                ArtworkReference(
                    name: "Mona Lisa",
                    image: UIImage(named: "mona_lisa") ?? UIImage(),
                    physicalWidth: 0.53,
                    description: "Painted by Leonardo da Vinci between 1503 and 1506, the Mona Lisa is one of the most famous paintings in the world."
                ),
                ArtworkReference(
                    name: "Starry Night",
                    image: UIImage(named: "starry_night") ?? UIImage(),
                    physicalWidth: 0.74,
                    description: "Painted by Vincent van Gogh in 1889, The Starry Night depicts the view from his asylum room window."
                )
            ]
        }
    }
    
    // MARK: - Debug Mode
    
    func toggleDebugMode() {
        isDebugModeActive.toggle()
        
        if isDebugModeActive {
            showDebugView()
        } else {
            hideDebugView()
        }
    }
    
    private func showDebugView() {
        guard let provider = marsPositionProvider else { return }
        
        // Get MARS map view
        let marsMapView = provider.showMap()
        
        // Create hosting controller
        let hostingController = UIHostingController(rootView: marsMapView)
        hostingController.view.backgroundColor = .clear
        
        // Add as child view controller
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.frame = view.bounds
        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hostingController.didMove(toParent: self)
        
        // Store reference for removal later
        debugViewController = hostingController
    }
    
    private func hideDebugView() {
        // Remove debug view if it exists
        debugViewController?.willMove(toParent: nil)
        debugViewController?.view.removeFromSuperview()
        debugViewController?.removeFromParent()
        debugViewController = nil
    }
    
    // MARK: - Cleanup
    
    func resetState() {
        // Clear artwork recognition
        currentArtwork = nil
        
        // Reset position flag
        isPositioned = false
        
        // Hide debug view if active
        if isDebugModeActive {
            hideDebugView()
            isDebugModeActive = false
        }
    }
}
