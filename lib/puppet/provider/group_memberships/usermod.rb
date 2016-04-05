Puppet::Type.type(:group_memberships).provide(:usermod) do
  desc "Manage user group memberships via usermod"

  confine :kernel => [ :Linux, :SunOS ]
  defaultfor :kernel => [ :Linux, :SunOS ]

  commands :usermod => "/usr/sbin/usermod"
  
  mk_resource_methods
  
  ###########################################################
  # Instance initialize
  ###########################################################
  def initialize(value={})
    super(value)
    @property_flush = {}
  end
  
  ###########################################################
  # Class initializing
  # This is done the first time the class is loaded
  ###########################################################
  class << self
    attr_accessor :groups
    attr_accessor :users
  end
  
  def self.initialize_class
    # Let's create a array of group & users
    # Otherwise we have to open & read /etc/group & /etc/passwd a lot!
    self.groups = []
    self.users = []
    
    # Groups
    Etc.setgrent
    Etc.group do |g|
      self.groups << g
    end
    Etc.endgrent
    
    # Users
    Etc.setpwent
    Etc.passwd do |u|
      self.users << u
    end
    Etc.endpwent
  end
  initialize_class 
  
  ###########################################################
  # Puppet Stuff
  ###########################################################
  # Build a property_hash containing all the discovered information
  def self.instances
    group_memberships = []
    Etc.setpwent
    Etc.passwd do |u|
      group_memberships << new({:name     => u.name,
          :ensure   => :present,
          :groups   => self.get_group_memberships(u)
      })
    end
    Etc.endpwent
    group_memberships
  end
  
  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name]
        resource.provider = prov
      end
    end
  end
  
  def groups=(value)
    @property_flush[:groups] = value
  end
  
  def create
    @property_flush[:ensure] = :present
  end
  
  def destroy
    @property_flush[:ensure] = :absent
  end
  
  def exists?
    if resource[:ensure] == :present
      @property_hash[:ensure] == :present
    else  
      @property_hash[:ensure] == :present && @property_hash[:groups] != nil && !@property_hash[:groups].empty?()
    end
  end
  
  def flush
    set_group_memberships   
  end
  
  def set_group_memberships
    # If ensure == absent delete ALL group_memberships
    if resource[:ensure] == :absent
      usermod(['-G', '', resource[:name]])
      return
    end
    
    # Present
    purge = resource[:purge]
    current = @property_hash[:groups]
    should = resource[:groups]
      
    should = should.concat(current) if (!purge) 
    should = should.compact.uniq.sort.join(",")
    usermod(['-G', should, resource[:name]])   
    return
  end
  
  ###########################################################
  # Puppet type stuff
  ###########################################################
  # Compare the should situation with the current situation
  def membership_insync?(current = [], should = [], resource = nil)
    current = current.compact.uniq.sort
    should = should.compact.uniq.sort
    purge = resource[:purge]
      
    if purge
      # Both arrays should match each other exactly
      if ((current - should).count == 0 && (should - current).count == 0)
        return true
      end
    else
      if ((should - current).count == 0)
        return true
      end
    end
    return false
  end
  
  # Check if the group already exists on the system
  def group_valid?(name, resource)
    self.class.groups.rindex{|g| g.name == name} != nil
  end
  
  # Check if we need to munge this value
  # We need to munge if the group is the primary group of the user (check catalog and system)
  # We need to munge if the group doesn't exists in the catalog and on the system
  def group_munge?(group, resource)
    # Check if the group is the primary group for the user
    user = resource.catalog.resources.select{|r| r.type == :user && r.name == resource[:name]}.first
    user = self.class.users.select{|u| u.name == resource[:name]}.first if user.nil?
    
    if !user.nil?
      gid = user[:gid]
      if gid.is_a?(String)
        primary = gid
        return true if primary == group
      elsif gid.is_a?(Integer)
        primary = resource.catalog.resources.select{|r| r.type == :group && r[:gid] == gid}.first
        primary = self.class.groups.select{|g| g.gid == gid}.first if primary.nil?
        return true if !primary.nil? && primary.name == group
      end
    end
    
    # Check if the group exists on the system
    if resource.catalog.resource(:group, group) != nil && resource.catalog.resource(:group, group)[:ensure] == :present
      return false
    else
      # Check if the group exists on the system
      return !group_valid?(group, resource)
    end
  end
  
  ###########################################################
  # self helper methods
  ###########################################################  
  def self.get_group_memberships(user)
    group_memberships = []
    self.groups.each do |g|
      if g.mem.include?(user.name)
        group_memberships << g.name
      end
    end
    group_memberships
  end

end
