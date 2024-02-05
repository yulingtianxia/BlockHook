Pod::Spec.new do |s|
s.name         = "BlockHook"
s.version      = "1.5.12"
s.summary      = "Hook Objective-C blocks."
s.description  = <<-DESC
Hook Objective-C blocks with libffi. It's a powerful AOP tool for blocks. BlockHook can run your code before/instead/after invoking a block. BlockHook can even notify you when a block dealloc. You can trace the whole lifecycle of a block using BlockHook!
DESC
s.homepage     = "https://github.com/yulingtianxia/BlockHook"

s.license = { :type => 'MIT', :file => 'LICENSE' }
s.author       = { "yulingtianxia" => "yulingtianxia@gmail.com" }
s.social_media_url = 'https://twitter.com/yulingtianxia'
s.source       = { :git => "https://github.com/yulingtianxia/BlockHook.git", :tag => s.version.to_s }

s.source_files = "BlockHook/*.{h,m}"
s.public_header_files = "BlockHook/BlockHook.h", "BlockHook/BHToken.h", "BlockHook/BHInvocation.h"
s.static_framework = true
s.pod_target_xcconfig = {
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64'
}
s.requires_arc = true

s.ios.deployment_target = "12.0"
s.osx.deployment_target = "10.13"
# s.tvos.deployment_target = "12.0"
# s.watchos.deployment_target = "4.0"

s.ios.vendored_frameworks = "libffi.xcframework"
s.osx.vendored_frameworks = "libffi.xcframework"
# s.tvos.vendored_frameworks = "libffi.xcframework"
# s.watchos.vendored_frameworks = "libffi.xcframework"

end

