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
    
    private func setupAR() {
        // Set up AR view
        arView.frame = view.bounds
        arView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(arView)
        
        // Set up delegate multiplexing
        arView.delegate = delegateMultiplexer
        
        // Initial AR configuration - only detect MARS markers first
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .automatic
        arView.session.run(configuration)
        
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
        
        // Listen for MARS notifications
        setupMARSNotifications()
        
        // Start MARS positioning
        marsPositionProvider?.start()
    }
    
    private func setupMARSNotifications() {
        // Monitor room changes
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("MARSRoomChanged"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            
            if let roomName = notification.userInfo?["roomName"] as? String {
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
        }
        
        // Handle coaching overlay
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("MARSTrackingStateChanged"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let state = notification.userInfo?["state"] as? String, state == "Normal" {
                // Post notification to hide coaching overlay
                NotificationCenter.default.post(
                    name: NSNotification.Name("MARSHideCoachingOverlay"),
                    object: nil
                )
            }
        }
    }
    
    // MARK: - Artwork Recognition
    
    func enableArtworkRecognition(for roomName: String) {
        // Only set up artwork recognition once positioned
        guard isPositioned else { return }
        
        // Prevent duplicates
        if selectedRoom == roomName && artworkRecognizer != nil {
            return
        }
        
        selectedRoom = roomName
        
        // Get artworks for the current room
        currentRoomArtworks = getArtworksForRoom(roomName)
        
        // Create artwork recognizer with room-specific artworks
        let recognizer = ArtworkRecognitionDelegate(artworkImages: currentRoomArtworks)
        
        // Add to delegate multiplexer
        delegateMultiplexer.addDelegate(recognizer)
        
        // Subscribe to artwork recognition events
        recognizer.recognitionPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] artworkName in
                guard let self = self else { return }
                
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
            return
        }
        
        // Add artwork images to existing configuration
        var updatedConfiguration = currentConfiguration
        
        if let existingImages = updatedConfiguration.detectionImages {
            updatedConfiguration.detectionImages = existingImages.union(artworkImages)
        } else {
            updatedConfiguration.detectionImages = artworkImages
        }
        
        updatedConfiguration.maximumNumberOfTrackedImages = 10
        
        // Update session with new configuration
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
