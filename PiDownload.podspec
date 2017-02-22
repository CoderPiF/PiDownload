Pod::Spec.new do |s|
  s.name         = "PiDownload"
  s.version      = "1.0.1"
  s.summary      = "iOS / macOS 后台断点下载"
  s.homepage     = "https://coderpif.github.io"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author             = { "CoderPiF" => "CoderPiF@gmail.com" }
  s.ios.deployment_target = "7.0"
  s.osx.deployment_target = "10.9"
  s.source       = { :git => "https://github.com/CoderPiF/PiDownload.git", :tag => "#{s.version}" }
  s.source_files  = "PiDownload/**/*.{h,m}"
  s.public_header_files = "PiDownload/PiDownload.h", "PiDownload/PiDownloadLogger.h", "PiDownload/PiDownloadTask.h", "PiDownload/PiDownloader.h", "PiDownload/PiDownloadConfig.h"
  s.ios.frameworks = "UIKit"
  s.osx.frameworks = "AppKit"
  s.requires_arc = true
end
