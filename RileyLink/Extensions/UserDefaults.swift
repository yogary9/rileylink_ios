//
//  UserDefaults.swift
//  RileyLink
//
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

import Foundation
import MinimedKit
import RileyLinkKit
import OmniKit
import LoopKit

extension UserDefaults {
    private enum Key: String {
        case pumpSettings = "com.rileylink.pumpSettings"
        case pumpState = "com.rileylink.pumpState"
        case podState = "com.rileylink.podState"
        case pumpManager = "com.rileylink.pumpManager"
    }

    var pumpSettings: PumpSettings? {
        get {
            guard let raw = dictionary(forKey: Key.pumpSettings.rawValue) else {
                return nil
            }

            return PumpSettings(rawValue: raw)
        }
        set {
            set(newValue?.rawValue
                , forKey: Key.pumpSettings.rawValue)
        }
    }

    var pumpState: PumpState? {
        get {
            guard let raw = dictionary(forKey: Key.pumpState.rawValue) else {
                return nil
            }

            return PumpState(rawValue: raw)
        }
        set {
            set(newValue?.rawValue, forKey: Key.pumpState.rawValue)
        }
    }
    
    var podState: PodState? {
        get {
            guard let raw = dictionary(forKey: Key.podState.rawValue) else {
                return nil
            }
            
            return PodState(rawValue: raw)
        }
        set {
            set(newValue?.rawValue, forKey: Key.podState.rawValue)
        }
    }
    
    var pumpManager: PumpManager? {
        get {
            guard let raw = dictionary(forKey: Key.pumpManager.rawValue) else {
                return nil
            }
            
            return PumpManagerFromRawValue(raw)
        }
        set {
            set(newValue?.rawValue, forKey: Key.pumpManager.rawValue)
        }
    }
}
