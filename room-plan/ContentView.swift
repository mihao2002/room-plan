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
                                        Text("Size: \(String(format: "%.1fx%.1fx%.1f", furniture.dimensions.x, furniture.dimensions.y, furniture.dimensions.z))m")
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
        // Leave empty to avoid unnecessary updates
    }
}

// AR Coordinator with colored mesh visualization
class ARMeshCoordinator: NSObject, ARSessionDelegate {
    @ObservedObject var viewModel: ViewModel
    private var meshAnchors: [ARMeshAnchor] = []
    private let furnitureDetector = FurnitureDetector()
    private var coloredMeshEntities: [UUID: AnchorEntity] = [:] // Track colored meshes by furniture ID
    private weak var arView: ARView?
    
    private let furnitureColors: [String: UIColor] = [
        "Table": .systemRed, "Chair": .systemBlue, "Bed": .systemGreen,
        "Cabinet": .systemPurple, "Furniture": .systemOrange
    ]

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
                meshAnchors.append(meshAnchor)
                analyzeMeshForFurniture(meshAnchor)
                DispatchQueue.main.async { self.viewModel.updateMeshCount(self.meshAnchors.count) }
            }
        }
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors {
            if let meshAnchor = anchor as? ARMeshAnchor {
                analyzeMeshForFurniture(meshAnchor)
            }
        }
    }
    
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        for anchor in anchors {
            if let meshAnchor = anchor as? ARMeshAnchor {
                meshAnchors.removeAll { $0.identifier == meshAnchor.identifier }
            }
        }
    }
    
    private func analyzeMeshForFurniture(_ meshAnchor: ARMeshAnchor) {
        guard let furniture = furnitureDetector.detectFurniture(from: meshAnchor) else { return }
        
        let isDuplicate = viewModel.detectedFurniture.contains {
            distance($0.position, furniture.position) < 0.5 // 50cm threshold
        }
        
        if !isDuplicate {
            DispatchQueue.main.async {
                if self.viewModel.detectedFurniture.count >= 10 {
                    self.clearAllFurniture()
                }
                self.viewModel.addDetectedFurniture(furniture)
                self.createColoredMesh(for: furniture)
            }
        }
    }
    
    private func createColoredMesh(for furniture: FurnitureItem) {
        guard let arView = arView else { return }

        // Comprehensive safety check for all floating-point values
        guard furniture.position.x.isFinite && furniture.position.y.isFinite && furniture.position.z.isFinite &&
              furniture.dimensions.x.isFinite && furniture.dimensions.y.isFinite && furniture.dimensions.z.isFinite else {
            print("❌ Invalid float value in furniture data. Pos: \(furniture.position), Dim: \(furniture.dimensions)")
            return
        }

        let avgDimension = (furniture.dimensions.x + furniture.dimensions.y + furniture.dimensions.z) / 3.0
        let radius = avgDimension / 2.0

        guard radius > 0.05 && radius.isFinite else {
            print("❌ Invalid radius: \(radius)")
            return
        }
        
        do {
            let color = furnitureColors[furniture.type] ?? .systemGray

            // Create sphere
            let sphereMesh = try MeshResource.generateSphere(radius: radius)
            var sphereMaterial = SimpleMaterial()
            sphereMaterial.baseColor = .color(color.withAlphaComponent(0.4))
            sphereMaterial.metallic = .float(0.5)
            sphereMaterial.roughness = .float(0.5)
            let sphereEntity = ModelEntity(mesh: sphereMesh, materials: [sphereMaterial])

            // Create text
            let textMesh = try MeshResource.generateText(furniture.type, extrusionDepth: 0.01, font: .systemFont(ofSize: 0.1))
            var textMaterial = SimpleMaterial()
            textMaterial.baseColor = .color(.white)
            let textEntity = ModelEntity(mesh: textMesh, materials: [textMaterial])
            let textSize = textEntity.visualBounds(relativeTo: nil).extents
            textEntity.position.x = -textSize.x / 2
            textEntity.position.y = radius + 0.1

            // Create anchor and add entities
            let anchorEntity = AnchorEntity(world: furniture.position)
            anchorEntity.addChild(sphereEntity)
            anchorEntity.addChild(textEntity)
            
            arView.scene.addAnchor(anchorEntity)
            coloredMeshEntities[furniture.id] = anchorEntity

        } catch {
            print("❌ Error creating mesh for furniture: \(error)")
        }
    }
    
    private func clearAllFurniture() {
        viewModel.detectedFurniture.removeAll()
        for anchor in coloredMeshEntities.values {
            arView?.scene.removeAnchor(anchor)
        }
        coloredMeshEntities.removeAll()
    }
}

