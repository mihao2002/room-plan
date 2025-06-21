import SwiftUI
import RealityKit
import ARKit

class ViewModel: ObservableObject {
    @Published var isScanning = false
    @Published var errorMessage: String?
    @Published var debugInfo: String = "Initializing..."
    @Published var meshCount: Int = 0
    @Published var detectedFurniture: [FurnitureItem] = []
    
    private var lastDetectionTime: Date = Date.distantPast
    private let detectionCooldown: TimeInterval = 2.0 // 2 seconds between detections

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
        let now = Date()
        guard now.timeIntervalSince(lastDetectionTime) > detectionCooldown else {
            print("⏰ Detection cooldown active, skipping...")
            return
        }
        
        DispatchQueue.main.async {
            if !self.detectedFurniture.contains(where: { $0.id == furniture.id }) {
                self.detectedFurniture.append(furniture)
                self.lastDetectionTime = now
                print("🪑 Detected furniture: \(furniture.type) at \(furniture.position)")
            }
        }
    }
    
    func clearDetectedFurniture() {
        DispatchQueue.main.async {
            self.detectedFurniture.removeAll()
            print("🗑️ Cleared all detected furniture")
        }
    }
}

struct FurnitureItem: Identifiable {
    let id = UUID()
    let type: String
    let position: SIMD3<Float>
    let dimensions: SIMD3<Float>
    let confidence: Float
    let meshId: UUID
    let vertexCount: Int
    let faceCount: Int
    let estimatedDimension: Float
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
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(furniture.type)
                                            .font(.caption)
                                            .fontWeight(.bold)
                                        Text("Conf: \(Int(furniture.confidence * 100))%")
                                            .font(.caption2)
                                        Text("Mesh: \(furniture.meshId.uuidString.prefix(8))")
                                            .font(.caption2)
                                            .foregroundColor(.yellow)
                                        Text("V: \(furniture.vertexCount), F: \(furniture.faceCount)")
                                            .font(.caption2)
                                            .foregroundColor(.cyan)
                                        Text("Size: \(String(format: "%.1f", furniture.estimatedDimension))m")
                                            .font(.caption2)
                                            .foregroundColor(.green)
                                    }
                                    .padding(8)
                                    .background(Color.black.opacity(0.8))
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
        
        // Pass ARView reference to coordinator
        context.coordinator.setARView(arView)
        
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
        
        // Disable default mesh visualization to see our colored furniture meshes
        arView.debugOptions = [] // Remove .showSceneUnderstanding
        
        print("🟢 ARMeshView created")
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        print("🔄 ARMeshView updated")
    }
}

// AR Coordinator with colored mesh visualization
class ARMeshCoordinator: NSObject, ARSessionDelegate {
    @ObservedObject var viewModel: ViewModel
    private var meshAnchors: [ARMeshAnchor] = []
    private let furnitureDetector = FurnitureDetector()
    private var coloredMeshEntities: [UUID: ModelEntity] = [:] // Track colored meshes by furniture ID
    private weak var arView: ARView? // Store ARView reference
    
    // Color mapping for furniture types
    private let furnitureColors: [String: UIColor] = [
        "Table": .systemRed,
        "Chair": .systemBlue,
        "Bed": .systemGreen,
        "Cabinet": .systemPurple,
        "Furniture": .systemOrange
    ]

    init(viewModel: ViewModel) {
        self.viewModel = viewModel
        super.init()
    }
    
