//
//  ViewController.swift
//  BadmintonActivityClassifier
//
//  Created by Eki Rifaldi on 28/07/20.
//  Copyright © 2020 Eki Rifaldi. All rights reserved.
//

import UIKit
import WatchConnectivity
import HealthKit
import CoreML

class ViewController: UIViewController {
    
    struct ModelConstants {
        // Must be the same value you used while training
        static let predictionWindowSize = 6
        // Must be the same value you used while training
        static let sensorsUpdateFrequency = 1.0 / 75.0
        static let stateInLength = 400
        //        https://apple.github.io/turicreate/docs/userguide/activity_classifier/export_coreml.html
    }
    
    let accX = try? MLMultiArray(
        shape: [ModelConstants.predictionWindowSize] as [NSNumber],
        dataType: MLMultiArrayDataType.double)
    
    let accY = try? MLMultiArray(
        shape: [ModelConstants.predictionWindowSize] as [NSNumber],
        dataType: MLMultiArrayDataType.double)
    
    let accZ = try? MLMultiArray(
        shape: [ModelConstants.predictionWindowSize] as [NSNumber],
        dataType: MLMultiArrayDataType.double)
    
    let rotX = try? MLMultiArray(
        shape: [ModelConstants.predictionWindowSize] as [NSNumber],
        dataType: MLMultiArrayDataType.double)
    
    let rotY = try? MLMultiArray(
        shape: [ModelConstants.predictionWindowSize] as [NSNumber],
        dataType: MLMultiArrayDataType.double)
    
    let rotZ = try? MLMultiArray(
        shape: [ModelConstants.predictionWindowSize] as [NSNumber],
        dataType: MLMultiArrayDataType.double)
    
    var currentState = try? MLMultiArray(
        shape: [ModelConstants.stateInLength as NSNumber],
        dataType: MLMultiArrayDataType.double)
    
    let healthStore = HKHealthStore()
    var wcSession : WCSession! = nil
    
    // Initialize the model, layers, and sensor data arrays
    private let classifier = BadmintonActivityClassifier()
    private let modelName:String = "BadmintonActivityClassifier"
    var currentIndexInPredictionWindow = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        wcSession = WCSession.default
        wcSession.delegate = self
        wcSession.activate()
        
        let allTypes = Set([HKObjectType.workoutType(),
                            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
                            HKObjectType.quantityType(forIdentifier: .distanceCycling)!,
                            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
                            HKObjectType.quantityType(forIdentifier: .heartRate)!])
        
        healthStore.requestAuthorization(toShare: allTypes, read: allTypes) { (success, error) in
            if !success {
                // Handle the error here.
            }
        }
    }
    
    @IBAction func btnStopPressed(_ sender: UIButton) {
        sendInstruction(strInstruction: "STOP")
    }
    
}


//MARK: - WatchConnectivity
extension ViewController: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        print("MESSAGE")
        if let instruction = message["instructionFromWatch"] as? String {
            print(instruction)
        }
        
        if let csv = message["motionFromWatch"] as? String {
            print(csv)
            //            csvString = csvString.appending(csv)
            convertCsvStrToArray(csvStr: csv)
        }
        
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        
    }
    
    func sendInstruction(strInstruction: String) {
        let message = ["instructionFromIos":strInstruction]
        
        wcSession.sendMessage(message, replyHandler: nil) { (error) in
            
            print(error.localizedDescription)
            
        }
    }
}

//MARK: - CoreML
extension ViewController {
    func activityPrediction() -> String? {
        // Perform prediction
        let modelPrediction = try? classifier.prediction(
            Accelerometer_X: accX!,
            Accelerometer_Y: accY!,
            Accelerometer_Z: accZ!,
            Gyroscope_X: rotX!,
            Gyroscope_Y: rotY!,
            Gyroscope_Z: rotZ!,
            stateIn: currentState)
        
        // Update the state vector
        currentState = modelPrediction?.stateOut
        
        // Return the predicted activity
        return modelPrediction?.label
    }
    
    func convertCsvStrToArray(csvStr: String) {
        DispatchQueue.global().async {
            let lines = csvStr.split(separator: "\n")
            for line in lines {
                let columns = line.split(separator: ",", omittingEmptySubsequences: false)
                self.accX![self.currentIndexInPredictionWindow] = Double(columns[0])! as NSNumber
                self.accY![self.currentIndexInPredictionWindow] = Double(columns[1])! as NSNumber
                self.accZ![self.currentIndexInPredictionWindow] = Double(columns[2])! as NSNumber
                self.rotX![self.currentIndexInPredictionWindow] = Double(columns[3])! as NSNumber
                self.rotY![self.currentIndexInPredictionWindow] = Double(columns[4])! as NSNumber
                self.rotZ![self.currentIndexInPredictionWindow] = Double(columns[5])! as NSNumber
                
                // Update prediction array index
                self.currentIndexInPredictionWindow += 1
                
                // If data array is full - execute a prediction
                if (self.currentIndexInPredictionWindow == ModelConstants.predictionWindowSize) {
                    // Move to main thread to update the UI
                    DispatchQueue.main.async {
                        // Use the predicted activity
//                        self.label.text = self.activityPrediction() ?? "N/A" 
                        print(self.activityPrediction() ?? "N/A")
                    }
                    // Start a new prediction window from scratch
                    self.currentIndexInPredictionWindow = 0
                }
            }
        }
    }
}
