# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.  The
# ASF licenses this file to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance with the
# License.  You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
# License for the specific language governing permissions and limitations
# under the License.

class CIMI::Model::Machine < CIMI::Model::Base

  text :state
  text :cpu

  struct :memory do
    scalar :quantity
    scalar :units
  end

  href :event_log

  array :disks do
    struct :capacity do
      scalar :quantity
      scalar :units
    end
    scalar :format
    scalar :attachment_point
  end

  array :volumes do
    scalar :href
    scalar :protocol
    scalar :attachment_point
  end

  array :network_interfaces do
    href :vsp
    text :hostname, :mac_address, :state, :protocol, :allocation
    text :address, :default_gateway, :dns, :max_transmission_unit
  end

  array :meters do
    scalar :href
  end

  array :operations do
    scalar :rel, :href
  end

  def self.find(id, context)
    instances = []
    if id == :all
      instances = context.driver.instances(context.credentials)
      instances.map { |instance| from_instance(instance, context) }.compact
    else
      instance = context.driver.instance(context.credentials, :id => id)
      raise CIMI::Model::NotFound unless instance
      from_instance(instance, context)
    end
  end

  def self.create_from_json(body, context)
    json = JSON.parse(body)
    hardware_profile_id = xml['machineTemplate']['machineConfig']["href"].split('/').last
    image_id = xml['machineTemplate']['machineImage']["href"].split('/').last
    instance = context.create_instance(context.credentials, image_id, { :hwp_id => hardware_profile_id })
    from_instance(instance, context)
  end

  def self.create_from_xml(body, context)
    xml = XmlSimple.xml_in(body)
    machine_template = xml['machineTemplate'][0]
    hardware_profile_id = machine_template['machineConfig'][0]["href"].split('/').last
    image_id = machine_template['machineImage'][0]["href"].split('/').last
    additional_params = {}
    additional_params[:name] =xml['name'][0] if xml['name']
    if machine_template.has_key? 'machineAdmin'
      additional_params[:keyname] = machine_template['machineAdmin'][0]["href"].split('/').last
    end
    instance = context.driver.create_instance(context.credentials, image_id, {
      :hwp_id => hardware_profile_id
    }.merge(additional_params))
    from_instance(instance, context)
  end

  def perform(action, context, &block)
    begin
      if context.driver.send(:"#{action.name}_instance", context.credentials, self.name)
        block.callback :success
      else
        raise "Operation failed to execute on given Machine"
      end
    rescue => e
      block.callback :failure, e.message
    end
  end

  def self.delete!(id, context)
    context.driver.destroy_instance(context.credentials, id)
  end

  def self.create_entity_metadata(context)
    cimi_entity = self.name.split("::").last
    metadata = CIMI::Model::EntityMetadata.metadata_from_deltacloud_features(cimi_entity, :instances, context)
    unless metadata.includes_attribute?(:name)
      metadata.attributes << {:name=>"name", :required=>"false",
                   :constraints=>"Determined by the cloud provider", :type=>"xs:string"}
    end
    metadata
  end

  def self.attach_volumes(volumes, context)
    volumes.each do |vol|
      context.driver.attach_storage_volume(context.credentials,
      {:id=>vol[:volume].name, :instance_id=>context.params[:id], :device=>vol[:attachment_point]})
    end
    self.find(context.params[:id], context)
  end

  def self.detach_volumes(volumes, context)
    volumes.each do |vol|
      context.driver.detach_storage_volume(context.credentials, {:id=>vol[:volume].name, :instance_id => context.params[:id]})
    end
    self.find(context.params[:id], context)
  end

  private

  def self.from_instance(instance, context)
    cpu =  memory = disks = (instance.instance_profile.id == "opaque")? "n/a" : nil
    self.new(
      :name => instance.id,
      :description => instance.name,
      :created => instance.launch_time,
      :id => context.machine_url(instance.id),
      :state => convert_instance_state(instance.state),
      :cpu => cpu || convert_instance_cpu(instance.instance_profile, context),
      :memory => memory || convert_instance_memory(instance.instance_profile, context),
      :disks => disks || convert_instance_storage(instance.instance_profile, context),
      :network_interfaces => convert_instance_addresses(instance),
      :operations => convert_instance_actions(instance, context),
      :volumes=>convert_storage_volumes(instance, context),
      :property => convert_instance_properties(instance, context)
    )
  end

  # FIXME: This will convert 'RUNNING' state to 'STARTED'
  # which is defined in CIMI (p65)
  #
  def self.convert_instance_state(state)
    ('RUNNING' == state) ? 'STARTED' : state
  end

  def self.convert_instance_properties(instance, context)
    properties = []
    properties << { :name => :machine_image, :value => context.machine_image_url(instance.image_id) }
    if instance.respond_to? :keyname
      properties << { :name => :machine_admin, :value => context.machine_admin_url(instance.keyname) }
    end
    properties
  end

  def self.convert_instance_cpu(profile, context)
    cpu_override = profile.overrides.find { |p, v| p == :cpu }
    if cpu_override.nil?
      CIMI::Model::MachineConfiguration.find(profile.id, context).cpu
    else
      cpu_override[1]
    end
  end

  def self.convert_instance_memory(profile, context)
    machine_conf = CIMI::Model::MachineConfiguration.find(profile.name, context)
    memory_override = profile.overrides.find { |p, v| p == :memory }
    {
      :quantity => memory_override.nil? ? machine_conf.memory[:quantity] : memory_override[1],
      :units => machine_conf.memory[:units]
    }
  end

  def self.convert_instance_storage(profile, context)
    machine_conf = CIMI::Model::MachineConfiguration.find(profile.name, context)
    storage_override = profile.overrides.find { |p, v| p == :storage }
    [
      { :capacity => {
          :quantity => storage_override.nil? ? machine_conf.disks.first[:capacity][:quantity] : storage_override[1],
          :units => machine_conf.disks.first[:capacity][:units]
        }
      }
    ]
  end

  def self.convert_instance_addresses(instance)
    (instance.public_addresses + instance.private_addresses).collect do |address|
      {
        :hostname => address.is_hostname? ? address : nil,
        :mac_address => address.is_mac? ? address : nil,
        :state => 'Active',
        :protocol => 'IPv4',
        :address => address.is_ipv4? ? address : nil,
        :allocation => 'Static'
      }
    end
  end

  def self.convert_instance_actions(instance, context)
    instance.actions.collect do |action|
      action = :destroy if action == :delete # In CIMI destroy operation become delete
      action = :restart if action == :reboot  # In CIMI reboot operation become restart
      { :href => context.send(:"#{action}_machine_url", instance.id), :rel => "http://www.dmtf.org/cimi/action/#{action}" }
    end
  end

  def self.convert_storage_volumes(instance, context)
    instance.storage_volumes ||= [] #deal with nilpointers
    instance.storage_volumes.map{|vol| {:href=>context.volume_url(vol.keys.first),
                                       :attachment_point=>vol.values.first} }
  end

end
