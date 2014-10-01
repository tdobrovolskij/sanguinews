# Rakefile

require 'rake/extensiontask'
spec = Gem::Specification.load('sanguinews.gemspec')
Rake::ExtensionTask.new('yencoded', spec) do |extension|
  extension.lib_dir = 'lib/sanguinews'
end
