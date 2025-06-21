import SwiftUI
import RoomPlan
import RealityKit

class ViewModel: ObservableObject {
    @Published var detectedObjects: [CapturedRoom.Object] = []
    @Published var projectedPoints: [CapturedRoom.Object: CGPoint] = [:]
    @Published var isScanning = false
    @Published var errorMessage: String?

    func start() {
        isScanning = true
        errorMessage = nil
        print("🟢 Starting room scan...")
    }

    func stop() {
        isScanning = false
        print("🔴 Stopping room scan...")
    }

    // This method is called by Coordinator to update detected objects
    func roomCaptureView(_ roomCaptureView: RoomCaptureView, didUpdate room: CapturedRoom) {
        DispatchQueue.main.async {
            self.detectedObjects = room.objects
            print("✅ Detected \(room.objects.count) objects")
        }
    }
    
    func roomCaptureView(_ captureView: RoomCaptureView, didFail error: Error) {
        DispatchQueue.main.async {
            self.errorMessage = error.localizedDescription
            print("❌ Room capture failed: \(error.localizedDescription)")
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
            // Debug background to ensure view is visible
            Color.black
                .ignoresSafeArea()
            
            // RoomCaptureView will show the camera feed
            RoomScanView(viewModel: vm)
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
        // No updates needed
    }
}
