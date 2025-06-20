import SwiftUI
import RoomPlan
import RealityKit

class ViewModel: ObservableObject {
    @Published var detectedObjects: [CapturedRoom.Object] = []
    @Published var projectedPoints: [CapturedRoom.Object: CGPoint] = [:]

    // Hidden ARView instance used only for projecting 3D points to 2D
    private let arView = ARView(frame: .zero)

    func start() {
        // Nothing special here; RoomCaptureView manages scanning internally
    }

    func updateProjectedPoints() {
        var newPoints: [CapturedRoom.Object: CGPoint] = [:]
        
        guard let frame = arView.session.currentFrame else {
            print("❌ ARView has no current ARFrame – projection will not run")
            return
        }

        print("✅ ARFrame available: camera transform = \(frame.camera.transform)")

        for obj in detectedObjects {
            let pos = SIMD3<Float>(
                obj.transform.columns.3.x,
                obj.transform.columns.3.y,
                obj.transform.columns.3.z
            )

            if let projected = arView.project(pos) {
                newPoints[obj] = CGPoint(x: CGFloat(projected.x), y: CGFloat(projected.y))
            } else {
                print("⚠️ Could not project object at position \(pos)")
            }
        }

        DispatchQueue.main.async {
            self.projectedPoints = newPoints
        }
    }


    // This method is called by Coordinator to update detected objects
    func roomCaptureView(_ roomCaptureView: RoomCaptureView, didUpdate room: CapturedRoom) {
        DispatchQueue.main.async {
            self.detectedObjects = room.objects
            self.updateProjectedPoints()
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

            Color.green.opacity(0.2) // Add this for debug

            RoomScanView(viewModel: vm)
                .ignoresSafeArea()

            GeometryReader { geo in
                ForEach(Array(vm.detectedObjects.enumerated()), id: \.element) { index, obj in
                    if let pos = vm.projectedPoints[obj] {
                        Text(String(describing: obj.category).capitalized)
                            .padding(6)
                            .background(Color.black.opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(6)
                            .position(x: pos.x, y: pos.y)

                    }
                }
            }
        }
        .onAppear {
            vm.start()
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
        return view
    }

    func updateUIView(_ uiView: RoomCaptureView, context: Context) {}
}
