Pod::Spec.new do |s|
s.name         = "BlockHook"
s.version      = "1.2.12"
s.summary      = "Hook Objective-C blocks."
s.description  = <<-DESC
Hook Objective-C blocks with libffi. It's a powerful AOP tool for blocks. BlockHook can run your code before/instead/after invoking a block. BlockHook can even notify you when a block dealloc. You can trace the whole lifecycle of a block using BlockHook!
DESC
s.homepage     = "https://github.com/yulingtianxia/BlockHook"

s.license = { :type => 'MIT', :file => 'LICENSE' }
s.author       = { "yulingtianxia" => "yulingtianxia@gmail.com" }
s.social_media_url = 'https://twitter.com/yulingtianxia'
s.source       = { :git => "https://github.com/yulingtianxia/BlockHook.git", :tag => s.version.to_s }

s.source_files = "BlockHook/*.{h,m}", "libffi/*.h"
s.public_header_files = "BlockHook/*.h"

s.ios.deployment_target = "8.0"
s.osx.deployment_target = "10.8"
#s.tvos.deployment_target = "9.0"
#s.watchos.deployment_target = "1.0"
s.requires_arc = true

s.ios.vendored_libraries = "libffi/libffi.a"
s.osx.vendored_libraries = "libffi/libffi.a"
#s.tvos.vendored_libraries = "libffi/libffi.a"
#s.watchos.vendored_libraries = "libffi/libffi.a"

end

