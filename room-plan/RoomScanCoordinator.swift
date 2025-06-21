import Foundation
import ARKit

@MainActor
class RoomScanCoordinator: NSObject, ARSessionDelegate {
    let viewModel: ViewModel

    init(viewModel: ViewModel) {
        self.viewModel = viewModel
        super.init()
        print("🟢 RoomScanCoordinator initialized")
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Update debug info
        DispatchQueue.main.async {
            self.viewModel.setDebugInfo("Camera frame updated")
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
