
Pod::Spec.new do |spec|
  spec.name         = "TFY_RouterMessageKit"

  spec.version      = "2.0.0"

  spec.summary      = "组件化路由，消息监听，封装好的工具"

  spec.description  = <<-DESC
  组件化路由，消息监听，封装好的工具
                   DESC

  spec.homepage     = "http://EXAMPLE/TFY_RouterMessageKit"
  
  spec.license      = "MIT"
  
  spec.author       = { "田风有" => "420144542@qq.com" }
  
  spec.platform     = :ios, "10.0"

  spec.source       = { :git => "http://EXAMPLE/TFY_RouterMessageKit.git", :tag => spec.version }

  spec.source_files  = "TTFY_MessageMKit/TFY_RouterMessageKit/TFY_RouterMessageKit.h"
  
  spec.subspec 'TFY_MessageMKit' do |ss|
    ss.source_files  = "TFY_MessageMKit/TFY_RouterMessageKit/TFY_MessageMKit/**/*.{h,m}"
  end

  spec.subspec 'TFY_RouterMKit' do |ss|
    ss.source_files  = "TFY_MessageMKit/TFY_RouterMessageKit/TFY_RouterMKit/**/*.{h,m}"
  end

  spec.frameworks    = "Foundation","UIKit"

  spec.xcconfig      = { "HEADER_SEARCH_PATHS" => "$(SDKROOT)/usr/include" }
  
  spec.requires_arc = true

end
