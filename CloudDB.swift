//
//  CloudDB.swift
//  SQLiteDB
//
//  Created by Fahim Farook on 22-10-2020.
//  Copyright © 2020 RookSoft Ltd. All rights reserved.
//

import CloudKit
import Foundation

class CloudDB {
	static let shared = CloudDB()

    var subscriptionPrefix = "clouddb"

	private let def = UserDefaults.standard
	private let container: CKContainer
	private var dbs = [CKDatabase.Scope: CKDatabase]()

	private init() {
		container = CKContainer.default()
		// Set up DBs
		dbs[.private] = container.privateCloudDatabase
		dbs[.public] = container.publicCloudDatabase
		dbs[.shared] = container.sharedCloudDatabase
	}

	// MARK: - Public Methods
	public func setup() {
		// Subscriptions and fetch changes since quit
		saveSubscription(scope: .private)
		fetchDatabaseChanges(scope: .private)
//		saveSubscription(scope: .public)
//		fetchDatabaseChanges(scope: .public)
		saveSubscription(scope: .shared)
		fetchDatabaseChanges(scope: .shared)
	}

	public func dbFor(scope: CKDatabase.Scope) -> CKDatabase {
		dbs[scope]!
	}

	// Handle receipt of an incoming push notification that something has changed.
	public func handleNotification(scope: CKDatabase.Scope) {
		// Pass on to internal handler
		fetchDatabaseChanges(scope: scope)
	}

	// MARK: - Private Methods
	private func getChangeTokenKey(scope: CKDatabase.Scope, zone: String = "") -> String {
		var key = ""
		if zone.isEmpty {
			switch scope {
			case .private:
				key = "PrivateDatabaseServerChangeToken"

			case .public:
				key = "PublicDatabaseServerChangeToken"

			case .shared:
				key = "SharedDatabaseServerChangeToken"

			@unknown default:
				fatalError()
			}
		} else {
			key = zone + "ZoneChangeToken"
		}
		return key
	}

