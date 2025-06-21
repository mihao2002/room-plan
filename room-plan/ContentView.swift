import SwiftUI
import RealityKit
import ARKit

class ViewModel: ObservableObject {
    @Published var isScanning = false
    @Published var errorMessage: String?
    @Published var debugInfo: String = "Initializing..."
    @Published var meshCount: Int = 0

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
    
    func updateMeshCount(_ count: Int) {
        DispatchQueue.main.async {
            self.meshCount = count
        }
    }
}

struct ContentView: View {
    @StateObject var vm = ViewModel()

    var body: some View {
        ZStack {
            // AR view with camera feed and mesh visualization
            ARMeshView(viewModel: vm)
                .ignoresSafeArea()

            // Debug overlay
            VStack {
                HStack {
                    Text("Custom Mesh Scanner")
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
                
                // Status and mesh info
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
                    
                    Text("Meshes: \(vm.meshCount)")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(8)
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

// AR view with mesh visualization
struct ARMeshView: UIViewRepresentable {
    @ObservedObject var viewModel: ViewModel

    func makeCoordinator() -> ARMeshCoordinator {
        ARMeshCoordinator(viewModel: viewModel)
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.session.delegate = context.coordinator
        
        // Configure AR session for mesh generation
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .automatic
        configuration.frameSemantics = .sceneReconstruction
        
        arView.session.run(configuration)
        
        // Enable mesh visualization
        arView.debugOptions = [.showSceneUnderstanding]
        
        print("🟢 ARMeshView created")
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        print("🔄 ARMeshView updated")
    }
}

class ARMeshCoordinator: NSObject, ARSessionDelegate {
    let viewModel: ViewModel
    private var meshAnchors: [ARMeshAnchor] = []
    
    init(viewModel: ViewModel) {
        self.viewModel = viewModel
        super.init()
        print("🟢 ARMeshCoordinator initialized")
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Update debug info
        DispatchQueue.main.async {
            self.viewModel.setDebugInfo("Camera frame updated")
        }
    }
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for anchor in anchors {
            if let meshAnchor = anchor as? ARMeshAnchor {
                meshAnchors.append(meshAnchor)
                print("📦 Mesh anchor added: \(meshAnchor.geometry.vertices.count) vertices")
                
                DispatchQueue.main.async {
                    self.viewModel.updateMeshCount(self.meshAnchors.count)
                    self.viewModel.setDebugInfo("Mesh detected: \(meshAnchor.geometry.vertices.count) vertices")
                }
            }
        }
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors {
            if let meshAnchor = anchor as? ARMeshAnchor {
                print("🔄 Mesh anchor updated: \(meshAnchor.geometry.vertices.count) vertices")
                
                DispatchQueue.main.async {
                    self.viewModel.setDebugInfo("Mesh updated: \(meshAnchor.geometry.vertices.count) vertices")
                }
            }
        }
    }
    
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        for anchor in anchors {
            if let meshAnchor = anchor as? ARMeshAnchor {
                meshAnchors.removeAll { $0.identifier == meshAnchor.identifier }
                print("🗑️ Mesh anchor removed")
                
                DispatchQueue.main.async {
                    self.viewModel.updateMeshCount(self.meshAnchors.count)
                    self.viewModel.setDebugInfo("Mesh removed")
                }
            }
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
}
