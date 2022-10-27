Pod::Spec.new do |spec|
  spec.name         = 'Embassy'
  spec.version      = '4.1.4'
  spec.summary      = 'Lightweight async HTTP server in pure Swift for iOS/macOS UI Automatic testing data mocking'
  spec.homepage     = 'https://github.com/envoy/Embassy'
  spec.license      = 'MIT'
  spec.license      = { type: 'MIT', file: 'LICENSE' }
  spec.author             = { 'Fang-Pen Lin' => 'fang@envoy.com' }
  spec.social_media_url   = 'https://twitter.com/fangpenlin'
  spec.ios.deployment_target = '8.0'
  spec.tvos.deployment_target = '11.0'
  spec.osx.deployment_target = '10.10'
  spec.source       = {
    git: 'https://github.com/envoy/Embassy.git',
    tag: "v#{spec.version}"
  }
  spec.source_files = 'Sources/**.swift', 'Sources/**/*.swift'
  spec.swift_versions = ['4.0']
end
