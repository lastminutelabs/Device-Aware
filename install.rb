# Install hook code here
#if !File.exists? "lib/data"
#  File.makedirs "lib/data"
#end
require 'fileutils'
here = File.dirname(__FILE__)
there = defined?(RAILS_ROOT) ? RAILS_ROOT : "#{here}/../../.."
FileUtils.mkdir_p("#{there}/lib/device_atlas")

puts "installed act as device aware plugin"
