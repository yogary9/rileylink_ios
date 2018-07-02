//
//  PumpManagerState.swift
//  Loop
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit
import MinimedKit


let allPumpManagerTypes: [String: PumpManager.Type] = [
    MinimedPumpManager.managerIdentifier: MinimedPumpManager.self
]


func PumpManagerFromRawValue(_ rawValue: [String: Any]) -> PumpManager? {
    guard let managerIdentifier = rawValue["managerIdentifier"] as? String,
        let rawState = rawValue["state"] as? PumpManager.RawStateValue,
        let Manager = allPumpManagerTypes[managerIdentifier]
        else {
            return nil
    }
    
    return Manager.init(rawState: rawState)
}

extension PumpManager {
    var rawValue: [String: Any] {
        return [
            "managerIdentifier": type(of: self).managerIdentifier,
            "state": self.rawState
        ]
    }
}
