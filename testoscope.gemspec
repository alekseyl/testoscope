
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "testoscope/version"

Gem::Specification.new do |spec|
  spec.name          = "testoscope"
  spec.version       = Testoscope::VERSION
  spec.authors       = ["alekseyl"]
  spec.email         = ["leshchuk@gmail.com"]

  spec.summary       = %q{ This is simple and nice tool to inspect how application operates with current DB structure while testing app,
                          inspecting for redundant indexes, sequential scans, dummy requests and any other unintended behaviour customized by user. }
  spec.description   = %q{This is simple and nice tool to inspect how application operates with current DB structure while testing app,
                          meaning redundant indexes, sequential scans, dummy requests and any other unintended behaviour customized by user.  }
  spec.homepage      = "https://github.com/alekseyl/testoscope"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "https://rubygems.org"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", ">= 2.2.10"
  spec.add_development_dependency  "rake", ">= 12.3.3"
  spec.add_development_dependency "minitest", "~> 5.0"

  spec.add_dependency "activerecord", ">= 4"
  spec.add_dependency "niceql", ">= 0.1.23"
end