    func setARView(_ arView: ARView) {
        self.arView = arView
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
                print("🆕 Mesh anchor added: \(meshAnchor.geometry.vertices.count) vertices")
                
                // Create a test mesh to verify rendering is working
                if meshAnchors.count == 1 {
                    createTestMesh()
                }
                
                // Analyze mesh for furniture
                analyzeMeshForFurniture(meshAnchor)
                
                DispatchQueue.main.async {
                    self.viewModel.updateMeshCount(self.meshAnchors.count)
                    self.viewModel.setDebugInfo("Mesh added: \(meshAnchor.geometry.vertices.count) vertices")
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
            // Check if this furniture is too close to existing ones to avoid duplicates
            let isDuplicate = viewModel.detectedFurniture.contains { existingFurniture in
                let distance = sqrt(
                    pow(existingFurniture.position.x - furniture.position.x, 2) +
                    pow(existingFurniture.position.y - furniture.position.y, 2) +
                    pow(existingFurniture.position.z - furniture.position.z, 2)
                )
                return distance < 0.5 // 50cm threshold for duplicates
            }
            
            if !isDuplicate {
                // Limit total furniture count to prevent excessive detections
                if viewModel.detectedFurniture.count < 10 {
                    viewModel.addDetectedFurniture(furniture)
                    // Create colored mesh for this furniture
                    createColoredMesh(for: furniture, meshAnchor: meshAnchor)
                } else {
                    // Clear old detections if we have too many
                    viewModel.clearDetectedFurniture()
                    clearColoredMeshes()
                    viewModel.addDetectedFurniture(furniture)
                    // Create colored mesh for this furniture
                    createColoredMesh(for: furniture, meshAnchor: meshAnchor)
                }
            }
        }
    }
    
    private func createColoredMesh(for furniture: FurnitureItem, meshAnchor: ARMeshAnchor) {
        guard let arView = getARView() else { 
            print("❌ ARView is nil, cannot create colored mesh")
            return 
        }
        
        print("🎨 Attempting to create colored mesh for \(furniture.type)")
        
        // Get color for furniture type
        let color = furnitureColors[furniture.type] ?? .systemGray
        
        // Create a larger, more visible wireframe box
        let mesh = MeshResource.generateBox(size: furniture.dimensions * 1.1) // Make slightly larger
        var material = SimpleMaterial()
        material.baseColor = MaterialColorParameter.color(color.withAlphaComponent(0.7)) // Add transparency
        material.metallic = MaterialScalarParameter(0.0)
        material.roughness = MaterialScalarParameter(0.3)
        
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.position = furniture.position
        
        // Add wireframe visualization
        let wireframeMesh = MeshResource.generateBox(size: furniture.dimensions * 1.1, cornerRadius: 0.02)
        var wireframeMaterial = SimpleMaterial()
        wireframeMaterial.baseColor = MaterialColorParameter.color(color)
        wireframeMaterial.metallic = MaterialScalarParameter(1.0)
        wireframeMaterial.roughness = MaterialScalarParameter(0.0)
        
        let wireframeEntity = ModelEntity(mesh: wireframeMesh, materials: [wireframeMaterial])
        wireframeEntity.position = furniture.position
        
        // Add text label
        let textMesh = MeshResource.generateText(furniture.type, extrusionDepth: 0.01, font: .systemFont(ofSize: 0.1))
        var textMaterial = SimpleMaterial()
        textMaterial.baseColor = MaterialColorParameter.color(.white)
        textMaterial.metallic = MaterialScalarParameter(0.0)
        textMaterial.roughness = MaterialScalarParameter(0.5)
        
        let textEntity = ModelEntity(mesh: textMesh, materials: [textMaterial])
        textEntity.position = furniture.position + SIMD3<Float>(0, furniture.dimensions.y * 0.6, 0) // Position above the furniture
        
        // Add to scene
        let anchorEntity = AnchorEntity()
        anchorEntity.addChild(entity)
        anchorEntity.addChild(wireframeEntity)
        anchorEntity.addChild(textEntity)
        arView.scene.addAnchor(anchorEntity)
        
        // Track the entity
        coloredMeshEntities[furniture.id] = entity
        
        print("✅ Successfully created colored mesh for \(furniture.type) at \(furniture.position)")
        print("   - Dimensions: \(furniture.dimensions)")
        print("   - Color: \(furniture.type)")
        print("   - Total entities in scene: \(arView.scene.anchors.count)")
    }
    
