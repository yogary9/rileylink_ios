//
//  DeviceDataManager.swift
//  RileyLink
//
//  Created by Pete Schwamb on 4/27/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation
import RileyLinkKit
import RileyLinkKitUI
import RileyLinkBLEKit
import MinimedKit
import MinimedKitUI
import NightscoutUploadKit
import OmniKit
import LoopKit

class DeviceDataManager {

    /// Manages remote data
    let remoteDataManager = RemoteDataManager()
    
    var deviceStates: [UUID: DeviceState] = [:]

    private(set) var pumpOps: PumpOps? {
        didSet {
            if pumpOps == nil {
                UserDefaults.standard.pumpState = nil
            }
        }
    }
    
    let podComms: PodComms
    
    var pumpManager: PumpManager? {
        didSet {
            UserDefaults.standard.pumpManager = pumpManager
            setupPump()
        }
    }
    
    var pumpState: PumpState? {
        return UserDefaults.standard.pumpState
    }

    // MARK: - Operation helpers

    var latestPumpStatusDate: Date?

    var latestPumpStatusFromMySentry: MySentryPumpStatusMessageBody? {
        didSet {
            if let update = latestPumpStatusFromMySentry, let timeZone = pumpState?.timeZone {
                var pumpClock = update.pumpDateComponents
                pumpClock.timeZone = timeZone
                latestPumpStatusDate = pumpClock.date
            }
        }
    }


    var latestPolledPumpStatus: MinimedKit.PumpStatus? {
        didSet {
            if let update = latestPolledPumpStatus {
                latestPumpStatusDate = update.clock.date
            }
        }
    }

    var lastHistoryAttempt: Date? = nil
    
    var lastGlucoseEntry: Date = Date(timeIntervalSinceNow: TimeInterval(hours: -24))
    
    private func setupPump() {
        pumpManager?.pumpManagerDelegate = self
    }

    
    private func uploadDeviceStatus(_ pumpStatus: NightscoutUploadKit.PumpStatus? /*, loopStatus: LoopStatus */) {
        
        guard let uploader = remoteDataManager.nightscoutUploader else {
            return
        }

        // Gather UploaderStatus
        let uploaderDevice = UIDevice.current
        let uploaderStatus = UploaderStatus(name: uploaderDevice.name, timestamp: Date(), battery: uploaderDevice.batteryLevel)

        // Build DeviceStatus
        let deviceStatus = DeviceStatus(device: "rileylink://" + uploaderDevice.name, timestamp: Date(), pumpStatus: pumpStatus, uploaderStatus: uploaderStatus)
        
        uploader.uploadDeviceStatus(deviceStatus)
    }
    


    /**
     Attempts to fix an extended communication failure between a RileyLink device and the pump
     
     - parameter device: The RileyLink device
     */
    private func troubleshootPumpCommsWithDevice(_ device: RileyLinkDevice) {
        
        // How long we should wait before we re-tune the RileyLink
        let tuneTolerance = TimeInterval(minutes: 14)

        guard let pumpOps = pumpOps else {
            return
        }

        let deviceState = deviceStates[device.peripheralIdentifier, default: DeviceState()]
        let lastTuned = deviceState.lastTuned ?? .distantPast

        if lastTuned.timeIntervalSinceNow <= -tuneTolerance {
            pumpOps.runSession(withName: "Tune pump", using: device) { (session) in
                do {
                    let scanResult = try session.tuneRadio(current: deviceState.lastValidFrequency)
                    print("Device auto-tuned to \(scanResult.bestFrequency)")

                    DispatchQueue.main.async {
                        self.deviceStates[device.peripheralIdentifier] = DeviceState(lastTuned: Date(), lastValidFrequency: scanResult.bestFrequency)
                    }
                } catch let error {
                    print("Device auto-tune failed with error: \(error)")
                }
            }
        }
    }
    
    private func getPumpHistory(_ device: RileyLinkDevice) {
        lastHistoryAttempt = Date()

        guard let pumpOps = pumpOps else {
            print("Missing pumpOps; is your pumpId configured?")
            return
        }

        let oneDayAgo = Date(timeIntervalSinceNow: TimeInterval(hours: -24))

        pumpOps.runSession(withName: "Get pump history", using: device) { (session) in
            do {
                let (events, pumpModel) = try session.getHistoryEvents(since: oneDayAgo)
                NSLog("fetchHistory succeeded.")
                DispatchQueue.main.async {
                    self.handleNewHistoryEvents(events, pumpModel: pumpModel, device: device)
                }
            } catch let error {
                NSLog("History fetch failed: %@", String(describing: error))
            }

            if Config.sharedInstance().fetchCGMEnabled, self.lastGlucoseEntry.timeIntervalSinceNow < TimeInterval(minutes: -5) {
                self.getPumpGlucoseHistory(device)
            }
        }
    }
    
