#
# Be sure to run `pod lib lint SafeIAP.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'SafeIAP'
  s.version          = '0.1.0'
  s.summary          = 'IAP功能'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
TODO: Add long description of the pod here.
                       DESC

  s.homepage         = 'https://gitee.com/uiop/safe-iap'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'yxkkk' => '13730228573@163.com' }
  s.source           = { :git => 'https://gitee.com/uiop/safe-iap.git', :tag => s.version.to_s }

  s.ios.deployment_target = '13.0'

  s.source_files = 'SafeIAP/Classes/**/*'
  s.swift_version = '5.0'

  # s.resource_bundles = {
  #   'SafeIAP' => ['SafeIAP/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
end
