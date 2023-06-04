//
//  CKError-Extras.swift
//  SQLiteDB
//
//  Created by Fahim Farook on 23-10-2020.
//  Copyright © 2020 RookSoft Ltd. All rights reserved.
//

import CloudKit

extension CKError {
	public func isRecordNotFound() -> Bool {
		isZoneNotFound() || isUnknownItem()
	}

	public func isZoneNotFound() -> Bool {
		isSpecificErrorCode(code: .zoneNotFound)
	}

	public func isUnknownItem() -> Bool {
		isSpecificErrorCode(code: .unknownItem)
	}

	public func isConflict() -> Bool {
		isSpecificErrorCode(code: .serverRecordChanged)
	}

	public func isSpecificErrorCode(code: CKError.Code) -> Bool {
		var match = false
		if self.code == code {
			match = true
		} else if self.code == .partialFailure {
			// This is a multiple-issue error. Check the underlying array
			// of errors to see if it contains a match for the error in question.
			guard let errors = partialErrorsByItemID else {
				return false
			}
			for (_, error) in errors {
				if let cke = error as? CKError {
					if cke.code == code {
						match = true
						break
					}
				}
			}
		}
		return match
	}

	// ServerRecordChanged errors contain the CKRecord information
	// for the change that failed, allowing the client to decide
	// upon the best course of action in performing a merge.
	public func getMergeRecords() -> (CKRecord?, CKRecord?) {
		if code == .serverRecordChanged {
			// This is the direct case of a simple serverRecordChanged Error.
			return (clientRecord, serverRecord)
		}
		guard code == .partialFailure else {
			return (nil, nil)
		}
		guard let errors = partialErrorsByItemID else {
			return (nil, nil)
		}
		for (_, error) in errors {
			if let cke = error as? CKError {
				if cke.code == .serverRecordChanged {
					// This is the case of a serverRecordChanged Error
					// contained within a multi-error PartialFailure Error.
					return cke.getMergeRecords()
				}
			}
		}
		return (nil, nil)
	}
}
