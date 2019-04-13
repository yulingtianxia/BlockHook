Pod::Spec.new do |s|
s.name         = "BlockHook"
s.version      = "1.1.3"
s.summary      = "Hook Objective-C blocks."
s.description  = <<-DESC
Hook Objective-C blocks with libffi. It's a powerful AOP tool for blocks. BlockHook can run your code before/instead/after invoking a block. BlockHook can even notify you when a block dealloc. You can trace the whole lifecycle of a block using BlockHook!
DESC
s.homepage     = "https://github.com/yulingtianxia/BlockHook"

s.license = { :type => 'MIT', :file => 'LICENSE' }
s.author       = { "yulingtianxia" => "yulingtianxia@gmail.com" }
s.social_media_url = 'https://twitter.com/yulingtianxia'
s.source       = { :git => "https://github.com/yulingtianxia/BlockHook.git", :tag => s.version.to_s }

s.ios.deployment_target = "8.0"
s.osx.deployment_target = "10.7"
s.tvos.deployment_target = "9.0"
s.requires_arc = true

s.ios.vendored_frameworks = "universal/iOS/BlockHookKit.framework"
s.tvos.vendored_frameworks = "universal/tvOS/BlockHookKit.framework"
s.osx.vendored_frameworks = "universal/macOS/BlockHookKit.framework"

end

