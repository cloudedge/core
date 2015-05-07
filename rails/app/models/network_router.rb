# Copyright 2013, Dell
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

class NetworkRouter < ActiveRecord::Base

  validate    :router_is_sane
  before_save :infer_address
  after_commit :on_change_hooks
  
  belongs_to     :network

  def address
    IP.coerce(read_attribute("address"))
  end

  def address=(addr)
    write_attribute("address",IP.coerce(addr).to_s)
  end

  def as_json(options)
    {id: id, network_id: network_id, address: address.to_s, pref: pref, created_at: created_at, updated_at: updated_at}
  end

  private

  def infer_address
    if read_attribute("address").nil?
      write_attribute("address", network.network_ranges.first.first)
    end
  end

  # Call the on_network_change hooks.
  def on_change_hooks
    # do the low cohorts last
    Rails.logger.info("NetworkRouter: calling all role on_network_change hooks for #{network.name}")
    Role.all_cohorts_desc.each do |r|
      begin
        Rails.logger.info("NetworkRouter: Calling #{r.name} on_network_change for #{self.network.name}")
        r.on_network_change(self.network)
      rescue Exception => e
        Rails.logger.error "NetworkRouter #{self.name} attempting to change role #{r.name} failed with #{e.message}"
      end
    end
  end


  def router_is_sane
    # A router is sane when its address is in a subnet covered by one of its ranges
# TODO this is broken, but needs to be fixed
#    unless !address.nil? and network.ranges.any?{|r|r.first.subnet === address}
#      errors.add("Router #{address.to_s} is not any range for #{network.name}")
#    end
  end
end

  
