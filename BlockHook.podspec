Pod::Spec.new do |s|
s.name         = "BlockHook"
s.version      = "1.1.0"
s.summary      = "Hook Objective-C blocks."
s.description  = <<-DESC
Hook Objective-C blocks with libffi. It's a powerful AOP tool for blocks. BlockHook can run your code before/instead/after invoking a block. BlockHook can even notify you when a block dealloc. You can trace the whole lifecycle of a block using BlockHook!
DESC
s.homepage     = "https://github.com/yulingtianxia/BlockHook"

s.license = { :type => 'MIT', :file => 'LICENSE' }
s.author       = { "yulingtianxia" => "yulingtianxia@gmail.com" }
s.social_media_url = 'https://twitter.com/yulingtianxia'
s.source       = { :git => "https://github.com/yulingtianxia/BlockHook.git", :tag => s.version.to_s }

s.platform     = :ios, '8.0'
s.requires_arc = true

s.vendored_frameworks = "BlockHookKit.framework"
# s.static_framework = true

end

