Pod::Spec.new do |s|
  s.name         = 'OptimizedNetworking'
  s.version      = '1.0.0'
  s.summary      = 'Optimal download features using NSOperations'
  s.homepage     = "http://www.smallsharptools.com/"
  s.license      = 'MIT'
  s.author = {
    'Brennan Stehling' => 'brennan@smallsharptools.com'
  }
  s.source = {
    :git => 'https://github.com/brennanMKE/OptimizedNetworking.git',
    :tag => '1.0.0'
  }
  s.social_media_url = 'https://twitter.com/smallsharptools'
  s.platform     = :ios, '7.0'
  s.ios.deployment_target = '7.0'
  s.requires_arc = true
  s.source_files = 'Networking/*.{h,m}'
end