	private func getToken(scope: CKDatabase.Scope, zone: String = "") -> CKServerChangeToken? {
		let key = getChangeTokenKey(scope: scope, zone: zone)
		guard let data = def.value(forKey: key) as? Data else {
			return nil
		}
		guard let token = try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: data) else {
			return nil
		}
		return token
	}

	private func setToken(scope: CKDatabase.Scope, zone: String = "", token: CKServerChangeToken?) {
		let key = getChangeTokenKey(scope: scope, zone: zone)
		if let token = token {
			if let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true) {
				def.set(data, forKey: key)
			}
		} else {
			def.removeObject(forKey: key)
		}
	}

	private func getSubscriptionKey(scope: CKDatabase.Scope) -> String {
		switch scope {
		case .private:
			return "PrivateDatabaseSubscriptionSaved"

		case .public:
			return "PublicDatabaseSubscriptionSaved"

		case .shared:
			return "SharedDatabaseSubscriptionSaved"

		@unknown default:
			fatalError()
		}
	}

	private func alreadySubscribed(scope: CKDatabase.Scope) -> Bool {
		let key = getSubscriptionKey(scope: scope)
		return def.bool(forKey: key)
	}

	private func setSubscribed(scope: CKDatabase.Scope) {
		let key = getSubscriptionKey(scope: scope)
		def.setValue(true, forKey: key)
	}

	private func getSubscriptionID(scope: CKDatabase.Scope) -> String {
		switch scope {
		case .private:
			return "\(subscriptionPrefix)-private-changes"

		case .public:
			return "\(subscriptionPrefix)-public-changes"

		case .shared:
			return "\(subscriptionPrefix)-shared-changes"

		@unknown default:
			fatalError()
		}
	}

	// Create the CloudKit subscription we’ll use to receive notification of changes. The SubscriptionID lets us identify when an incoming notification is associated with the query we created.
	private func saveSubscription(scope: CKDatabase.Scope) {
		// Have we already subscribed?
		if alreadySubscribed(scope: scope) {
			return
		}
		let subscriptionID = getSubscriptionID(scope: scope)
		// Get notified of all DB changes
		let subscription = CKDatabaseSubscription(subscriptionID: subscriptionID)
		// We set shouldSendContentAvailable to true to indicate we want CloudKit to use silent pushes, which won’t bother the user (and which don’t require user permission.)
		let notificationInfo = CKSubscription.NotificationInfo()
		notificationInfo.shouldSendContentAvailable = true
		subscription.notificationInfo = notificationInfo
		let operation = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription], subscriptionIDsToDelete: [])
		operation.modifySubscriptionsResultBlock = { result in
			switch result {
			case .failure(let error):
				NSLog("Error modifying subscription: \(error)")
				
			case .success:
				self.setSubscribed(scope: scope)
			}
		}
		dbFor(scope: scope).add(operation)
	}

	private func getRecord(name: String) -> SQLTable? {
		let bm = Bundle.main
		let ns = (bm.infoDictionary!["CFBundleExecutable"] as! String).replacingOccurrences(of: " ", with: "_")
		if let fc = bm.classNamed("\(ns).\(name)") as? SQLTable.Type {
			let rec = fc.init()
			return rec
		}
		return nil
	}

	private func fetchDatabaseChanges(scope: CKDatabase.Scope) {
		let db = dbFor(scope: scope)
		let changeToken = getToken(scope: scope)
		var changedZoneIDs = [CKRecordZone.ID]()
		let operation = CKFetchDatabaseChangesOperation(previousServerChangeToken: changeToken)
		operation.fetchAllChanges = true
		operation.recordZoneWithIDChangedBlock = { zoneID in
			changedZoneIDs.append(zoneID)
		}
		operation.recordZoneWithIDWasDeletedBlock = {(zoneID) in
			// Do we need to handle zone deletions?
			NSLog("Zone was deleted: \(zoneID)")
		}
		operation.recordZoneWithIDWasPurgedBlock = {(zoneID) in
			// Do we need to handle zone purges?
			NSLog("Zone was purged: \(zoneID)")
		}
		operation.changeTokenUpdatedBlock = { token in
			self.setToken(scope: scope, token: token)
		}
		operation.fetchDatabaseChangesResultBlock = { result in
			switch result {
			case .failure(let error):
				NSLog("Error during fetching database changes: \(error)")
				
			case .success(let (token, _)):
				// Flush zone deletions for this database to disk
				self.setToken(scope: scope, token: token)
				if changedZoneIDs.count > 0 {
					self.fetchZoneChanges(database: db, zoneIDs: changedZoneIDs)
				}
			}
		}
		operation.qualityOfService = .userInitiated
		dbFor(scope: scope).add(operation)
	}

	private func fetchZoneChanges(database: CKDatabase, zoneIDs: [CKRecordZone.ID]) {
		// Collect changes and deletions
		var updates = [CKRecord]()
		var deletions = [(CKRecord.ID, CKRecord.RecordType)]()
		// Look up the previous change token for each zone
		var optionsByRecordZoneID = [CKRecordZone.ID: CKFetchRecordZoneChangesOperation.ZoneConfiguration]()
		for zoneID in zoneIDs {
			let options = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
			options.previousServerChangeToken = getToken(scope: database.databaseScope, zone: zoneID.zoneName)
			optionsByRecordZoneID[zoneID] = options
		}
		let operation = CKFetchRecordZoneChangesOperation()
		operation.configurationsByRecordZoneID = optionsByRecordZoneID
		operation.recordZoneIDs = zoneIDs
		operation.recordWasChangedBlock = { rid, result in
			switch result {
			case .failure(let error):
				NSLog("Error changing record: \(error)")
				
			case .success(let record):
				updates.append(record)
			}
		}
		operation.recordWithIDWasDeletedBlock = {(recordId, recordType) in
			deletions.append((recordId, recordType))
		}
		operation.recordZoneChangeTokensUpdatedBlock = {(zoneId, token, _) in
			self.setToken(scope: database.databaseScope, zone: zoneId.zoneName, token: token)
		}
		operation.recordZoneFetchResultBlock = { zoneID, result in
			switch result {
			case .failure(let error):
				NSLog("Error fetching zone changes: \(error)")
				
			case .success(let (token, _, _)):
				self.setToken(scope: database.databaseScope, zone: zoneID.zoneName, token: token)
			}
		}
		operation.fetchRecordZoneChangesResultBlock = { result in
			switch result {
			case .failure(let error):
				NSLog("Error fetching zone changes: \(error)")

			case .success:
				var types = Set<String>()
				// Handle changes
				NSLog("Processing: \(updates.count) updates")
				for record in updates {
					let type = record.recordType
					types.insert(type)
					if let rec = self.getRecord(name: record.recordType) {
						rec.cloudLoad(record: record)
						_ = rec.save(updateCloud: false)
					}
				}
				// Done - notify about changes
				for type in types {
					let name = Notification.Name(type + "DataChangedNotification")
					NSLog("*** Notifying for: \(name)")
					DispatchQueue.main.async {
						NotificationCenter.default.post(name: name, object: nil)
					}
				}
				NSLog("Processing: \(deletions.count) deletions")
				for (recordId, recordType) in deletions {
					types.insert(recordType)
					guard let pid = Int(recordId.recordName) else { return }
					if let rec = self.getRecord(name: recordType) {
						rec.setValue(pid, forKey: rec.primaryKey)
						_ = rec.delete(updateCloud: false, force: true)
					}
				}
				// Done - notify about changes
				for type in types {
					let name = Notification.Name(type + "DataChangedNotification")
					NSLog("*** Notifying for: \(name)")
					DispatchQueue.main.async {
						NotificationCenter.default.post(name: name, object: nil)
					}
				}
			}
		}
		database.add(operation)
	}
}
