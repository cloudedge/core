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
#

action :add do
  os = "#{new_resource.distro}-#{new_resource.version}"
  proxy = node["crowbar"]["proxy"]["servers"].first["url"]
  repos = node["crowbar"]["provisioner"]["server"]["repositories"][os]
  params = node["crowbar"]["provisioner"]["server"]["boot_specs"][os]
  online = node["crowbar"]["provisioner"]["server"]["online"]
  tftproot = node["crowbar"]["provisioner"]["server"]["root"]
  provisioner_web = node["crowbar"]["provisioner"]["server"]["webservers"].first["url"]
  api_server=node['crowbar']['api']['servers'].first["url"]
  ntp_server = "#{node["crowbar"]["ntp"]["servers"].first}"
  use_local_security = node["crowbar"]["provisioner"]["server"]["use_local_security"]
  install_url=node["crowbar"]["provisioner"][""]
  keys = node["crowbar"]["access_keys"].values.sort.join($/)
  machine_key = node["crowbar"]["machine_key"]
  os_dir = "#{tftproot}/#{os}"
  mnode_name = new_resource.name
  node_dir = "#{tftproot}/nodes/#{mnode_name}"
  web_path = "#{provisioner_web}/nodes/#{mnode_name}"
  crowbar_repo_web="#{web_path}/crowbar-extra"
  admin_web="#{web_path}/install"
  append = "ksdevice=bootif ks=#{web_path}/compute.ks #{params["kernel_params"]} crowbar.fqdn=#{mnode_name} crowbar.install.key=#{machine_key}"
  v4addr = new_resource.address

  directory node_dir do
    action :create
    recursive true
  end

  template "#{node_dir}/compute.ks" do
    mode 0644
    source "compute.ks.fedora-20.erb"
    owner "root"
    group "root"
    variables(:os_install_site => params[:os_install_site],
              :name => mnode_name,
              :proxy => proxy,
              :repos => repos,
              :provisioner_web => provisioner_web,
              :api_server => api_server,
              :logging_server => api_server, # XXX: FIX THIS
              :online => online,
              :keys => keys,
              :web_path => web_path)
  end

  template "#{node_dir}/crowbar_join.sh" do
    mode 0644
    owner "root"
    group "root"
    source "crowbar_join.sh.erb"
    variables(:api_server => api_server, :name => mnode_name, :ntp_server => ntp_server)
  end

  provisioner_bootfile mnode_name do
    bootenv "#{os}-install"
    kernel params["kernel"]
    initrd params["initrd"]
    address v4addr
    kernel_params append
    action :add
  end
  
end
