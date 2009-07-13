#Configuration needed for plugin to function
config.gem 'json'
config.gem 'rubyzip', :lib => 'zip/zipfilesystem'

require "acts_as_device_aware"
require 'device_atlas'

ActionController::Base.send(:include, ActsAsDeviceAware::ActionControllerExtensions)


