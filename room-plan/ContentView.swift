import SwiftUI
import RealityKit
import ARKit

class ViewModel: ObservableObject {
    @Published var isScanning = false
    @Published var errorMessage: String?
    @Published var debugInfo: String = "Initializing..."
    @Published var meshCount: Int = 0
    @Published var detectedFurniture: [FurnitureItem] = []

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
    
    func addDetectedFurniture(_ furniture: FurnitureItem) {
        DispatchQueue.main.async {
            if !self.detectedFurniture.contains(where: { $0.id == furniture.id }) {
                self.detectedFurniture.append(furniture)
                print("🪑 Detected furniture: \(furniture.type) at \(furniture.position)")
            }
        }
    }
}

struct FurnitureItem: Identifiable {
    let id = UUID()
    let type: String
    let position: SIMD3<Float>
    let dimensions: SIMD3<Float>
    let confidence: Float
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
                    
                    Text("Furniture: \(vm.detectedFurniture.count)")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(8)
                    
                    if !vm.detectedFurniture.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(vm.detectedFurniture) { furniture in
                                    VStack {
                                        Text(furniture.type)
                                            .font(.caption)
                                        Text("Conf: \(Int(furniture.confidence * 100))%")
                                            .font(.caption2)
                                    }
                                    .padding(8)
                                    .background(Color.green.opacity(0.8))
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
        
        // Enable mesh generation if available
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
            print("✅ Scene reconstruction with mesh enabled")
        } else {
            print("⚠️ Scene reconstruction with mesh not supported")
        }
        
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
    private let furnitureDetector = FurnitureDetector()
    
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
                
                // Analyze mesh for furniture
                analyzeMeshForFurniture(meshAnchor)
                
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
                
                // Re-analyze updated mesh
                analyzeMeshForFurniture(meshAnchor)
                
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
    
