//
//  RileyLinkListTableViewController.swift
//  RileyLink
//
//  Created by Pete Schwamb on 5/11/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import UIKit
import MinimedKit
import MinimedKitUI
import RileyLinkBLEKit
import RileyLinkKit
import RileyLinkKitUI
import LoopKit
import LoopKitUI


class RileyLinkListTableViewController: UITableViewController, DeviceConnectionPreferenceDelegate {

    private lazy var numberFormatter = NumberFormatter()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 44
        
        tableView.register(RileyLinkDeviceTableViewCell.self, forCellReuseIdentifier: RileyLinkDeviceTableViewCell.className)
        tableView.register(SettingsImageTableViewCell.self, forCellReuseIdentifier: SettingsImageTableViewCell.className)
        tableView.register(TextButtonTableViewCell.self, forCellReuseIdentifier: TextButtonTableViewCell.className)
        
        devicesDataSource.connectionPreferenceDelegate = self
        devicesDataSource.tableView = tableView
    }
    
    override func viewWillAppear(_ animated: Bool) {
        // Manually invoke the delegate for rows deselecting on appear
        for indexPath in tableView.indexPathsForSelectedRows ?? [] {
            _ = tableView(tableView, willDeselectRowAt: indexPath)
        }
        
        super.viewWillAppear(animated)
    }
    
    fileprivate enum Section: Int, CaseCountable {
        case devices = 0
        case pump
    }
    
    fileprivate enum PumpActionRow: Int, CaseCountable {
        case addMinimedPump = 0
        case addPod
    }
    
    weak var rileyLinkManager: RileyLinkDeviceManager!
    
    private lazy var devicesDataSource: RileyLinkDevicesTableViewDataSource = {
        return RileyLinkDevicesTableViewDataSource(
            rileyLinkManager: rileyLinkManager,
            devicesSectionIndex: Section.devices.rawValue
        )
    }()

    private var dataManager: DeviceDataManager {
        return DeviceDataManager.sharedManager
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        devicesDataSource.isScanningEnabled = true

    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        devicesDataSource.isScanningEnabled = false
    }
    
    // MARK: Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .devices:
            return devicesDataSource.tableView(tableView, numberOfRowsInSection: section)
        case .pump:
            if let _ = dataManager.pumpManager {
                return 1
            } else {
                return PumpActionRow.count
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell
        
        switch(Section(rawValue: indexPath.section)!) {
        case .devices:
            cell = devicesDataSource.tableView(tableView, cellForRowAt: indexPath)
        case .pump:
            if let pumpManager = dataManager.pumpManager as? PumpManagerUI {
                cell = tableView.dequeueReusableCell(withIdentifier: SettingsImageTableViewCell.className, for: indexPath)
                cell.imageView?.image = pumpManager.smallImage
                cell.textLabel?.text = pumpManager.localizedTitle
                cell.detailTextLabel?.text = nil
                cell.accessoryType = .disclosureIndicator
            } else {
                switch(PumpActionRow(rawValue: indexPath.row)!) {
                case .addMinimedPump:
                    cell = tableView.dequeueReusableCell(withIdentifier: TextButtonTableViewCell.className, for: indexPath)
                    cell.textLabel?.text = NSLocalizedString("Add Minimed Pump", comment: "Title text for button to set up a new minimed pump")
                case .addPod:
                    cell = tableView.dequeueReusableCell(withIdentifier: TextButtonTableViewCell.className, for: indexPath)
                    cell.textLabel?.text = NSLocalizedString("Pair New Pod", comment: "Title text for button to pair a new pod")
                }
            }
        }
        return cell
    }
    
    public override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .devices:
            return devicesDataSource.tableView(tableView, titleForHeaderInSection: section)
        case .pump:
            return NSLocalizedString("Pumps", comment: "Title text for section listing configured pumps")
        }
    }
    
    public override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        switch Section(rawValue: section)! {
        case .devices:
            return devicesDataSource.tableView(tableView, viewForHeaderInSection: section)
        case .pump:
            return nil
        }
    }
    
    public override func tableView(_ tableView: UITableView, estimatedHeightForHeaderInSection section: Int) -> CGFloat {
        return devicesDataSource.tableView(tableView, estimatedHeightForHeaderInSection: section)
    }

    
    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let sender = tableView.cellForRow(at: indexPath)
        
        switch Section(rawValue: indexPath.section)! {
        case .devices:
            let device = devicesDataSource.devices[indexPath.row]            
            let deviceState = dataManager.deviceStates[device.peripheralIdentifier, default: DeviceState()]
            let vc = RileyLinkMinimedDeviceTableViewController(
                device: device,
                deviceState: deviceState,
                pumpSettings: nil,
                pumpState: nil,
                pumpOps: nil
            )
            show(vc, sender: indexPath)
        case .pump:
            if let pumpManager = dataManager.pumpManager as? PumpManagerUI {
                let settings = pumpManager.settingsViewController()
                show(settings, sender: sender)
            } else {
                switch PumpActionRow(rawValue: indexPath.row)! {
                case .addMinimedPump:
                    var setupViewController = MinimedPumpManager.setupViewController()
                    if let rlSetupViewController = setupViewController as? RileyLinkManagerSetupViewController {
                        rlSetupViewController.rileyLinkManager = rileyLinkManager
                    }
                    setupViewController.setupDelegate = self
                    present(setupViewController, animated: true, completion: nil)
                    break
                case .addPod:
                    break
                }
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, willDeselectRowAt indexPath: IndexPath) -> IndexPath? {
        switch Section(rawValue: indexPath.section)! {
        case .devices:
            break
        case .pump:
            tableView.reloadSections(IndexSet([Section.pump.rawValue]), with: .none)
        }
        
        return indexPath
    }

    
    // MARK: - DeviceConnectionPreferenceDelegate
    func connectionPreferenceChanged(connectionPreference: DeviceConnectionPreference, device: RileyLinkDevice) {
        switch connectionPreference {
        case .autoConnect:
            rileyLinkManager.connect(device)
        case .noAutoConnect:
            rileyLinkManager.disconnect(device)
        }
    }
    
    func getGonnectionPreferenceFor(device: RileyLinkDevice) -> DeviceConnectionPreference? {
        return nil
    }    
}

extension RileyLinkListTableViewController: PumpManagerSetupViewControllerDelegate {
    func pumpManagerSetupViewController(_ pumpManagerSetupViewController: PumpManagerSetupViewController, didSetUpPumpManager pumpManager: PumpManagerUI) {
        dataManager.pumpManager = pumpManager
        show(pumpManager.settingsViewController(), sender: nil)
        tableView.reloadSections(IndexSet([Section.pump.rawValue]), with: .none)
        dismiss(animated: true, completion: nil)
    }
    
    func pumpManagerSetupViewControllerDidCancel(_ pumpManagerSetupViewController: PumpManagerSetupViewController) {
        dismiss(animated: true, completion: nil)
    }
}
