# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "sanguinews/version"

Gem::Specification.new do |s|
  s.name        = "sanguinews"
  s.version     = Sanguinews::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Tadeus Dobrovolskij"]
  s.email       = ["root@tad-do.net"]
  s.homepage    = "http://www.tad-do.net"
  s.summary     = %q{Simple, commandline client for Usenet uploads}
  s.license       = 'GPLv2'
  s.description = %q{Sanguinews is a simple, commandline client for Usenet(nntp) uploads. Inspired by newsmangler. Supports multithreading and SSL.}
  s.required_ruby_version = ">= 2.0"

  s.add_runtime_dependency "speedometer", ">= 0.1.2"
  s.add_runtime_dependency "nzb", ">= 0.2.2"
  s.add_runtime_dependency "vmstat", ">= 2.1.0"
  s.add_runtime_dependency "parseconfig"
  s.add_runtime_dependency "rake-compiler"

  s.extensions << "ext/yencoded/extconf.rb"

  s.files         = `git ls-files`.split("\n")
  s.executables	  = 'sanguinews'
  s.require_paths = ["lib"]
end
