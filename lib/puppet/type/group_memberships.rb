require 'puppet/parameter/boolean'
Puppet::Type.newtype(:group_memberships) do
  desc "Adding user to existing system groups. Do nothing if group does not exist."
  @doc = "Adding user to existing system groups. Do nothing if group does not exist."

  ensurable do
    desc "Create or remove the group."
    defaultvalues
    defaultto :present
  end
        
  # Auto require
  autorequire(:user) do
      self[:name]
  end
    
  # Autorequire the group, if it's around
  autorequire(:group) do
    self[:groups]
  end
    
  newparam(:name, :namevar => true) do
      desc "The name of the user."
  end
    
  newparam(:purge) do
    desc "Whether we have to remove groups memberships that are not defined. Defaults to false."
    defaultto :false
  end
    
  newproperty(:groups, :array_matching => :all) do
    desc "Groups that we need to add to the user if they exists."

    # Validate the values
    validate do |value|
      if value =~ /^\d+$/ or value.is_a? Integer
        raise ArgumentError, "Group names must be provided, not GID numbers."
      end
      raise ArgumentError, "Group names must be provided as an array, not a comma-separated list." if value.include?(",")
      raise ArgumentError, "Group names must not be empty. If you want to specify \"no groups\" pass an empty array" if value.empty?
    end
    
    # Check values and delete does who are not correct, will result in nil values in the array
    munge do |value|
      raise Puppet::Error, "Provider does not provide group_munge? function!" if !provider.respond_to?(:group_munge?)
      value if !provider.group_munge?(value, resource)
    end
    
    # Check if the current and should situation is in sync
    def insync?(current)
      if provider.respond_to?(:membership_insync?)
        return provider.membership_insync?(current, @should, resource)
      else
        raise Puppet::Error, "Provider does not provide membership_insync? function!"      
      end

      super(current)
    end
    
    # This function is used to print the change message.
    def change_to_s(currentvalue, newvalue)
      newvalue = newvalue.concat(currentvalue) if (!resource[:purge]) 
      newvalue = newvalue.compact.uniq.sort
      currentvalue = currentvalue.compact.uniq.sort
      super(currentvalue, newvalue)
    end
    
    def is_to_s(value)
      value.compact.uniq.sort.inspect
    end
    alias :should_to_s :is_to_s
    
  end
end
