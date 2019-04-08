Seam3 Changelog
===============
# [1.5.5]

* Improve logging of errors and activity in order to diagnose bugs and inefficiencies

* Removed dead code that was duplicated elsewhere anyway

* Fix syncing of attribute values when changing from a value to nil - Previously these changes were synced to the server, but wouldn't be applied to other clients because null values simply don't exist in CloudKit records

* Fix conflict resolution block - parameter names were in the wrong order

* Upload whole records to CloudKit, not partial (only changes) records - This is especially important since because of the changes in the previous commit we will now treat missing values as null.

* Explicitly enqueue local 'deletes' so that they are cleared after success and aren't repeated forever

* Combine multiple pending changes to the same object to minimize conflicts after being offline - For example, while offline, if you insert an object, then update it these two changes will now be combined.  When you sync to iCloud, a conflict will still occur on the second change set, but the server record will contain all the correct data and will be resolved correctly by default.

* Don't save iCloud change token until fetched server changes have been saved locally

* Handle possible errors in recordZoneFetchCompletionBlock (like .changeTokenExpired)

* Handle CKError.unknownItem (missing in Cloud) with a retry that resends the whole record to the Cloud

* Handle CKError.userDeletedZone and CKError.zoneNotFound besides just at startup time

* Add function to resend all local data to cloud in case of new user or deleted zone

* Syncing will now return a result indicating if any data was sent or received, for use with the background fetch API.

* Expose required APIs to support Objective-C

* Removed call to UserDefaults.synchronize

* Swift 5.0

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

