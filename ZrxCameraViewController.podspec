Pod::Spec.new do |s|
  s.name     = 'ZrxCameraViewController'
  s.version  = '1.0.0'
  s.license  =  { :type => 'MIT', :file => 'LICENSE' }
  s.summary  = 'A Swift view controller that provides live camera preview and helps you to capture photos.'
  s.homepage = 'https://github.com/ZoomRx/ZrxCameraViewController'
  s.author   = 'ZoomRx'
  s.source   = { :git => 'https://github.com/ZoomRx/ZrxCameraViewController.git', :tag => s.version }
  s.platform = :ios, '11.0'
  s.source_files = 'ZrxCameraViewController/*.{h,swift,xib}'
  s.resources = "ZrxCameraViewController/*.xcassets"
  s.swift_version = '5.0'
end