    private func clearColoredMeshes() {
        guard let arView = getARView() else { return }
        
        // Remove all colored mesh entities from scene
        for entity in coloredMeshEntities.values {
            entity.parent?.removeChild(entity)
        }
        coloredMeshEntities.removeAll()
        
        print("🗑️ Cleared all colored meshes")
    }
    
    private func getARView() -> ARView? {
        return arView
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
    
    private func createTestMesh() {
        guard let arView = getARView() else { 
            print("❌ ARView is nil, cannot create test mesh")
            return 
        }
        
        print("🧪 Creating test mesh...")
        
        // Create a simple red cube at the origin
        let testMesh = MeshResource.generateBox(size: SIMD3<Float>(0.5, 0.5, 0.5))
        var testMaterial = SimpleMaterial()
        testMaterial.baseColor = MaterialColorParameter.color(.systemRed)
        testMaterial.metallic = MaterialScalarParameter(0.0)
        testMaterial.roughness = MaterialScalarParameter(0.5)
        
        let testEntity = ModelEntity(mesh: testMesh, materials: [testMaterial])
        testEntity.position = SIMD3<Float>(0, 0, -1) // 1 meter in front of camera
        
        let testAnchor = AnchorEntity()
        testAnchor.addChild(testEntity)
        arView.scene.addAnchor(testAnchor)
        
        print("✅ Test mesh created at (0, 0, -1)")
        print("   - Total anchors in scene: \(arView.scene.anchors.count)")
    }
}

// Furniture detection logic
class FurnitureDetector {
    
    func detectFurniture(from meshAnchor: ARMeshAnchor) -> FurnitureItem? {
        let vertices = meshAnchor.geometry.vertices
        let faces = meshAnchor.geometry.faces
        
        // Much stricter minimum requirements
        guard vertices.count > 100 else { return nil } // Increased from 10 to 100
        guard faces.count > 50 else { return nil } // Added face count requirement
        
        // Use simplified detection based on vertex count and mesh anchor properties
        let vertexCount = vertices.count
        let faceCount = faces.count
        
        // Estimate dimensions based on vertex count and face count
        let estimatedVolume = Float(vertexCount) * 0.001 // Rough estimation
        let estimatedDimension = pow(estimatedVolume, 1.0/3.0) // Cube root for rough size
        
        // Much stricter size requirements
        guard estimatedDimension > 0.3 else { return nil } // Minimum 30cm
        guard estimatedDimension < 3.0 else { return nil } // Maximum 3m
        
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
                confidence: confidence,
                meshId: meshAnchor.identifier,
                vertexCount: vertexCount,
                faceCount: faceCount,
                estimatedDimension: estimatedDimension
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
        
        // Much stricter requirements for furniture detection
        
        // Table detection - must be substantial size
        if height > 0.6 && height < 1.2 && width > 0.8 && depth > 0.8 {
            if horizontalSurfaces > verticalSurfaces * 2 {
                return "Table"
            }
        }
        
        // Chair detection - must be chair-sized
        if height > 0.6 && height < 1.1 && width > 0.4 && width < 0.8 && depth > 0.4 && depth < 0.8 {
            if verticalSurfaces > horizontalSurfaces {
                return "Chair"
            }
        }
        
        // Bed detection - must be bed-sized
        if height > 0.3 && height < 0.8 && width > 1.2 && depth > 1.8 {
            return "Bed"
        }
        
        // Cabinet detection - must be substantial
        if height > 0.8 && width > 0.6 && depth > 0.4 && verticalSurfaces > horizontalSurfaces * 2 {
            return "Cabinet"
        }
        
        // Generic furniture - much stricter criteria
        if height > 0.5 && width > 0.5 && depth > 0.5 && vertexCount > 200 {
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
