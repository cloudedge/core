# Copyright 2011, Dell
# Copyright 2012, SUSE Linux Products GmbH
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License
# You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied
# See the License for the specific language governing permissions and
# limitations under the License
#
# This recipe sets up Apache and TFTP servers.

web_port = node["crowbar"]["provisioner"]["server"]["web_port"]

template "/etc/init.d/sws" do
  mode "0755"
  source "sws-init.erb"
  variables(:docroot => node["crowbar"]["provisioner"]["server"]["root"],
            :port => node["crowbar"]["provisioner"]["server"]["web_port"])
  notifies :restart, "service[sws]"
end

service "sws" do
  action [ :enable, :start ]
end

# Set up the TFTP server as well.
case node["platform"]
when "ubuntu", "debian"
  package "tftpd-hpa"
when "redhat","centos"
  package "tftp-server"
when "suse"
  package "tftp"
end

case
when File.directory?("/usr/lib/systemd/system")
  template "/etc/systemd/system/tftp.service" do
    source "tftp.service.erb"
    variables tftproot: node["crowbar"]["provisioner"]["server"]["root"]
    notifies :restart, "service[tftp]"
  end

  service "tftp" do
    enabled true
    provider Chef::Provider::Service::Systemd
    service_name "tftp.socket"
    action [ :enable, :start ]
  end
when node["platform"] == "suse"
  service "tftp" do
    action [ :enable ]
  end
  service "xinetd" do
    running true
    enabled true
    action [ :enable, :start ]
  end
when ["redhat","centos"].member?(node["platform"])
  template "/etc/xinetd.d/tftp" do
    source "xinetd.tftp.erb"
    variables(:tftproot => node["crowbar"]["provisioner"]["server"]["root"])
    mode 0644
    user "root"
    group "root"
    notifies :restart, "service[xinetd]"
  end
  service "xinetd" do
    action [:enable, :start]
  end
when node["platform"] == "ubuntu"
  service "tftpd-hpa" do
    action [ :enable ]
  end
  template "/etc/default/tftpd-hpa" do
    source "tftpd-ubuntu.erb"
    mode 0644
    user "root"
    group "root"
    variables(
              :address => "0.0.0.0:69",
              :tftproot => node["crowbar"]["provisioner"]["server"]["root"]
              )
    notifies :restart, resources(:service => "tftpd-hpa")
  end
else
  raise "Cannot set up TFTP on #{node[platform]}"
end

bash "reload consul provisioner" do
  code "/usr/local/bin/consul reload"
  action :nothing
end

ip_addr = (IP.coerce(node["provisioner"]["service_address"]).addr rescue nil)

template "/etc/consul.d/crowbar-provisioner.json" do
  source "consul-provisioner-server.json.erb"
  mode 0644
  owner "root"
  variables(:web_port => web_port, :ip_addr => ip_addr)
  notifies :run, "bash[reload consul provisioner]", :immediately
end
