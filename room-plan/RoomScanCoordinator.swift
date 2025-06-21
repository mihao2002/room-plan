import Foundation
import RoomPlan

@MainActor
class RoomScanCoordinator: NSObject, RoomCaptureViewDelegate, NSSecureCoding {
    static var supportsSecureCoding: Bool { true }

    let viewModel: ViewModel

    init(viewModel: ViewModel) {
        self.viewModel = viewModel
        super.init()
        print("🟢 RoomScanCoordinator initialized")
    }

    required convenience init?(coder: NSCoder) {
        // You can return nil or inject a dummy ViewModel if needed
        self.init(viewModel: ViewModel())
    }

    func encode(with coder: NSCoder) {
        // No-op – nothing to encode
    }

    func captureView(_ captureView: RoomCaptureView, didUpdate room: CapturedRoom) {
         print("✅ Room updated - detected objects count: \(room.objects.count)")
         print("📊 Room details: openings=\(room.openings.count)")
         viewModel.updateDetectedObjects(room.objects)
     }

     func captureView(_ captureView: RoomCaptureView, didFail error: Error) {
         print("❌ Room capture failed: \(error.localizedDescription)")
         viewModel.setError(error.localizedDescription)
     }
     
     func captureViewDidStart(_ captureView: RoomCaptureView) {
         print("🎥 RoomCaptureView did start")
         viewModel.setDebugInfo("RoomPlan scanning started")
     }
     
     func captureViewDidStop(_ captureView: RoomCaptureView) {
         print("🛑 RoomCaptureView did stop")
         viewModel.setDebugInfo("RoomPlan scanning stopped")
     }
}
