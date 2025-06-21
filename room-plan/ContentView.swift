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
    }

    func stop() {
        isScanning = false
        debugInfo = "Stopped"
    }
    
    func setError(_ error: String) {
        DispatchQueue.main.async {
            self.errorMessage = error
            self.debugInfo = "Error: \(error)"
        }
    }
    
    func setDebugInfo(_ info: String) {
        DispatchQueue.main.async {
            self.debugInfo = info
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
        
        context.coordinator.setARView(arView)
        
        // Configure AR session for mesh generation
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .automatic
        
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
        }
        
        arView.session.run(configuration)
        
        // Re-enable default mesh visualization to compare with our custom one
        arView.debugOptions = [.showSceneUnderstanding]
        
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        // Leave empty to avoid unnecessary updates
    }
}

// AR Coordinator for manual mesh visualization
class ARMeshCoordinator: NSObject, ARSessionDelegate {
    @ObservedObject var viewModel: ViewModel
    private weak var arView: ARView?
    // Store the AnchorEntity to properly remove it from the scene later
    private var meshEntities: [UUID: AnchorEntity] = [:]

    init(viewModel: ViewModel) {
        self.viewModel = viewModel
        super.init()
    }
    
    func setARView(_ arView: ARView) {
        self.arView = arView
    }
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for anchor in anchors {
            if let meshAnchor = anchor as? ARMeshAnchor {
                updateMesh(anchor: meshAnchor)
            }
        }
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors {
            if let meshAnchor = anchor as? ARMeshAnchor {
                updateMesh(anchor: meshAnchor)
            }
        }
    }
    
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        for anchor in anchors {
            if let meshAnchor = anchor as? ARMeshAnchor, let existingAnchor = meshEntities[meshAnchor.identifier] {
                arView?.scene.removeAnchor(existingAnchor)
                meshEntities.removeValue(forKey: meshAnchor.identifier)
            }
        }
    }

    private func updateMesh(anchor: ARMeshAnchor) {
        // All scene updates must be performed on the main thread.
        DispatchQueue.main.async {
            guard let arView = self.arView else { return }

            // Remove old anchor entity if it exists
            if let existingAnchor = self.meshEntities[anchor.identifier] {
                arView.scene.removeAnchor(existingAnchor)
            }

            do {
                // 1. Create a MeshDescriptor from the ARMeshGeometry
                var descriptor = MeshDescriptor(name: "custom")
                let positions = anchor.geometry.vertices.asSIMD3(ofType: SIMD3<Float>.self)
                descriptor.positions = MeshBuffers.Positions(positions)
                let indices = anchor.geometry.faces.asUInt32()
                descriptor.primitives = .triangles(indices)

                // 2. Create a MeshResource from the descriptor
                let meshResource = try MeshResource.generate(from: [descriptor])

                // 3. Create a solid red material to compare with the default mesh
                var material = SimpleMaterial()
                material.baseColor = .color(.red)
                
                // 4. Create a ModelEntity and scale it down slightly
                let modelEntity = ModelEntity(mesh: meshResource, materials: [material])
                modelEntity.scale *= 0.99 // Make it slightly smaller to see inside default mesh
                
                // 5. Create a new AnchorEntity to hold the model
                let anchorEntity = AnchorEntity(world: anchor.transform)
                anchorEntity.addChild(modelEntity)
                arView.scene.addAnchor(anchorEntity)

                // 6. Store the new anchor entity
                self.meshEntities[anchor.identifier] = anchorEntity
                
            } catch {
                print("❌ Error creating mesh for anchor \(anchor.identifier): \(error)")
            }
        }
    }
}

// Helper extensions to convert buffer data
extension ARGeometrySource {
    func asSIMD3<T: SIMD3Initializable>(ofType: T.Type) -> [T] {
        let buffer = self.buffer.contents().assumingMemoryBound(to: T.self)
        let bufferPointer = UnsafeBufferPointer(start: buffer, count: self.count)
        return Array(bufferPointer)
    }
}

protocol SIMD3Initializable {
    init(_: SIMD3<Float>)
}
extension SIMD3: SIMD3Initializable where Scalar == Float {
    init(_ val: SIMD3<Float>) {
        self = val
    }
}

extension ARGeometryElement {
    func asUInt32() -> [UInt32] {
        let count = self.count * self.indexCountPerPrimitive
        let buffer = self.buffer

        // ARKit can provide indices in 16-bit or 32-bit format.
        // We need to handle both and convert to the UInt32 format
        // required by MeshDescriptor.
        if self.bytesPerIndex == 4 {
            let pointer = buffer.contents().assumingMemoryBound(to: UInt32.self)
            let bufferPointer = UnsafeBufferPointer(start: pointer, count: count)
            return Array(bufferPointer)
        } else if self.bytesPerIndex == 2 {
            let pointer = buffer.contents().assumingMemoryBound(to: UInt16.self)
            let bufferPointer = UnsafeBufferPointer(start: pointer, count: count)
            return bufferPointer.map { UInt32($0) }
        } else {
            // This case should not be reached for triangle meshes from ARKit.
            return []
        }
    }
}
