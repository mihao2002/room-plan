import SwiftUI
import RoomPlan
import RealityKit
import ARKit

class ViewModel: ObservableObject {
    @Published var detectedObjects: [CapturedRoom.Object] = []
    @Published var isScanning = false
    @Published var errorMessage: String?
    @Published var debugInfo: String = "Initializing..."

    func start() {
        isScanning = true
        errorMessage = nil
        debugInfo = "Starting AR session..."
        print("🟢 Starting AR session...")
    }

    func stop() {
        isScanning = false
        debugInfo = "Stopped"
        print("🔴 Stopping AR session...")
    }

    func updateDetectedObjects(_ objects: [CapturedRoom.Object]) {
        DispatchQueue.main.async {
            self.detectedObjects = objects
            self.debugInfo = "Detected \(objects.count) objects"
            print("✅ Detected \(objects.count) objects")
            
            // Print details of each detected object
            for (index, obj) in objects.enumerated() {
                print("📦 Object \(index + 1): \(obj.category) at position \(obj.transform.columns.3)")
            }
        }
    }
    
    func setError(_ error: String) {
        DispatchQueue.main.async {
            self.errorMessage = error
            self.debugInfo = "Error: \(error)"
            print("❌ Error: \(error)")
        }
    }
    
    func setDebugInfo(_ info: String) {
        DispatchQueue.main.async {
            self.debugInfo = info
            print("ℹ️ \(info)")
        }
    }
}

extension CapturedRoom.Object: Hashable {
    public static func == (lhs: CapturedRoom.Object, rhs: CapturedRoom.Object) -> Bool {
        lhs.transform.columns.3 == rhs.transform.columns.3 && lhs.category == rhs.category
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(category)
        hasher.combine(transform.columns.3.x)
        hasher.combine(transform.columns.3.y)
        hasher.combine(transform.columns.3.z)
    }
}

struct ContentView: View {
    @StateObject var vm = ViewModel()

    var body: some View {
        ZStack {
            // ARView for camera feed (always visible)
            ARCameraView(viewModel: vm)
                .ignoresSafeArea()

            // Debug overlay
            VStack {
                HStack {
                    Text("RoomPlan Scanner")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(8)
                    
                    Spacer()
                }
                .padding(.top, 50)
                
                Spacer()
                
                // Status and detected objects
                VStack(spacing: 10) {
                    Text("Debug: \(vm.debugInfo)")
                        .foregroundColor(.yellow)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(8)
                    
                    if let error = vm.errorMessage {
                        Text("Error: \(error)")
                            .foregroundColor(.red)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(8)
                    }
                    
                    Text("Status: \(vm.isScanning ? "Scanning" : "Stopped")")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(8)
                    
                    Text("Detected Objects: \(vm.detectedObjects.count)")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(8)
                    
                    if !vm.detectedObjects.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(Array(vm.detectedObjects.enumerated()), id: \.element) { index, obj in
                                    VStack {
                                        Text(String(describing: obj.category).capitalized)
                                            .font(.caption)
                                        Text("Obj \(index + 1)")
                                            .font(.caption2)
                                    }
                                    .padding(8)
                                    .background(Color.blue.opacity(0.8))
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            vm.start()
        }
        .onDisappear {
            vm.stop()
        }
    }
}

// ARView for camera feed
struct ARCameraView: UIViewRepresentable {
    @ObservedObject var viewModel: ViewModel

    func makeCoordinator() -> ARCameraCoordinator {
        ARCameraCoordinator(viewModel: viewModel)
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: UIScreen.main.bounds)
        arView.session.delegate = context.coordinator
        
        // Configure AR session for basic camera feed
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .automatic
        
        // Ensure the view is properly configured
        arView.isOpaque = true
        arView.backgroundColor = .systemRed // Temporary color to see if view is visible
        
        arView.session.run(configuration)
        
        print("🟢 ARView created for camera feed with frame: \(arView.frame)")
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        print("🔄 ARView updated with frame: \(uiView.frame)")
    }
}

class ARCameraCoordinator: NSObject, ARSessionDelegate {
    let viewModel: ViewModel
    private var roomCaptureView: RoomCaptureView?
    
    init(viewModel: ViewModel) {
        self.viewModel = viewModel
        super.init()
        print("🟢 ARCameraCoordinator initialized")
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // This confirms the camera is working
        DispatchQueue.main.async {
            self.viewModel.setDebugInfo("Camera frame updated")
        }
        
        // Start RoomPlan scanning if not already started
        if roomCaptureView == nil {
            startRoomPlanScanning()
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.viewModel.setError(error.localizedDescription)
        }
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        DispatchQueue.main.async {
            self.viewModel.setDebugInfo("AR Session interrupted")
        }
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        DispatchQueue.main.async {
            self.viewModel.setDebugInfo("AR Session resumed")
        }
    }
    
    private func startRoomPlanScanning() {
        guard roomCaptureView == nil else { return }
        
        DispatchQueue.main.async {
            // Create RoomCaptureView in background for scanning
            let roomView = RoomCaptureView()
            let coordinator = RoomScanCoordinator(viewModel: self.viewModel)
            roomView.delegate = coordinator
            
            // Keep a reference to prevent deallocation
            self.roomCaptureView = roomView
            
            self.viewModel.setDebugInfo("RoomPlan scanning started")
            print("🎥 RoomPlan scanning started")
        }
    }
}
