import SwiftUI
import ARKit
import SceneKit
import ModelIO
import MetalKit

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
            // AR view with custom wireframe mesh visualization
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

// AR view with custom wireframe mesh visualization
struct ARMeshView: UIViewRepresentable {
    @ObservedObject var viewModel: ViewModel

    func makeCoordinator() -> ARMeshCoordinator {
        ARMeshCoordinator(viewModel: viewModel)
    }

    func makeUIView(context: Context) -> ARSCNView {
        let arView = ARSCNView(frame: .zero)
        arView.session.delegate = context.coordinator
        arView.delegate = context.coordinator
        
        context.coordinator.setARView(arView)
        
        // Configure AR session for mesh generation
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .automatic
        
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
        }
        
        arView.session.run(configuration)
        
        // Enable wireframe debug option
        arView.debugOptions = [.showWireframe]
        
        return arView
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {
        // Leave empty to avoid unnecessary updates
    }
}

// AR Coordinator for mesh wireframe visualization
class ARMeshCoordinator: NSObject, ARSessionDelegate, ARSCNViewDelegate {
    @ObservedObject var viewModel: ViewModel
    private weak var arView: ARSCNView?
    private var meshNodes: [UUID: SCNNode] = [:]
    private let device: MTLDevice? = MTLCreateSystemDefaultDevice()

    init(viewModel: ViewModel) {
        self.viewModel = viewModel
        super.init()
    }
    
    func setARView(_ arView: ARSCNView) {
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
            if let meshAnchor = anchor as? ARMeshAnchor, let existingNode = meshNodes[meshAnchor.identifier] {
                existingNode.removeFromParentNode()
                meshNodes.removeValue(forKey: meshAnchor.identifier)
            }
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        viewModel.setError(error.localizedDescription)
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        viewModel.setDebugInfo("AR Session interrupted")
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        viewModel.setDebugInfo("AR Session resumed")
    }

    private func updateMesh(anchor: ARMeshAnchor) {
        DispatchQueue.main.async {
            guard let arView = self.arView, let device = self.device else { return }

            // Remove old mesh node if it exists
            if let existingNode = self.meshNodes[anchor.identifier] {
                existingNode.removeFromParentNode()
            }

            // Convert ARMeshAnchor geometry to MDLMesh
            let mdlMesh = anchor.geometry.toMDLMesh(device: device)
            guard let scnGeometry = Self.scnGeometry(from: mdlMesh) else { return }
            let material = SCNMaterial()
            material.fillMode = .lines // Wireframe
            material.diffuse.contents = UIColor.cyan
            material.lightingModel = .constant
            scnGeometry.materials = [material]

            // Create node and apply anchor transform
            let meshNode = SCNNode(geometry: scnGeometry)
            meshNode.simdTransform = anchor.transform
            arView.scene.rootNode.addChildNode(meshNode)
            self.meshNodes[anchor.identifier] = meshNode

            // Update mesh count and debug info
            self.viewModel.updateMeshCount(self.meshNodes.count)
            let position = anchor.transform.columns.3
            self.viewModel.setDebugInfo("Mesh: \(anchor.geometry.vertices.count) vertices at (\(String(format: "%.2f", position.x)), \(String(format: "%.2f", position.y)), \(String(format: "%.2f", position.z)))")
        }
    }

