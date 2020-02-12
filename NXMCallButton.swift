import UIKit
import AVFoundation
import NexmoClient

public class NXMCallButton: UIButton {
    
    @IBInspectable public var nexmoToken: String?
    @IBInspectable public var callee: String?
    public var callCompletionHandler: ((Error?, NXMCall?) -> Void)?
    
    private var session: AVAudioSession = AVAudioSession.sharedInstance()
    private var recordPermissionGranted = false
    private var isCalling = false
    private var userWantsToCall = false
    
    private func buttonInit() {
        self.addTarget(self, action: #selector(callButtonPressed(_:)), for: .touchUpInside)
        if NXMClient.shared.connectionStatus != .connected {
            guard let token = nexmoToken else {
                return
            }
            NXMClient.shared.login(withAuthToken: token)
        }
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        buttonInit()
    }
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        buttonInit()
    }
    
    
    @objc func callButtonPressed(_ sender: Any) {
        userWantsToCall = true
        
        if (!recordPermissionGranted) {
            getRecordPermission()
        }
        
        if NXMClient.shared.connectionStatus == .connected {
            call()
            return
        }
    }
    
    
    
    public func call() {
        let completion: (Error?, NXMCall?) -> Void
        completion =  { (err: Error?, call: NXMCall?) in
            self.isCalling = false
            if let userCompletion = self.callCompletionHandler {
                // Perform the completion handler that the user provided.
                userCompletion(err, call);
            }
        }
        
        
        // Verify Permissions
        if (!recordPermissionGranted) {
            print("Record permission not granted")
            return
        }
        
        // Verify Callee is set
        guard let callee = callee, !callee.isEmpty else {
            print("Callee not set")
            return
        }
        
        // Verify Nexmo Client
        guard NXMClient.shared.connectionStatus == .connected else {
            print("Nexmo Client not connected")
            return
        }
        
        // Verify that the user is not mid call, and verify that the user intended to call.
        // This prevents a call being performed after successful login, where the user hasn't pressed the button.
        if (!isCalling && userWantsToCall) {
            isCalling = true
            NXMClient.shared.call(callee, callHandler: .server, completionHandler: completion)
            userWantsToCall = false
        }
    }
}


extension NXMCallButton {
    func getRecordPermission() {
        if (session.responds(to: #selector(AVAudioSession.requestRecordPermission(_:)))) {
            AVAudioSession.sharedInstance().requestRecordPermission(){  (granted: Bool) in
                self.recordPermissionGranted = granted
                if granted {
                    print("record permission granted")
                    do {
                        try self.session.setCategory(.playAndRecord, mode: .default, options: [])
                        try self.session.setActive(true)
                    }
                    catch {
                        print("Couldn't set Audio session category")
                    }
                    
                } else {
                    print("record permission not granted")
                }
            }
        }
    }
}



