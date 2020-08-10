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
import HealthKit
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
    
    //workout
    let healthStore = HKHealthStore()
    var session: HKWorkoutSession?
    var currentQuery: HKQuery?
    
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
        
        //Check HealthStore
        guard HKHealthStore.isHealthDataAvailable() == true else {
            print("Health Data Not Avaliable")
            return
        }
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
        startWorkout()
        startDeviceMotion()
        isRecording = !isRecording
    }
    
    func stopRecording(){
        stopDeviceMotion()
        let exitTitle = NSMutableAttributedString(string: "Start Recording")
        exitTitle.setAttributes([NSAttributedString.Key.foregroundColor: UIColor.green], range: NSMakeRange(0, exitTitle.length))
        button.setAttributedTitle(exitTitle)
        session?.stopActivity(with: Date())
        labelHeart.setText("Heart Rate")
        isRecording = !isRecording
    }
}

//MARK: - CoreMotion
extension InterfaceController {
    
    func startDeviceMotion(){
        print("Start DeviceMotion")
        var csvString = ""
        var dataMotionCounter = 0
        motion.deviceMotionUpdateInterval  = sensorsUpdateFrequency
        motion.startDeviceMotionUpdates(to: OperationQueue.current!) {
            (data, error) in
            //            print("Motion")
//            print(data as Any)
            if let trueData =  data {
                
                //csvString ganti dengan arrayList of Object (double motion data)
                csvString = csvString.appending("\(trueData.userAcceleration.x),\(trueData.userAcceleration.y),\(trueData.userAcceleration.z),\(trueData.rotationRate.x),\(trueData.rotationRate.y),\(trueData.rotationRate.z)\n")
                dataMotionCounter += 1
                print(dataMotionCounter)
                
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
    
//    func getNowTime() -> String {
//        let date = Date()
//        let calendar = Calendar.current
//        let hour = calendar.component(.hour, from: date)
//        let minutes = calendar.component(.minute, from: date)
//        let seconds = calendar.component(.second, from: date)
//        let nanoseconds = calendar.component(.nanosecond, from: date)
//        let strDate = "\(hour):\(minutes):\(seconds).\(nanoseconds)"
//        return strDate
//    }
}

//    MARK: - WCSession
extension InterfaceController: WCSessionDelegate {
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        
        if let instruction = message["instructionFromIos"] as? String {
            print(instruction)
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
        
        print("sendMessage")
    }
}

//MARK: - WorkOut
extension InterfaceController: HKWorkoutSessionDelegate{
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        print("State: \(toState.rawValue)")
        switch toState {
        case .running:
            print(date)
            if let query = heartRateQuery(date){
                self.currentQuery = query
                healthStore.execute(query)
            }
        //Execute Query
        case .stopped:
            //Stop Query
            print("STOP: \(date)")
            healthStore.stop(self.currentQuery!)
            session?.end()
            session = nil
        default:
            print("Unexpected state: \(toState.rawValue)")
        }
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        //Do Nothing
    }
    
    func startWorkout(){
        // If a workout has already been started, do nothing.
        if (session != nil) {
            return
        }
        // Configure the workout session.
        let workoutConfiguration = HKWorkoutConfiguration()
        workoutConfiguration.activityType = .badminton
        workoutConfiguration.locationType = .indoor
        
        do {
            session = try HKWorkoutSession(healthStore: healthStore, configuration: workoutConfiguration)
            session?.delegate = self
        } catch {
            fatalError("Unable to create workout session")
        }
        
        
        session?.startActivity(with: Date())
        print("Start Workout Session")
    }
    
    func heartRateQuery(_ startDate: Date) -> HKQuery? {
        let quantityType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate)
        let datePredicate = HKQuery.predicateForSamples(withStart: startDate, end: nil, options: .strictEndDate)
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates:[datePredicate])
        
        let heartRateQuery = HKAnchoredObjectQuery(type: quantityType!, predicate: predicate, anchor: nil, limit: Int(HKObjectQueryNoLimit)) { (query, sampleObjects, deletedObjects, newAnchor, error) -> Void in
            //Do nothing
        }
        
        heartRateQuery.updateHandler = {(query, samples, deleteObjects, newAnchor, error) -> Void in
            guard let samples = samples as? [HKQuantitySample] else {return}
            DispatchQueue.main.async {
                guard let sample = samples.first else { return }
                let value = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
//                print("This line is executed!")
                self.labelHeart.setText(String(UInt16(value))) //Update label
            }
            
        }
        
        return heartRateQuery
    }
    
}
