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
  os_codename = node["crowbar"]["provisioner"]["server"]["supported_oses"][os]["codename"]
  keys = node["crowbar"]["access_keys"].values.sort.join($/)
  machine_key = node["crowbar"]["machine_key"]
  os_dir = "#{tftproot}/#{os}"
  mnode_name = new_resource.name
  node_dir = "#{tftproot}/nodes/#{mnode_name}"
  web_path = "#{provisioner_web}/nodes/#{mnode_name}"
  crowbar_repo_web="#{web_path}/crowbar-extra"
  admin_web="#{web_path}/install"
  append = "url=#{web_path}/seed netcfg/get_hostname=#{mnode_name} #{params["kernel_params"]} crowbar.fqdn=#{mnode_name} crowbar.install.key=#{machine_key}"
  v4addr = new_resource.address

  directory node_dir do
    action :create
    recursive true
  end

  template "#{node_dir}/seed" do
    mode 0644
    owner "root"
    group "root"
    source "net_seed.erb"
    variables(:install_name => os,
              :name => mnode_name,
              :cc_use_local_security => use_local_security,
              :os_install_site => params[:os_install_site],
              :online => online,
              :provisioner_web => provisioner_web,
              :web_path => web_path,
              :proxy => proxy)
  end

  template "#{node_dir}/post-install.sh" do
    mode 0644
    owner "root"
    group "root"
    source "net-post-install.sh.erb"
    variables(:install_name => os,
              :os_codename => os_codename,
              :repos => repos,
              :api_server => api_server,
              :online => online,
              :keys => keys,
              :provisioner_web => provisioner_web,
              :logging_server => api_server, # XXX: FIX this with logging service.
              :proxy => proxy,
              :web_path => web_path)
  end

  template "#{node_dir}/crowbar_join.sh" do
    mode 0644
    owner "root"
    group "root"
    source "crowbar_join.sh.erb"
    variables(:api_server => api_server, :ntp_server => ntp_server, :name => mnode_name)
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
