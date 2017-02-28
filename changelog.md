Seam3 Changelog
===============

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

