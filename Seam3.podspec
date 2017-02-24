#
# Be sure to run `pod lib lint Seam3.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'Seam3'
  s.version          = '1.1.2'
  s.summary          = 'A CoreData store backed by CloudKit.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
Seam3 is a framework built to bridge gaps between CoreData and CloudKit. It handles almost all of the CloudKit hassle.
All you have to do is use it as a store type for your CoreData store. 
Local caching and sync is taken care of. 
It builds and exposes different features to facilitate and give control to the developer where it is demanded and required.

Seam3 is based on [Seam](https://github.com/nofelmahmood/Seam) by [nofelmahmood](https://github.com/nofelmahmood/)

Changes in Seam3 include:

* Corrects one-to-many and many-to-one relationship mapping between CoreData and CloudKit
* Adds mapping between binary attributes in CoreData and CKAssets in CloudKit
* Code updates for Swift 3.0
* Restructures code to eliminate the use of global variables
                       DESC

  s.homepage         = 'https://github.com/paulw11/Seam3'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'paulw' => 'paulw@wilko.me' }
  s.source           = { :git => 'https://github.com/paulw11/Seam3.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/paulwilko'

  s.ios.deployment_target = '9.0'
  s.osx.deployment_target = '10.11'
  s.tvos.deployment_target = '9.0'

  s.source_files = 'Sources/Classes/**/*'
  
  # s.resource_bundles = {
  #   'Seam3' => ['Seam3/Assets/*.png']
  # }
end
