
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

    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.addTarget(self, action: #selector(callButtonPressed(_:)), for: .touchUpInside)
    }
   
    public override init(frame: CGRect) {
        super.init(frame: frame)
        self.addTarget(self, action: #selector(callButtonPressed(_:)), for: .touchUpInside)
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
        
        login()
        // Call will be made after successful login - as defined in delegate
    }

    
    
    public func login() {
        guard let token = nexmoToken else {
            print("Token is not set")
            return
        }
        NXMClient.shared.setDelegate(self)
        NXMClient.shared.login(withAuthToken: token)
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
            NXMClient.shared.call(callee, callHandler: (callee.isPhoneNumber) ? .server : .inApp, completionHandler: completion)
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

extension NXMCallButton: NXMClientDelegate {
    public func client(_ client: NXMClient, didChange status: NXMConnectionStatus, reason: NXMConnectionStatusReason) {
        print("Nexmo Client Authorization: Success")
        if (status == .connected) {
            // Inside self.call(), we check if userWantsToCall == true
            self.call()
        }
    }
    
    public func client(_ client: NXMClient, didReceiveError error: Error) {
        print("Nexmo Client Authorization: Faliure")
        print(error.localizedDescription)
    }
    
}


extension String {
    var isPhoneNumber: Bool {
        do {
            let detector = try NSDataDetector(types: NSTextCheckingResult.CheckingType.phoneNumber.rawValue)
            let matches = detector.matches(in: self, options: [], range: NSRange(location: 0, length: self.count))
            if let res = matches.first {
                return res.resultType == .phoneNumber && res.range.location == 0 && res.range.length == self.count
            } else {
                return false
            }
        } catch {
            return false
        }
    }
}
