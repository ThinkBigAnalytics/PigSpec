# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "pig-spec/version"

Gem::Specification.new do |s|
  s.name = "pig-spec"
  s.version = PigSpec::VERSION
  s.authors = ["Matt Martin"]
  s.email = ["matt [dot] martin [at] thinkbiganalytics [dot] com"]
  s.homepage = "http://www.thinkbiganalytics.com/"
  s.summary = %q{PigSpec is a PigUnit-like program implemented in Ruby.}
  s.description = %q{PigSpec is a PigUnit-like program implemented in Ruby. It can be easily included into RSpec for running integration tests of existing Pig scripts.}

  s.files = `git ls-files`.split("\n")
  s.test_files = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_development_dependency "rspec"
end