Pod::Spec.new do |spec|
  spec.name         = 'Embassy'
  spec.version      = '3.0.0'
  spec.summary      = 'Lightweight async HTTP server in pure Swift for iOS/macOS UI Automatic testing data mocking'
  spec.homepage     = 'https://github.com/envoy/Embassy'
  spec.license      = 'MIT'
  spec.license      = { type: 'MIT', file: 'LICENSE' }
  spec.author             = { 'Victor' => 'victor@envoy.com' }
  spec.social_media_url   = 'http://twitter.com/victorlin'
  spec.ios.deployment_target = '8.0'
  spec.osx.deployment_target = '10.10'
  spec.source       = {
    git: 'https://github.com/envoy/Embassy.git',
    tag: "v#{spec.version}"
  }
  spec.source_files = 'Embassy/**.swift', 'Embassy/**/*.swift'
end
