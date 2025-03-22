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
    var artworkRecognizer: ArtworkRecognitionDelegate
    
    // State
    private var cancellables = Set<AnyCancellable>()
    var currentArtwork: String? = nil
    var currentRoom: String = "Not located"
    var isDebugMode = false
    
    // Callback for artwork detection
    var onArtworkDetected: ((String) -> Void)?
    
    init(artworkRecognizer: ArtworkRecognitionDelegate) {
        self.artworkRecognizer = artworkRecognizer
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
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
        delegateMultiplexer.addDelegate(artworkRecognizer)
        arView.delegate = delegateMultiplexer
        
        // Initial AR configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.detectionImages = artworkRecognizer.artworkImages
        configuration.maximumNumberOfTrackedImages = 10
        arView.session.run(configuration)
        
        // Subscribe to artwork recognition events
        artworkRecognizer.recognitionPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] artworkName in
                self?.currentArtwork = artworkName
                self?.onArtworkDetected?(artworkName)
            }
            .store(in: &cancellables)
    }
    
    func initializeMARS(appFolderURL: URL) {
        print("🔄 Initializing MARS with app folder URL: \(appFolderURL.path)")
        
        // Initialize MARS with the app folder URL
        marsPositionProvider = PositionProvider(
            data: appFolderURL,
            arSCNView: arView,
            worldMapConfigurationHandler: { [weak self] config in
                guard let self = self else { return }
                
                // Keep artwork recognition images when MARS changes rooms
                if config.detectionImages == nil {
                    config.detectionImages = self.artworkRecognizer.artworkImages
                } else {
                    var combinedImages = config.detectionImages ?? Set<ARReferenceImage>()
                    combinedImages = combinedImages.union(self.artworkRecognizer.artworkImages)
                    config.detectionImages = combinedImages
                }
                
                config.planeDetection = [.horizontal, .vertical]
                config.maximumNumberOfTrackedImages = 10
                config.environmentTexturing = .automatic
            }
        )
        
        // Fix for coaching overlay persistence
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("MARSTrackingStateChanged"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let state = notification.userInfo?["state"] as? String, state == "Normal" {
                // Hide coaching overlay when tracking state is normal
                if let marsProvider = self?.marsPositionProvider,
                   let marsContainer = marsProvider.arSCNView as? ARSCNViewContainer,
                   let sessionManager = marsContainer.getSessionManager() {
                    
                    sessionManager.coachingOverlay.setActive(false, animated: true)
                }
            }
        }
        
        // Start MARS positioning
        marsPositionProvider?.start()
    }
    
    func toggleDebugMode() {
        isDebugMode = !isDebugMode
        
        if isDebugMode {
            // Show MARS debug view
            if let provider = marsPositionProvider {
                let marsMapView = provider.showMap()
                let hostingController = UIHostingController(rootView: marsMapView)
                hostingController.view.backgroundColor = .clear
                
                addChild(hostingController)
                view.addSubview(hostingController.view)
                hostingController.view.frame = view.bounds
                hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                hostingController.didMove(toParent: self)
                
                // Store the hosting controller for removal later
                self.marsDebugController = hostingController
            }
        } else {
            // Remove MARS debug view
            marsDebugController?.willMove(toParent: nil)
            marsDebugController?.view.removeFromSuperview()
            marsDebugController?.removeFromParent()
            marsDebugController = nil
        }
    }
    
    private var marsDebugController: UIHostingController<AnyView>?
}
