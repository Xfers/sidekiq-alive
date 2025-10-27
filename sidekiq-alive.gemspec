lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'sidekiq_alive/version'

Gem::Specification.new do |spec|
  spec.name          = 'sidekiq-alive'
  spec.version       = SidekiqAlive::VERSION
  spec.authors       = ['Artur Pañach', 'Arlo Liu', 'Eshton Robateau']
  spec.email         = ['arturictus@gmail.com', 'arlo.liu@fazzfinancial.com', 'eshton.robateau@fazzfinancial.com']

  spec.summary       = 'Liveness probe for sidekiq on Kubernetes deployments.'
  spec.description   = 'SidekiqAlive offers a solution to add liveness probe of a Sidekiq instance.

  How?

  A http server is started and on each requests validates that a liveness key is stored in Redis. If it is there means is working.

  A Sidekiq job is the responsable to storing this key. If Sidekiq stops processing jobs
  this key gets expired by Redis an consequently the http server will return a 500 error.

  This Job is responsible to requeue itself for the next liveness probe.'
  spec.homepage      = 'https://github.com/Xfers/sidekiq_alive'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '> 1.16'
  spec.add_development_dependency 'mock_redis'
  spec.add_development_dependency 'rack-test'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rspec-sidekiq', '> 5'
  spec.add_dependency 'sidekiq', '> 7'
  spec.add_dependency 'falcon'
  spec.add_dependency 'rack'
  spec.add_dependency 'rackup'
end