// Furniture detection logic
class FurnitureDetector {
    func detectFurniture(from meshAnchor: ARMeshAnchor) -> FurnitureItem? {
        let vertices = meshAnchor.geometry.vertices
        let faces = meshAnchor.geometry.faces

        guard vertices.count > 100, faces.count > 50 else { return nil }
        guard vertices.buffer.length > 0 else { return nil }

        let vertexPointer = vertices.buffer.contents().assumingMemoryBound(to: SIMD3<Float>.self)
        let vertexBuffer = UnsafeBufferPointer(start: vertexPointer, count: vertices.count)

        guard let firstVertex = vertexBuffer.first else { return nil }
        var minVec = firstVertex
        var maxVec = firstVertex

        for vertex in vertexBuffer.dropFirst() {
            minVec = min(minVec, vertex)
            maxVec = max(maxVec, vertex)
        }

        let dimensions = maxVec - minVec
        let localCenter = (minVec + maxVec) / 2.0
        let worldCenter = (meshAnchor.transform * SIMD4<Float>(localCenter, 1)).xyz

        guard dimensions.x > 0.3 && dimensions.y > 0.3 && dimensions.z > 0.1 else { return nil }
        guard dimensions.x < 3.0 && dimensions.y < 3.0 && dimensions.z < 3.0 else { return nil }

        let vertexCount = vertices.count
        let faceCount = faces.count
        var horizontalSurfaces = 0
        var verticalSurfaces = 0
        
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
                position: worldCenter,
                dimensions: dimensions,
                confidence: confidence,
                meshId: meshAnchor.identifier,
                vertexCount: vertexCount,
                faceCount: faceCount
            )
        }
        return nil
    }

    private func classifyFurniture(dimensions: SIMD3<Float>, horizontalSurfaces: Int, verticalSurfaces: Int, vertexCount: Int) -> String? {
        let (width, height, depth) = (dimensions.x, dimensions.y, dimensions.z)
        if height > 0.6 && height < 1.2 && width > 0.8 && depth > 0.8 { return "Table" }
        if height > 0.6 && height < 1.1 && width > 0.4 && width < 0.8 && depth > 0.4 && depth < 0.8 { return "Chair" }
        if height > 0.3 && height < 0.8 && width > 1.2 && depth > 1.8 { return "Bed" }
        if height > 0.8 && width > 0.6 && depth > 0.4 { return "Cabinet" }
        if height > 0.5 && width > 0.5 && depth > 0.5 && vertexCount > 200 { return "Furniture" }
        return nil
    }

    private func calculateConfidence(dimensions: SIMD3<Float>, horizontalSurfaces: Int, verticalSurfaces: Int, vertexCount: Int) -> Float {
        var confidence: Float = 0.0
        confidence += min(Float(vertexCount) / 1000.0, 0.5)
        let volume = dimensions.x * dimensions.y * dimensions.z
        if volume > 0.05 && volume < 10.0 {
            confidence += 0.5
        }
        return min(confidence, 1.0)
    }
}

extension SIMD4 {
    var xyz: SIMD3<Scalar> { return SIMD3<Scalar>(x, y, z) }
}
