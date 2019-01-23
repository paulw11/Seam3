Seam3 Changelog
===============

# [1.5.4]
 - Fix concurrency issue with reseting backing store

# [1.5.3]
 - Fix missing version number for Carthage (#99)

# [1.5.2]
 - Fix examples for Carthage

# [1.5.1]
 - Update to Swift 4.2
 - Fix isssues with non-iOS examples (#104)
 - Make completion handler for `handlePush` optional

# [1.4.9]
 - Updates to example app
 - Use flexible logging via os_log
 - Address issues with concurrent access (Potential crashes)
 - Address issues with handling for server change token that caused issues with sync
 - Fix error in readme (#100)

# [1.4.8]
 - Include platforms in example pod file
 - Update osx minimum version

# [1.4.7]
 - Update to Swift 4.2
 - Add support for WatchOS
 - Add shared schemes for Carthage

# [1.4.6]
 - Handle purged zone in CloudKit

# [1.4.5]
 - Add support for batch deletes
 - Add Carthage support

# [1.4.4]
 - Include migration fixes
 - Include predicate creation fixes

# [1.4.3]
 - Include the ability to import object graphs
 - Fix #37 - Provide new functions for retrieving predicates that search relationships
 - Fix #45 - Ensure migration works by using a fixed store identifier in metadata
 - Swift 4.0 support

# [1.3.1]
 - Fix #32 - Conflict resolution issues
 - Fix #27 - Superfluous logging of conflicts that will be resolved by the framework
 - New example code and documentation on conflict resolution

# [1.2.6]
 - Fix documentation for iOS 9

# [1.2.5]
 - Not released

# [1.2.4]
 - Fix infinite loop when reference is missing in cloudkit - #29
 - Include `Error` in sync complete notification `userInfo`
 - Add description of sync errors

# [1.2.3]
 - Fix crash when `count` is invoked against a seam3 backed `NSManagedObjectContext` - Fix #20
 - Fix potential crash due to a race condition with a remotely deleted object Fix #21
 - Dont' set alert body in the `CKNotification` - Fix #19
# [1.2.2]
 - Change `registerStore()` to `registerStoreClass()`

# [1.2.1]
 - Fix warnings under Swift 3.1
 - You must now call `SMStore.registerStore()` before attempting to create an SMStore

# [1.1.5]
 - Fixed a bug with assigning the incorrect entity to to-one related objects

# [1.1.4]
 - Address an issue with the handling of empty relationships 

# [1.1.3]
 - Correctly create zone and subscription for new zone

# [1.1.2]
 - Improve sync when concurrent changes occur

# [1.1.1]
 - Add TVOS support and example

# [1.1.0]
 - Add option to specify a CloudKit container - This allows sharing containers between targets (e.g. iOS and Mac OS)
 - Add Mac OS 10.11 (and later) support
 - Include sample Mac OS app

# [1.0.7]
 - Return current user identifier from CloudKit check
 - Provide ability to remove all existing data from the local store
 - Add user id check to `verifyCloudKitConnection`

# [1.0.6]
 - Check for Cloud Kit login before syncing; fix #3
 - Check for deleted record when resolving conflicts; fix #4

# [1.0.5]

 - Add optional parameter to `triggerSync` to force complete sync with CloudKit data
 - Core Data attributes that are enabled for *allows external storage* will be stored as `CKAssets` in Cloud Kit

# [1.0.4]

 - First release

