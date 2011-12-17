# ActAsDeviceAware
module ActsAsDeviceAware


  module ActionControllerExtensions
    def self.included(base)
          @@device_atlas = DeviceAtlas.new
          @@device_atlas_tree = @@device_atlas.getTreeFromFile("lib/device_atlas/device_atlas.json")
          base.send(:before_filter, :get_device_atlas_data)
    end

  private

    def get_device_atlas_data
      unless request.env["HTTP_USER_AGENT"].nil?
        @device_atlas_data = properties = @@device_atlas.getProperties(@@device_atlas_tree, request.env["HTTP_USER_AGENT"].strip)
      end
      #In case the header could not be decoded, set device_data to an empty hash.
      if @device_atlas_data.nil?
        @device_atlas_data = {}
      end
    end

  end


end