    private func analyzeMeshForFurniture(_ meshAnchor: ARMeshAnchor) {
        let furniture = furnitureDetector.detectFurniture(from: meshAnchor)
        if let furniture = furniture {
            viewModel.addDetectedFurniture(furniture)
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

// Furniture detection logic
class FurnitureDetector {
    
    func detectFurniture(from meshAnchor: ARMeshAnchor) -> FurnitureItem? {
        let vertices = meshAnchor.geometry.vertices
        let faces = meshAnchor.geometry.faces
        
        guard vertices.count > 10 else { return nil } // Too small to be furniture
        
        // Temporarily disable vertex analysis to avoid crashes
        // TODO: Re-enable when buffer access issues are resolved
        /*
        // Safely convert vertices to array
        let vertexArray = Array(UnsafeBufferPointer(
            start: vertices.buffer.contents().assumingMemoryBound(to: SIMD3<Float>.self),
            count: vertices.count
        ))
        
        // Calculate bounding box
        let minX = vertexArray.map { $0.x }.min() ?? 0
        let maxX = vertexArray.map { $0.x }.max() ?? 0
        let minY = vertexArray.map { $0.y }.min() ?? 0
        let maxY = vertexArray.map { $0.y }.max() ?? 0
        let minZ = vertexArray.map { $0.z }.min() ?? 0
        let maxZ = vertexArray.map { $0.z }.max() ?? 0
        
        let width = maxX - minX
        let height = maxY - minY
        let depth = maxZ - minZ
        
        let center = SIMD3<Float>((minX + maxX) / 2, (minY + maxY) / 2, (minZ + maxZ) / 2)
        let dimensions = SIMD3<Float>(width, height, depth)
        */
        
        // Use simplified detection based on vertex count and mesh anchor properties
        let vertexCount = vertices.count
        let faceCount = faces.count
        
        // Estimate dimensions based on vertex count and face count
        let estimatedVolume = Float(vertexCount) * 0.001 // Rough estimation
        let estimatedDimension = pow(estimatedVolume, 1.0/3.0) // Cube root for rough size
        
        let center = SIMD3<Float>(0, 0, 0) // Use origin as center
        let dimensions = SIMD3<Float>(estimatedDimension, estimatedDimension, estimatedDimension)
        
        // Analyze surface normals for horizontal vs vertical surfaces
        let normals = meshAnchor.geometry.normals
        var horizontalSurfaces = 0
        var verticalSurfaces = 0
        
        // Temporarily disable normal analysis to avoid crashes
        // TODO: Re-enable when buffer access issues are resolved
        /*
        if normals.count > 0 {
            // Use a safer approach with error handling
            do {
                let normalBuffer = normals.buffer
                if normalBuffer.length > 0 {
                    let normalArray = Array(UnsafeBufferPointer(
                        start: normalBuffer.contents().assumingMemoryBound(to: SIMD3<Float>.self),
                        count: normals.count
                    ))
                    
                    for normal in normalArray {
                        if abs(normal.y) > 0.8 { // Mostly vertical
                            verticalSurfaces += 1
                        } else if abs(normal.y) < 0.2 { // Mostly horizontal
                            horizontalSurfaces += 1
                        }
                    }
                }
            } catch {
                // If normal analysis fails, continue without it
                print("⚠️ Normal analysis failed, continuing without surface analysis")
            }
        }
        */
        
        // Classify based on dimensions and surface analysis
        let furnitureType = classifyFurniture(
            dimensions: dimensions,
            horizontalSurfaces: horizontalSurfaces,
            verticalSurfaces: verticalSurfaces,
            vertexCount: vertexCount
        )
        
        if let type = furnitureType {
            let confidence = calculateConfidence(
                dimensions: dimensions,
                horizontalSurfaces: horizontalSurfaces,
                verticalSurfaces: verticalSurfaces,
                vertexCount: vertexCount
            )
            
            return FurnitureItem(
                type: type,
                position: center,
                dimensions: dimensions,
                confidence: confidence
            )
        }
        
        return nil
    }
    
    private func classifyFurniture(
        dimensions: SIMD3<Float>,
        horizontalSurfaces: Int,
        verticalSurfaces: Int,
        vertexCount: Int
    ) -> String? {
        
        let width = dimensions.x
        let height = dimensions.y
        let depth = dimensions.z
        
        // Table detection
        if height > 0.4 && height < 1.2 && width > 0.3 && depth > 0.3 {
            if horizontalSurfaces > verticalSurfaces * 2 {
                return "Table"
            }
        }
        
        // Chair detection
        if height > 0.4 && height < 1.0 && width > 0.2 && width < 0.6 && depth > 0.2 && depth < 0.6 {
            if verticalSurfaces > horizontalSurfaces {
                return "Chair"
            }
        }
        
        // Bed detection
        if height > 0.2 && height < 0.8 && width > 0.8 && depth > 1.5 {
            return "Bed"
        }
        
        // Cabinet detection
        if height > 0.5 && width > 0.3 && depth > 0.3 && verticalSurfaces > horizontalSurfaces * 2 {
            return "Cabinet"
        }
        
        // Generic furniture for anything that meets basic criteria
        if height > 0.3 && width > 0.2 && depth > 0.2 && vertexCount > 20 {
            return "Furniture"
        }
        
        return nil
    }
    
    private func calculateConfidence(
        dimensions: SIMD3<Float>,
        horizontalSurfaces: Int,
        verticalSurfaces: Int,
        vertexCount: Int
    ) -> Float {
        var confidence: Float = 0.0
        
        // More vertices = higher confidence
        confidence += Swift.min(Float(vertexCount) / 100.0, 0.3)
        
        // Good surface ratio = higher confidence
        let totalSurfaces = horizontalSurfaces + verticalSurfaces
        if totalSurfaces > 0 {
            let surfaceRatio = Float(Swift.max(horizontalSurfaces, verticalSurfaces)) / Float(totalSurfaces)
            confidence += surfaceRatio * 0.4
        }
        
        // Reasonable dimensions = higher confidence
        let volume = dimensions.x * dimensions.y * dimensions.z
        if volume > 0.01 && volume < 10.0 { // 10cm³ to 10m³
            confidence += 0.3
        }
        
        return min(confidence, 1.0)
    }
}
