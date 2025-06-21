import SwiftUI
import RoomPlan

class ViewModel: ObservableObject {
    @Published var detectedObjects: [CapturedRoom.Object] = []
    @Published var isScanning = false
    @Published var errorMessage: String?
    @Published var debugInfo: String = "Initializing..."

    func start() {
        isScanning = true
        errorMessage = nil
        debugInfo = "Starting RoomPlan scan..."
        print("🟢 Starting RoomPlan scan...")
    }

    func stop() {
        isScanning = false
        debugInfo = "Stopped"
        print("🔴 Stopping RoomPlan scan...")
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
            // Simple RoomCaptureView - this should show camera feed and detect furniture
            RoomScanView(viewModel: vm)
                .ignoresSafeArea()

            // Debug overlay
            VStack {
                HStack {
                    Text("Simple RoomPlan Test")
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

// Simple RoomPlan scanning view
struct RoomScanView: UIViewRepresentable {
    @ObservedObject var viewModel: ViewModel

    func makeCoordinator() -> RoomScanCoordinator {
        RoomScanCoordinator(viewModel: viewModel)
    }

    func makeUIView(context: Context) -> RoomCaptureView {
        let view = RoomCaptureView()
        view.delegate = context.coordinator
        
        print("🟢 RoomCaptureView created")
        return view
    }

    func updateUIView(_ uiView: RoomCaptureView, context: Context) {
        print("🔄 RoomCaptureView updated")
    }
}
