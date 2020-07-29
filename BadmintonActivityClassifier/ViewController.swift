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

class ViewController: UIViewController {
    
    let healthStore = HKHealthStore()
    var wcSession : WCSession! = nil
    var csvString = ""
    
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
            csvString = csvString.appending(csv)
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

