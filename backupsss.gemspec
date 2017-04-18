# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'backupsss/version'

Gem::Specification.new do |spec|
  spec.name          = 'backupsss'
  spec.version       = Backupsss::VERSION
  spec.authors       = ['Reppard Walker', 'Jonathan Niesen', 'Jason Antman']
  spec.email         = [
    'reppard.walker@manheim.com',
    'jonathan.niesen@manheim.com',
    'jason@jasonantman.com'
  ]

  spec.homepage      = 'https://github.com/manheim/backupsss'
  spec.license       = 'MIT'
  spec.summary       = 'Tar a thing and put it in S3'
  spec.description   =  [
    'Backup any file or directory as a tar and push the',
    'tar to a specificed S3 bucket.'
  ].join(' ')

  spec.files = `git ls-files -z`.split("\x0").reject { |f|
    f.match(%r{^(test|spec|features)/})
  }
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.10'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.4'
  spec.add_development_dependency 'guard', '~> 2.13'
  spec.add_development_dependency 'guard-rspec', '~> 4.6.4'
  spec.add_development_dependency 'guard-rubocop', '~> 1.2'
  spec.add_development_dependency 'guard-bundler', '~> 2.1'
  spec.add_development_dependency 'rubocop', '0.46'
  spec.add_development_dependency 'simplecov', '~> 0.11.2'
  spec.add_development_dependency 'simplecov-console', '~> 0.3.0'
  spec.add_development_dependency 'codeclimate-test-reporter', '~> 0.4'

  spec.add_runtime_dependency 'aws-sdk', '~> 2.7.0'
  spec.add_runtime_dependency 'parallel', '~> 1.10.0'
  spec.add_runtime_dependency 'rufus-scheduler', '3.4.0'
end
