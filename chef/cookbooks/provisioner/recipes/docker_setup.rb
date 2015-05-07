# Copyright 2011, Dell
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
#

api_server = node['crowbar']['api']['servers'].first['url'],
proxy = node['crowbar']['proxy']['servers'].first['url'],
tftproot = node["crowbar"]["provisioner"]["server"]["root"]
node_dir="#{tftproot}/nodes"
node.normal["crowbar_wall"] ||= Mash.new
node.normal["crowbar_wall"]["docker"] ||= Mash.new
node.normal["crowbar_wall"]["docker"]["clients"] ||= Mash.new

# Split out the v4 addresses
v4dns, v6dns = node["crowbar"]["dns"]["nameservers"].collect{|a|IP.coerce(a)}.partition{|a|a.v4?}
v4addresses = v4dns.collect{|a|a.addr}

(node["crowbar"]["docker"]["clients"] || {} rescue {}).each do |name,info|
  # Generate an appropriate crowbar init for the system
  directory "#{node_dir}/#{name}" do
    action :create
    recursive true
  end
  template "#{node_dir}/#{name}/crowbar-init" do
    source "docker-node.sh.erb"
    mode 0755
    variables(:addresses => info["addresses"],
              :image => info["image"],
              :dns_servers => v4addresses,
              :name => name,
              :proxy => proxy,
              :keys => (node["crowbar"]["access_keys"] rescue Hash.new).values.sort.join($/),
              :admin_url => api_server
              )
  end
end
