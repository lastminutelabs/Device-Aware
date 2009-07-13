require 'rubygems'
require 'json'
#
# JSON is a required rependency
#     sudo gem install JSON
#
# Used to load the recognition tree and perform lookups of all properties, or
# individual properties. Typical usage is as follows:
#
#     device_atlas = DeviceAtlas.new
#     tree = device_atlas.getTreeFromFile("sample/DeviceAtlas.json")
#     properties = device_atlas.getProperties(tree, "Nokia6680...")
#     property = device_atlas.getProperty(tree, "Nokia6680...", "displayWidth")
# 
# Note that you should normally use the user-agent that was received in
# the device's HTTP request. In a Rails environment, you would do this as follows:
# 
# 
#     user_agent = request.env['HTTP_USER_AGENT']
#     display_width = device_atlas.getPropertyAsInteger(tree, user_agent, "displayWidth")
# 
# Author:: MTLD (dotMobi)
# 
class DeviceAtlas

  class IncorrectPropertyTypeException < StandardError; end
  class InvalidPropertyException < StandardError; end
  class JsonException < StandardError; end
  class UnknownPropertyException < StandardError; end
    
  attr_accessor :found_properties, :patricia, :matched_ua, :unmatched_ua
  
  # Returns a tree from a JSON string
  def getTreeFromString(string)
    tree = JSON::Parser.new(string, :max_nesting => false).parse
    raise(JsonException, "Unable to load Json data.") if (tree.nil? || !tree.kind_of?(Hash))
    raise(JsonException, "Bad data loaded into the tree") unless tree.has_key?("$")
    raise(JsonException, "DeviceAtlas json file must be v0.7 or greater. Please download a more recent version.") if(tree["$"]["Ver"].to_f < 0.7)
    
    pr = {}
    pn = {}
    tree['p'].each_with_index do |key,value|
      pr[key] = value
      pn[key[1..key.size]] = value
    end
    tree['pr'] = pr
    tree['pn'] = pn
    self.patricia = tree
    tree
  end

  # Returns a tree from a JSON file.
	# Use an absolute path name to be sure of success if the current working directory is not clear.
  def getTreeFromFile(filename)
    json = File.open(filename,"r").readlines.to_s
    getTreeFromString(json)
  end
  
  # Returns the revision number of the tree
  def getTreeRevision(tree)
    _getRevisionFromKeyword(tree['$']["Rev"])
  end

  # Returns the revision number of this API
  def getApiRevision()
    _getRevisionFromKeyword('$Rev: 2830 $')
  end

  # Returns an array of known property names.
	# Returns all properties available for all user agents in this tree, with their data type names
  def listProperties(tree)
    types = {:s => "string", :b =>"boolean", :i =>"integer", :d =>"date", :u =>"unknown"}
    properties = {}
    tree['p'].each do |property|
      properties[property[1..property.length]] = types[property[0..0].to_sym]
    end
    properties
  end

 	# Returns an array of known properties (as strings) for the user agent
  def getProperties(tree, userAgent)
    _getProperties(tree, userAgent, false)
  end

  # Returns an array of known properties (as typed) for the user agent
  def getPropertiesAsTyped(tree, userAgent)
    _getProperties(tree, userAgent, true)
  end

  # Returns a value for the named property for this user agent
  def getProperty(tree, userAgent, property)
    _getProperty(tree, userAgent, property, false)
  end

  # Strongly typed property accessor.
	# Returns a boolean property.
	# (Throws an exception if the property is actually of another type.)
  def getPropertyAsBoolean(tree, userAgent, property)
    _propertyTypeCheck(tree, property, "b", "boolean")
    _getProperty(tree, userAgent, property, true)
  end

	# Strongly typed property accessor.
	# Returns a date property.
	# (Throws an exception if the property is actually of another type.)
  def getPropertyAsDate(tree, userAgent, property)
    _propertyTypeCheck(tree, property, "d", "date")
    _getProperty(tree, userAgent, property, true)
  end

	# Strongly typed property accessor.
	# Returns an integer property.
	# (Throws an exception if the property is actually of another type.)
  def getPropertyAsInteger(tree, userAgent, property)
    _propertyTypeCheck(tree, property, "i", "integer")
    _getProperty(tree, userAgent, property, true)
  end

  # Strongly typed property accessor.
	# Returns a string property.
	# (Throws an exception if the property is actually of another type.)
  def getPropertyAsString(tree, userAgent, property)
    _propertyTypeCheck(tree, property, "s", "string")
    _getProperty(tree, userAgent, property, true)
  end

  protected
  # Formats the SVN revision string to return a number
  def _getRevisionFromKeyword(keyword)
    keyword.gsub("$","")[5..keyword.size].strip.to_i
  end

  # Returns an array of known properties for the user agent.
	# Allows the values of properties to be forced to be strings.
  def _getProperties(tree, userAgent, typedValues)
    idProperties = []
    matched = ""
    sought = nil
    self.found_properties = {}
    
    _seekProperties(tree['t'], userAgent.strip, idProperties, sought, matched)
    properties = {}
    self.found_properties.each_pair do |id,value|
      if typedValues 
        properties[_propertyFromId(tree, id)] = _valueAsTypedFromId(tree, value, id)
      else
        properties[_propertyFromId(tree, id)] = _valueFromId(tree, value)
      end
    end
    properties["_matched"] = self.matched_ua
    properties["_unmatched"] = self.unmatched_ua
    properties
  end

  # Returns a value for the named property for this user agent.
	# Allows the value to be typed or forced as a string.
  def _getProperty(tree, userAgent, property, typedValue)    
    propertyId = _idFromProperty(tree, property)  
    idProperties = []
    sought = {}
    sought[propertyId.to_s] = 1
    matched = ""
    unmatched = ""
    self.found_properties = {}
    _seekProperties(tree['t'], userAgent.strip, idProperties, sought, matched)
    
    raise(InvalidPropertyException, "The property #{property} is invalid for the User Agent:#{userAgent}") if self.found_properties.size == 0
    
    if typedValue
      _valueAsTypedFromId(tree, self.found_properties[propertyId.to_s], propertyId)
    else
     _valueFromId(tree, self.found_properties[propertyId.to_s])
    end
  end

  # Return the coded ID for a property's name
  def _idFromProperty(tree, property)
    raise(UnknownPropertyException, "The property #{property} is not known in this tree.") unless tree['pn'].has_key?(property)
    tree['pn'][property]
  end

  # Return the name for a property's coded ID
  def _propertyFromId(tree, id)
    string = tree['p'][id.to_i]
    return if string.nil?
    string[1..string.size]
  end

  # Checks that the property is of the supplied type or throws an error.
  def _propertyTypeCheck(tree, property, prefix, typeName)
    key = prefix + property
    raise(IncorrectPropertyTypeException, "#{property} is not of type #{typeName}") unless tree['pr'].has_key?(key)
  end

  # Seek properties for a user agent within a node. 
	# This is designed to be recursed, and only externally called with the node representing the top of the tree
  def _seekProperties(node, string, properties, sought, matched)
    unmatched = string
    self.unmatched_ua = unmatched
    if node.has_key?('d')
      if (sought != nil && sought.size == 0)
        return
      end
      node['d'].each do |property,value|
        if (sought == nil || sought[property])
          self.found_properties[property.to_s] = value
          properties[property.to_i] = value
        end
        if (sought != nil) && ( !node.has_key?('m') || ( node.has_key?('m') && !node['m'].has_key?(property) ) )
          sought.delete(property)
        end
      end
    end
    if node.has_key?('c')      
      (0..string.length+1).each do |c|    
        seek = string[0..c]
        # TODO for some reason the last node is an array? handle it better?
        if node['c'].kind_of?(Hash) && node['c'][seek]
          matched += seek
          self.matched_ua = matched
          return _seekProperties(node['c'][seek], string[c+1..string.length], properties, sought, matched)
        elsif node['c'][seek.to_i]
          matched += seek
          self.matched_ua = matched
          return _seekProperties(node['c'][seek.to_i], string[c+1..string.length], properties, sought, matched)
        end
      end
    end
  end  
  
  # Returns the property value as typed
  def _valueAsTypedFromId(tree, id, propertyId)
    obj = tree['v'][id]
    case tree['p'][propertyId.to_i][0..0]
      when 's'
        return obj.to_s
      when 'b'
        return (obj.to_i == 1)
      when 'i'
        return obj.to_i
      when 'd'
        return Date.parse(obj)
    end
  end

  # Return the value for a value's coded ID
  def _valueFromId(tree, id)
    tree['v'][id]
  end

end