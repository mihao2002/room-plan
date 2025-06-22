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
            // AR view with mesh visualization
            ARMeshView(viewModel: vm)
                .ignoresSafeArea()

            // Debug overlay
            VStack {
                HStack {
                    Text("Mesh Wireframe Debug")
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
        
        // Disable default mesh visualization to see only our custom wireframes
        arView.debugOptions = []
        
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        // Leave empty to avoid unnecessary updates
    }
}

// AR Coordinator for mesh wireframe visualization
class ARMeshCoordinator: NSObject, ARSessionDelegate {
    @ObservedObject var viewModel: ViewModel
    private weak var arView: ARView?
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
                // Create wireframe geometry from the mesh
                let wireframeMesh = self.createWireframeMesh(from: anchor.geometry)
                
                // Create a wireframe material
                var material = SimpleMaterial()
                material.baseColor = .color(.cyan)
                
                // Create a ModelEntity
                let modelEntity = ModelEntity(mesh: wireframeMesh, materials: [material])
                
                // Create a new AnchorEntity to hold the model
                let anchorEntity = AnchorEntity(world: anchor.transform)
                anchorEntity.addChild(modelEntity)
                arView.scene.addAnchor(anchorEntity)

                // Store the new anchor entity
                self.meshEntities[anchor.identifier] = anchorEntity
                
                // Update mesh count
                self.viewModel.updateMeshCount(self.meshEntities.count)
                
            } catch {
                print("❌ Error creating mesh for anchor \(anchor.identifier): \(error)")
                self.viewModel.setError("Mesh creation failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func createWireframeMesh(from geometry: ARMeshGeometry) -> MeshResource {
        let vertices = geometry.vertices.asSIMD3(ofType: SIMD3<Float>.self)
        let indices = geometry.faces.asUInt32()
        
        // Create thin triangles that look like wireframes
        var wireframeVertices: [SIMD3<Float>] = []
        var wireframeIndices: [UInt32] = []
        
        // Process triangles in groups of 3 indices
        for i in stride(from: 0, to: indices.count, by: 3) {
            guard i + 2 < indices.count else { break }
            
            let v0 = vertices[Int(indices[i])]
            let v1 = vertices[Int(indices[i + 1])]
            let v2 = vertices[Int(indices[i + 2])]
            
            // Calculate triangle normal for offsetting
            let edge1 = v1 - v0
            let edge2 = v2 - v0
            let normal = normalize(cross(edge1, edge2))
            
            // Create thin triangles by offsetting vertices slightly
            let offset: Float = 0.001 // 1mm offset
            let v0Offset = v0 + normal * offset
            let v1Offset = v1 + normal * offset
            let v2Offset = v2 + normal * offset
            
            // Add both front and back faces for visibility
            let baseIndex = UInt32(wireframeVertices.count)
            
            // Front face
            wireframeVertices.append(contentsOf: [v0Offset, v1Offset, v2Offset])
            wireframeIndices.append(contentsOf: [baseIndex, baseIndex + 1, baseIndex + 2])
            
            // Back face (flipped)
            wireframeVertices.append(contentsOf: [v0Offset, v2Offset, v1Offset])
            wireframeIndices.append(contentsOf: [baseIndex + 3, baseIndex + 4, baseIndex + 5])
        }
        
        // Create mesh descriptor for wireframe
        var descriptor = MeshDescriptor(name: "wireframe")
        descriptor.positions = MeshBuffers.Positions(wireframeVertices)
        descriptor.primitives = .triangles(wireframeIndices)
        
        return try MeshResource.generate(from: [descriptor])
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

// Math helper functions
func normalize(_ vector: SIMD3<Float>) -> SIMD3<Float> {
    let length = sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
    guard length > 0 else { return SIMD3<Float>(0, 0, 0) }
    return vector / length
}

func cross(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> SIMD3<Float> {
    return SIMD3<Float>(
        a.y * b.z - a.z * b.y,
        a.z * b.x - a.x * b.z,
        a.x * b.y - a.y * b.x
    )
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