    // Manual conversion from MDLMesh to SCNGeometry (iOS)
    static func scnGeometry(from mdlMesh: MDLMesh) -> SCNGeometry? {
        guard let vertexBuffer = mdlMesh.vertexBuffers.first else { return nil }
        let vertexCount = mdlMesh.vertexCount

        // Get position attribute
        guard let positionAttribute = mdlMesh.vertexDescriptor.attributes[0] as? MDLVertexAttribute,
              positionAttribute.format == .float3 else { return nil }

        let vertexStride = (mdlMesh.vertexDescriptor.layouts[0] as? MDLVertexBufferLayout)?.stride ?? MemoryLayout<Float>.size * 3

        let vertexSource = SCNGeometrySource(
            buffer: vertexBuffer.buffer,
            vertexFormat: .float3,
            semantic: .vertex,
            vertexCount: vertexCount,
            dataOffset: positionAttribute.offset,
            dataStride: vertexStride
        )

        // Get indices from the first submesh
        guard let submesh = mdlMesh.submeshes?.firstObject as? MDLSubmesh,
              let indexBuffer = submesh.indexBuffer else { return nil }

        let indexCount = submesh.indexCount
        let primitiveType: SCNGeometryPrimitiveType = .triangles
        let bytesPerIndex = submesh.indexType == .uInt32 ? 4 : 2

        let geometryElement = SCNGeometryElement(
            buffer: indexBuffer.buffer,
            primitiveType: primitiveType,
            primitiveCount: indexCount / 3,
            bytesPerIndex: bytesPerIndex
        )

        let geometry = SCNGeometry(sources: [vertexSource], elements: [geometryElement])
        return geometry
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
        // required by SCNGeometryElement.
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

extension ARMeshGeometry {
    func vertex(at index: UInt32) -> SIMD3<Float> {
        assert(vertices.format == MTLVertexFormat.float3, "Expected three floats (twelve bytes) per vertex.")
        let vertexPointer = vertices.buffer.contents().advanced(by: vertices.offset + (vertices.stride * Int(index)))
        let vertex = vertexPointer.assumingMemoryBound(to: SIMD3<Float>.self).pointee
        return vertex
    }
    func toMDLMesh(device: MTLDevice, camera: ARCamera, modelMatrix: simd_float4x4) -> MDLMesh {
        func convertVertexLocalToWorld() {
            let verticesPointer = vertices.buffer.contents()
            for vertexIndex in 0..<vertices.count {
                let vertex = self.vertex(at: UInt32(vertexIndex))
                var vertexLocalTransform = matrix_identity_float4x4
                vertexLocalTransform.columns.3 = SIMD4<Float>(x: vertex.x, y: vertex.y, z: vertex.z, w: 1)
                let vertexWorldPosition = (modelMatrix * vertexLocalTransform).columns.3
                let vertexOffset = vertices.offset + vertices.stride * vertexIndex
                let componentStride = vertices.stride / 3
                verticesPointer.storeBytes(of: vertexWorldPosition.x,
                                           toByteOffset: vertexOffset, as: Float.self)
                verticesPointer.storeBytes(of: vertexWorldPosition.y,
                                           toByteOffset: vertexOffset + componentStride, as: Float.self)
                verticesPointer.storeBytes(of: vertexWorldPosition.z,
                                           toByteOffset: vertexOffset + (2 * componentStride), as: Float.self)
            }
        }
        convertVertexLocalToWorld()
        let allocator = MTKMeshBufferAllocator(device: device)
        let data = Data.init(bytes: vertices.buffer.contents(),
                             count: vertices.stride * vertices.count)
        let vertexBuffer = allocator.newBuffer(with: data, type: .vertex)
        let indexData = Data.init(bytes: faces.buffer.contents(),
                                  count: faces.bytesPerIndex * faces.count * faces.indexCountPerPrimitive)
        let indexBuffer = allocator.newBuffer(with: indexData, type: .index)
        let submesh = MDLSubmesh(indexBuffer: indexBuffer,
                                 indexCount: faces.count * faces.indexCountPerPrimitive,
                                 indexType: .uInt32,
                                 geometryType: .triangles,
                                 material: nil)
        let vertexDescriptor = MDLVertexDescriptor()
        vertexDescriptor.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition,
                                                            format: .float3,
                                                            offset: 0,
                                                            bufferIndex: 0)
        vertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: vertices.stride)
        let mesh = MDLMesh(vertexBuffer: vertexBuffer,
                           vertexCount: vertices.count,
                           descriptor: vertexDescriptor,
                           submeshes: [submesh])
        return mesh
    }
}
