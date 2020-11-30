//
//  InterfaceController.swift
//  BadmintonActivityClassifier WatchKit Extension
//
//  Created by Eki Rifaldi on 28/07/20.
//  Copyright © 2020 Eki Rifaldi. All rights reserved.
//

import WatchKit
import Foundation
import WatchConnectivity
import CoreMotion
//import HealthKit
import CoreML


class InterfaceController: WKInterfaceController {
    
    @IBOutlet weak var labelHeart: WKInterfaceLabel!
    @IBOutlet weak var button: WKInterfaceButton! {
        didSet {
            let exitTitle = NSMutableAttributedString(string: "Start Recording")
            exitTitle.setAttributes([NSAttributedString.Key.foregroundColor: UIColor.green], range: NSMakeRange(0, exitTitle.length))
            button.setAttributedTitle(exitTitle)
        }
    }
    
    
    var wcSession : WCSession!
    var motion = CMMotionManager()
    var dataMotionArray:[Dictionary<String, AnyObject>] =  Array()
    
    var isRecording = false
    let sensorsUpdateFrequency = 1.0 / 75.0
    let predictionWindowSize = 80
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        // Configure interface objects here.
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
        print("willActivate")
        
        wcSession = WCSession.default
        wcSession.delegate = self
        wcSession.activate()
        
        WKExtension.shared().isAutorotating = true
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }
    
    @IBAction func btnPressed() {
        if(!isRecording){
            startRecording()
        }else{
            stopRecording()
        }
    }
    
    func startRecording(){
        let stopTitle = NSMutableAttributedString(string: "Stop Recording")
        stopTitle.setAttributes([NSAttributedString.Key.foregroundColor: UIColor.red], range: NSMakeRange(0, stopTitle.length))
        button.setAttributedTitle(stopTitle)
        startDeviceMotion()
        isRecording = !isRecording
    }
    
    func stopRecording(){
        stopDeviceMotion()
        let exitTitle = NSMutableAttributedString(string: "Start Recording")
        exitTitle.setAttributes([NSAttributedString.Key.foregroundColor: UIColor.green], range: NSMakeRange(0, exitTitle.length))
        button.setAttributedTitle(exitTitle)
//        session?.stopActivity(with: Date())
        labelHeart.setText("Heart Rate")
        isRecording = !isRecording
    }
}

//MARK: - CoreMotion
extension InterfaceController {
    
    func startDeviceMotion(){
        var csvString = ""
        var dataMotionCounter = 0
        motion.deviceMotionUpdateInterval  = sensorsUpdateFrequency
        motion.startDeviceMotionUpdates(to: OperationQueue.current!) {
            (data, error) in
            if let trueData =  data {
                
                csvString = csvString.appending("\(trueData.userAcceleration.x),\(trueData.userAcceleration.y),\(trueData.userAcceleration.z),\(trueData.rotationRate.x),\(trueData.rotationRate.y),\(trueData.rotationRate.z)\n")
                dataMotionCounter += 1
                
                if dataMotionCounter == self.predictionWindowSize {
                    self.sendMessage(strMsg: csvString, isMotion: true)
                    csvString = ""
                    dataMotionCounter = 0
                    //sementara
                    self.stopRecording()
                }
            }
        }
        return
    }
    
    func stopDeviceMotion() {
        if motion.isDeviceMotionAvailable {
            motion.stopDeviceMotionUpdates()
        }
    }
    
}

//    MARK: - WCSession
extension InterfaceController: WCSessionDelegate {
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        
        if let instruction = message["instructionFromIos"] as? String {
            if instruction == "STOP" {
                stopRecording()
            } else if instruction == "START" {
                startRecording()
            }
        }
        
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        
        // Code.
        
    }
    
    func sendMessage(strMsg: String, isMotion: Bool){
        var message = ["instructionFromWatch":strMsg]
        if isMotion {
            message = ["motionFromWatch":strMsg]
        }
        
        wcSession.sendMessage(message, replyHandler: nil) { (error) in
            
            print(error.localizedDescription)
            
        }
        
    }
}
