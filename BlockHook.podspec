Pod::Spec.new do |s|
s.name         = "BlockHook"
s.version      = "1.0.0"
s.summary      = "Hook Objective-C block with libffi."
s.description  = <<-DESC
You can hook a block using 4 modes (before/instead/after/dead). This method returns a `BHToken` instance for more control. You can `remove` a `BHToken`, or set custom return value to its `retValue` property.
DESC
s.homepage     = "https://github.com/yulingtianxia/BlockHook"

s.license = { :type => 'MIT', :file => 'LICENSE' }
s.author       = { "YangXiaoyu" => "yulingtianxia@gmail.com" }
s.social_media_url = 'https://twitter.com/yulingtianxia'
s.source       = { :git => "https://github.com/yulingtianxia/BlockHook.git", :tag => s.version.to_s }

s.ios.deployment_target = "6.0"
s.osx.deployment_target = "10.7"
s.tvos.deployment_target = "9.0"
s.requires_arc = true

s.source_files = "BlockHook/*.{h,m}"
s.public_header_files = "BlockHook/BlockHook.h"
s.frameworks = 'Foundation'

end
