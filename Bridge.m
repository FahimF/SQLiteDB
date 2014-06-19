//
//  Bridge.m
//  TasksGalore
//
//  Created by Fahim Farook on 15/6/14.
//  Copyright (c) 2014 RookSoft Pte. Ltd. All rights reserved.
//

#import "Bridge.h"
#import "sqlite3.h"

@implementation Bridge

+(NSString *)esc:(NSString *)str {
	if (!str || [str length] == 0) {
		return @"''";
	}
	NSString *buf = @(sqlite3_mprintf("%q", [str cStringUsingEncoding:NSUTF8StringEncoding]));
	return buf;
}

@end
