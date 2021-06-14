Pod::Spec.new do |s|
  s.name         = 'SwiftSimpleCache'
  s.version      = '1.0.0'
  s.summary      = 'Simple cache'
  s.homepage     = 'https://github.com/giaynhap'
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.source       = { :git => 'https://github.com/giaynhap/GnSwiftSimpleCache.git', :tag => "#{s.version}" }
  s.author       = { 'Do Van Thuc' => 'https://github.com/giaynhap' }
  s.ios.deployment_target = '9.0'
  s.source_files = 'Sources/*.{swift}'
  s.requires_arc = true
end
