//
//  RileyLinkSettingsViewController.swift
//  Loop
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import UIKit
import CoreBluetooth
import RileyLinkBLEKit
import RileyLinkKit


open class RileyLinkSettingsViewController: UITableViewController, DeviceConnectionPreferenceDelegate {

    open let devicesDataSource: RileyLinkDevicesTableViewDataSource
    
    let rileyLinkPumpManager: RileyLinkPumpManager

    public init(rileyLinkPumpManager: RileyLinkPumpManager, devicesSectionIndex: Int, style: UITableViewStyle) {
        self.rileyLinkPumpManager = rileyLinkPumpManager
        devicesDataSource = RileyLinkDevicesTableViewDataSource(rileyLinkManager: rileyLinkPumpManager.rileyLinkManager, devicesSectionIndex: devicesSectionIndex)
        super.init(style: style)
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override open func viewDidLoad() {
        super.viewDidLoad()
        
        devicesDataSource.connectionPreferenceDelegate = self
        devicesDataSource.tableView = tableView
    }

    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        devicesDataSource.isScanningEnabled = true
    }

    override open func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        devicesDataSource.isScanningEnabled = false
    }

    // MARK: - UITableViewDataSource

    override open func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return devicesDataSource.tableView(tableView, numberOfRowsInSection: section)
    }

    override open func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return devicesDataSource.tableView(tableView, cellForRowAt: indexPath)
    }

    override open func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return devicesDataSource.tableView(tableView, titleForHeaderInSection: section)
    }

    // MARK: - UITableViewDelegate

    override open func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return devicesDataSource.tableView(tableView, viewForHeaderInSection: section)
    }
    
    // MARK: - DeviceConnectionPreferenceDelegate
    
    public func connectionPreferenceChanged(connectionPreference: DeviceConnectionPreference, device: RileyLinkDevice) {
        switch connectionPreference {
        case .autoConnect:
            rileyLinkPumpManager.connectToRileyLink(device)
        case .noAutoConnect:
            rileyLinkPumpManager.disconnectFromRileyLink(device)
        }
    }
    
    public func getGonnectionPreferenceFor(device: RileyLinkDevice) -> DeviceConnectionPreference? {
        return rileyLinkPumpManager.rileyLinkPumpManagerState.connectedPeripheralIDs.contains(device.peripheralIdentifier.uuidString) ? .autoConnect : .noAutoConnect
    }
}
