//
//  String-Extras.swift
//  Swift Tools
//
//  Created by Fahim Farook on 23/7/14.
//  Copyright (c) 2014 RookSoft Pte. Ltd. All rights reserved.
//

#if os(iOS)
import UIKit
#else
import AppKit
#endif

extension String {
	func positionOf(sub:String)->Int {
		var pos = -1
		if let range = self.rangeOfString(sub) {
			if !range.isEmpty {
				pos = self.startIndex.distanceTo(range.startIndex)
			}
		}
		return pos
	}
	
	func subStringFrom(pos:Int)->String {
		var substr = ""
		let start = self.startIndex.advancedBy(pos)
		let end = self.endIndex
//		println("String: \(self), start:\(start), end: \(end)")
		let range = start..<end
		substr = self[range]
//		println("Substring: \(substr)")
		return substr
	}
	
	func subStringTo(pos:Int)->String {
		var substr = ""
		let end = self.startIndex.advancedBy(pos-1)
		let range = self.startIndex...end
		substr = self[range]
		return substr
	}
	
	func urlEncoded()->String {
		let res:NSString = CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, self as NSString, nil,
			"!*'();:@&=+$,/?%#[]", CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding))
		return res as String
	}
	
	func urlDecoded()->String {
		let res:NSString = CFURLCreateStringByReplacingPercentEscapesUsingEncoding(kCFAllocatorDefault, self as NSString, "", CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding))
		return res as String
	}
	
	func range()->Range<String.Index> {
		return Range<String.Index>(start:startIndex, end:endIndex)
	}
}

