# Update the license key to reflect your own license.
DEVICE_ATLAS_LICENSE = "ENTER YOUR LICENSE KEY HERE"
DEVICE_ATLAS_RESOURCE = "/getJSON.php?licencekey=" + DEVICE_ATLAS_LICENSE + "&format=zip"
DEVICE_ATLAS_HOST = "deviceatlas.com"
DEVICE_ATLAS_JSON_RESOURCE_NAME  = "device_atlas.json"
DEVICE_ATLAS_JSON_RESOURCE_PATH = "lib/device_atlas/"

desc "download/update device atlas device data"
task :deviceatlas_update do
  if hasDownloadedJsonData
    if downloadDeviceData DEVICE_ATLAS_HOST, DEVICE_ATLAS_RESOURCE
      #download was sucessful
      if unzipDeviceData
        #unzip was sucessfull
      end
    end
  else
    if downloadDeviceData DEVICE_ATLAS_HOST, DEVICE_ATLAS_RESOURCE
        #download was sucessful
      if unzipDeviceData
        #unzip was sucessfull
      else
        raise "ActAsDeviceAware: No device data found and Failed to unzip data"
      end
    else
      raise "ActAsDeviceAware: No device data found and data download faild"
    end
  end
end

def hasDownloadedJsonData
  if File.exists? DEVICE_ATLAS_JSON_RESOURCE_PATH + DEVICE_ATLAS_JSON_RESOURCE_NAME
    return true
  else
    return false
  end
end

def downloadDeviceData host, resource
  require 'net/http'
  require 'open-uri'
  begin
    Net::HTTP.start(host) do |http|
      resp = http.get(resource)
      open(DEVICE_ATLAS_JSON_RESOURCE_PATH + "new.json.zip", "wb") do |file|
      file.write(resp.body)
    end
  end
  rescue Exception=>e
    return false
  end
  return true
end

def unzipDeviceData
  require 'zip/zipfilesystem'
  begin
  json_file = "lib/device_atlas/"
  Zip::ZipFile.open(DEVICE_ATLAS_JSON_RESOURCE_PATH + "new.json.zip", Zip::ZipFile::CREATE) do |zipfile|
    Zip::ZipFile.foreach(DEVICE_ATLAS_JSON_RESOURCE_PATH + "new.json.zip") do |f|
      zipfile.extract(f, DEVICE_ATLAS_JSON_RESOURCE_PATH  + f.name)
      json_file += f.name
    end
  end
  rescue Exception=>e
    puts e
    return false
  end
  File.copy(json_file, DEVICE_ATLAS_JSON_RESOURCE_PATH + DEVICE_ATLAS_JSON_RESOURCE_NAME)
  puts 'Device Atlas updated'
  File.delete(DEVICE_ATLAS_JSON_RESOURCE_PATH + "new.json.zip")
  File.delete(json_file)
  return true
end
