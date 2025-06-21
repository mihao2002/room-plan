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
        debugInfo = "Starting room scan..."
        print("🟢 Starting room scan...")
    }

    func stop() {
        isScanning = false
        debugInfo = "Stopped"
        print("🔴 Stopping room scan...")
    }

    // This method is called by Coordinator to update detected objects
    func roomCaptureView(_ roomCaptureView: RoomCaptureView, didUpdate room: CapturedRoom) {
        DispatchQueue.main.async {
            self.detectedObjects = room.objects
            self.debugInfo = "Detected \(room.objects.count) objects"
            print("✅ Detected \(room.objects.count) objects")
        }
    }
    
    func roomCaptureView(_ captureView: RoomCaptureView, didFail error: Error) {
        DispatchQueue.main.async {
            self.errorMessage = error.localizedDescription
            self.debugInfo = "Error: \(error.localizedDescription)"
            print("❌ Room capture failed: \(error.localizedDescription)")
        }
    }
    
    func roomCaptureViewDidStart(_ captureView: RoomCaptureView) {
        DispatchQueue.main.async {
            self.debugInfo = "Camera started successfully"
            print("🎥 Camera feed started")
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
            // Try ARView approach first
            ARScanView(viewModel: vm)
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
                                    Text(String(describing: obj.category).capitalized)
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

struct ARScanView: UIViewRepresentable {
    @ObservedObject var viewModel: ViewModel

    func makeCoordinator() -> ARScanCoordinator {
        ARScanCoordinator(viewModel: viewModel)
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.session.delegate = context.coordinator
        
        // Configure AR session for room scanning
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .automatic
        
        arView.session.run(configuration)
        
        print("🟢 ARView created and session started")
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        print("🔄 ARView updated")
    }
}

class ARScanCoordinator: NSObject, ARSessionDelegate {
    let viewModel: ViewModel
    
    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // This confirms the camera is working
        DispatchQueue.main.async {
            self.viewModel.debugInfo = "Camera frame updated"
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.viewModel.errorMessage = error.localizedDescription
            self.viewModel.debugInfo = "AR Session failed: \(error.localizedDescription)"
        }
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        DispatchQueue.main.async {
            self.viewModel.debugInfo = "AR Session interrupted"
        }
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        DispatchQueue.main.async {
            self.viewModel.debugInfo = "AR Session resumed"
        }
    }
}

struct RoomScanView: UIViewRepresentable {
    @ObservedObject var viewModel: ViewModel

    func makeCoordinator() -> RoomScanCoordinator {
        RoomScanCoordinator(viewModel: viewModel)
    }

    func makeUIView(context: Context) -> RoomCaptureView {
        let view = RoomCaptureView()
        view.delegate = context.coordinator
        
        // Configure the view
        view.isOpaque = false
        view.backgroundColor = .clear
        
        print("🟢 RoomCaptureView created")
        return view
    }

    func updateUIView(_ uiView: RoomCaptureView, context: Context) {
        print("🔄 RoomCaptureView updated")
    }
}
