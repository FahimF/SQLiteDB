//
//  DBManager.swift
//  SpamBGone
//
//  Created by Fahim Farook on 22-10-2020.
//  Copyright © 2020 RookSoft Ltd. All rights reserved.
//

import CloudKit
import Foundation

public protocol DBDelegate: AnyObject {
	func recordChanged(record: CKRecord)
	func recordDeleted(record: CKRecord)
}

enum RecordType: String, CaseIterable {
	case filter = "Filter", number = "PhoneNumber"
}

class DBManager {
	static let shared = DBManager()

	private let def = UserDefaults.standard
	private var delegates = [DBDelegate]()
	private let container: CKContainer
	private var dbs = [CKDatabase.Scope: CKDatabase]()

	private init() {
		// DBs, subscriptions, and fetch changes since quit
		container = CKContainer.default()
		dbs[.private] = container.privateCloudDatabase
		saveSubscription(scope: .private)
		fetchDatabaseChanges(scope: .private)
		dbs[.public] = container.publicCloudDatabase
//		saveSubscription(scope: .public)
//		fetchDatabaseChanges(scope: .public)
		dbs[.shared] = container.sharedCloudDatabase
		saveSubscription(scope: .shared)
		fetchDatabaseChanges(scope: .shared)
	}

	// MARK: - Public Methods
	public func add(delegate: DBDelegate) {
		delegates.append(delegate)
	}

	public func remove(delegate: DBDelegate) {
		if let index = delegates.firstIndex(where: {$0 === delegate}) {
			delegates.remove(at: index)
		}
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
			return "spambgone-private-changes"

		case .public:
			return "spambgone-public-changes"

		case .shared:
			return "spambgone-shared-changes"

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
		operation.modifySubscriptionsCompletionBlock = { _, _, error in
			guard error == nil else {
				return
			}
			self.setSubscribed(scope: scope)
		}
		dbFor(scope: scope).add(operation)
	}

	private func fetchDatabaseChanges(scope: CKDatabase.Scope, completion: (() -> Void)? = nil) {
		let db = dbFor(scope: scope)
		let changeToken = getToken(scope: scope)
		var changedZoneIDs: [CKRecordZone.ID] = []
		let operation = CKFetchDatabaseChangesOperation(previousServerChangeToken: changeToken)
		operation.fetchAllChanges = true
		operation.recordZoneWithIDChangedBlock = { zoneID in
			changedZoneIDs.append(zoneID)
		}
		operation.recordZoneWithIDWasDeletedBlock = { _ in
			// Write this zone deletion to memory
			fatalError()
		}
		operation.recordZoneWithIDWasPurgedBlock = { _ in
			// Probably have to fetch changes for the zone
			fatalError()
		}
		operation.changeTokenUpdatedBlock = { token in
			self.setToken(scope: scope, token: token)
		}
		operation.fetchDatabaseChangesCompletionBlock = { token, _, error in
			if let error = error {
				print("Error during fetching database changes: ", error)
				if let comp = completion {
					comp()
				}
				return
			}
			// Flush zone deletions for this database to disk
			if let token = token {
				self.setToken(scope: scope, token: token)
			}
			if changedZoneIDs.count > 0 {
				self.fetchZoneChanges(database: db, zoneIDs: changedZoneIDs) {
					if let comp = completion {
						comp()
					}
				}
			}
		}
		operation.qualityOfService = .userInitiated
		dbFor(scope: scope).add(operation)
	}

	func fetchZoneChanges(database: CKDatabase, zoneIDs: [CKRecordZone.ID], completion: @escaping () -> Void) {
		// Look up the previous change token for each zone
		var optionsByRecordZoneID = [CKRecordZone.ID: CKFetchRecordZoneChangesOperation.ZoneConfiguration]()
		for zoneID in zoneIDs {
			let options = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
			options.previousServerChangeToken = getToken(scope: database.databaseScope, zone: zoneID.zoneName)
			optionsByRecordZoneID[zoneID] = options
		}
		let operation = CKFetchRecordZoneChangesOperation()
		operation.configurationsByRecordZoneID = optionsByRecordZoneID
		operation.recordChangedBlock = {(record) in
			NSLog("Record - \(record.recordType) changed:", record)
			// TODO: Update record change
			// Bundle.main.classNamed("MyClassName")
		}
		operation.recordWithIDWasDeletedBlock = {(recordId, recordType) in
			print("Record deleted:", recordId)
			// TOOD: Update record change
		}
		operation.recordZoneChangeTokensUpdatedBlock = {(zoneId, token, _) in
			self.setToken(scope: database.databaseScope, zone: zoneId.zoneName, token: token)
		}
		operation.recordZoneFetchCompletionBlock = {(zoneId, token, _, _, error) in
			if let error = error {
				print("Error fetching zone changes:", error)
				return
			}
			self.setToken(scope: database.databaseScope, zone: zoneId.zoneName, token: token)
		}
		operation.fetchRecordZoneChangesCompletionBlock = {(error) in
			if let error = error {
				print("Error fetching zone changes:", error)
			}
			completion()
		}
		database.add(operation)
	}
}
