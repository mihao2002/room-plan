import SwiftUI
import RoomPlan
import RealityKit
import ARKit
import AVFoundation

class ViewModel: ObservableObject {
    @Published var detectedObjects: [CapturedRoom.Object] = []
    @Published var isScanning = false
    @Published var errorMessage: String?
    @Published var debugInfo: String = "Initializing..."

    func start() {
        isScanning = true
        errorMessage = nil
        debugInfo = "Starting camera session..."
        print("🟢 Starting camera session...")
    }

    func stop() {
        isScanning = false
        debugInfo = "Stopped"
        print("🔴 Stopping camera session...")
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
            // Camera view with AVFoundation
            CameraView(viewModel: vm)
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

// Camera view using AVFoundation
struct CameraView: UIViewRepresentable {
    @ObservedObject var viewModel: ViewModel

    func makeCoordinator() -> CameraCoordinator {
        CameraCoordinator(viewModel: viewModel)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        view.backgroundColor = .black
        
        // Set up camera preview layer
        let previewLayer = AVCaptureVideoPreviewLayer()
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        // Store reference to preview layer in coordinator
        context.coordinator.previewLayer = previewLayer
        
        // Start camera session
        context.coordinator.startCameraSession()
        
        print("🟢 CameraView created with frame: \(view.frame)")
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // Update preview layer frame if needed
        context.coordinator.previewLayer?.frame = uiView.bounds
        print("🔄 CameraView updated with frame: \(uiView.frame)")
    }
}

class CameraCoordinator: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let viewModel: ViewModel
    var previewLayer: AVCaptureVideoPreviewLayer?
    private var captureSession: AVCaptureSession?
    private var roomCaptureSession: RoomCaptureSession?
    
    init(viewModel: ViewModel) {
        self.viewModel = viewModel
        super.init()
        print("🟢 CameraCoordinator initialized")
    }
    
    func startCameraSession() {
        let session = AVCaptureSession()
        session.sessionPreset = .high
        
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            viewModel.setError("Camera not available")
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(input) {
                session.addInput(input)
            }
            
            // Add video output for processing
            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue.global(qos: .userInteractive))
            
            if session.canAddOutput(videoOutput) {
                session.addOutput(videoOutput)
            }
            
            // Set preview layer session
            previewLayer?.session = session
            
            // Start session on background queue
            DispatchQueue.global(qos: .userInteractive).async {
                session.startRunning()
                self.captureSession = session
                
                DispatchQueue.main.async {
                    self.viewModel.setDebugInfo("Camera session started")
                }
                
                // Start RoomPlan scanning after camera is ready
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.startRoomPlanScanning()
                }
            }
            
        } catch {
            viewModel.setError("Failed to setup camera: \(error.localizedDescription)")
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Camera is working - update debug info occasionally
        DispatchQueue.main.async {
            self.viewModel.setDebugInfo("Camera feed active")
        }
    }
    
    private func startRoomPlanScanning() {
        guard roomCaptureSession == nil else { return }
        
        do {
            roomCaptureSession = try RoomCaptureSession()
            roomCaptureSession?.delegate = self
            
            DispatchQueue.main.async {
                self.viewModel.setDebugInfo("RoomPlan scanning started")
            }
            
            print("🎥 RoomPlan scanning started")
        } catch {
            DispatchQueue.main.async {
                self.viewModel.setError("Failed to start RoomPlan: \(error.localizedDescription)")
            }
            print("❌ Failed to start RoomPlan: \(error)")
        }
    }
}

extension CameraCoordinator: RoomCaptureSessionDelegate {
    func captureSession(_ session: RoomCaptureSession, didUpdate room: CapturedRoom) {
        viewModel.updateDetectedObjects(room.objects)
    }
    
    func captureSession(_ session: RoomCaptureSession, didFailWithError error: Error) {
        viewModel.setError("RoomPlan failed: \(error.localizedDescription)")
    }
}