    private func handleNewHistoryEvents(_ events: [TimestampedHistoryEvent], pumpModel: PumpModel, device: RileyLinkDevice) {
        // TODO: get insulin doses from history
        if Config.sharedInstance().uploadEnabled {
            remoteDataManager.nightscoutUploader?.processPumpEvents(events, source: device.deviceURI, pumpModel: pumpModel)
        }
    }
    
    private func getPumpGlucoseHistory(_ device: RileyLinkDevice) {
        guard let pumpOps = pumpOps else {
            print("Missing pumpOps; is your pumpId configured?")
            return
        }

        pumpOps.runSession(withName: "Get glucose history", using: device) { (session) in
            do {
                let events = try session.getGlucoseHistoryEvents(since: self.lastGlucoseEntry)
                NSLog("fetchGlucoseHistory succeeded.")
                if let latestEntryDate: Date = self.handleNewGlucoseHistoryEvents(events, device: device) {
                    self.lastGlucoseEntry = latestEntryDate
                }
            } catch let error {
                NSLog("Glucose History fetch failed: %@", String(describing: error))
            }
        }
    }
    
    private func handleNewGlucoseHistoryEvents(_ events: [TimestampedGlucoseEvent], device: RileyLinkDevice) -> Date? {
        if Config.sharedInstance().uploadEnabled {
            return remoteDataManager.nightscoutUploader?.processGlucoseEvents(events, source: device.deviceURI)
        }
        return nil
    }
    
    // MARK: - Initialization
    
    static let sharedManager = DeviceDataManager()

    init() {
        let podState = UserDefaults.standard.podState
        podComms = PodComms(podState: podState)
        
        podComms.delegate = self
        
        pumpManager = UserDefaults.standard.pumpManager
        setupPump()
        

        UIDevice.current.isBatteryMonitoringEnabled = true
    }
}

extension DeviceDataManager: PumpManagerDelegate {
    func pumpManager(_ pumpManager: PumpManager, didAdjustPumpClockBy adjustment: TimeInterval) {
    }
    
    func pumpManagerDidUpdatePumpBatteryChargeRemaining(_ pumpManager: PumpManager, oldValue: Double?) {
    }
    
    func pumpManagerDidUpdateState(_ pumpManager: PumpManager) {
        self.pumpManager = pumpManager
    }
    
    func pumpManagerBLEHeartbeatDidFire(_ pumpManager: PumpManager) {
    }
    
    func pumpManagerShouldProvideBLEHeartbeat(_ pumpManager: PumpManager) -> Bool {
        return true
    }
    
    func pumpManager(_ pumpManager: PumpManager, didUpdateStatus status: PumpManagerStatus) {
        //nightscoutDataManager.upload(pumpStatus: status)
    }
    
    func pumpManagerWillDeactivate(_ pumpManager: PumpManager) {
        self.pumpManager = nil
    }
    
    func pumpManager(_ pumpManager: PumpManager, didUpdatePumpRecordsBasalProfileStartEvents pumpRecordsBasalProfileStartEvents: Bool) {
    }
    
    func pumpManager(_ pumpManager: PumpManager, didError error: PumpManagerError) {
    }
    
    func pumpManager(_ pumpManager: PumpManager, didReadPumpEvents events: [NewPumpEvent], completion: @escaping (_ error: Error?) -> Void) {
    }
    
    func pumpManager(_ pumpManager: PumpManager, didReadReservoirValue units: Double, at date: Date, completion: @escaping (_ result: PumpManagerResult<(newValue: ReservoirValue, lastValue: ReservoirValue?, areStoredValuesContinuous: Bool)>) -> Void) {
    }
    
    func pumpManagerRecommendsLoop(_ pumpManager: PumpManager) {
    }
    
    func startDateToFilterNewPumpEvents(for manager: PumpManager) -> Date {
        return Date()
    }
    
    func startDateToFilterNewReservoirEvents(for manager: PumpManager) -> Date {
        return Date()
    }
}



extension DeviceDataManager: PodCommsDelegate {
    func podComms(_ podComms: PodComms, didChange state: PodState?) {
        UserDefaults.standard.podState = state
    }
}

