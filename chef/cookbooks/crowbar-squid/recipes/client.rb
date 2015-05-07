# Copyright 2014, Opencrowbar Team
# Copyright 2015, RackN
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
# This recipe sets up Squid clients

proxy_str=node["crowbar"]["proxy"]["servers"].first["url"]

localnets = ["127.0.0.1","localhost","::1"]
`ip -o addr show`.lines.each do |line|
  next unless /inet6? ([^ ]+)/ =~ line
  localnets << IP.coerce($1).network.to_s
end
localnets.sort!

# Once the local proxy service is set up, we need to use it.
proxies = {
  "http_proxy" => proxy_str,
  "https_proxy" => proxy_str,
  "no_proxy" => localnets.join(",")
}

template "/etc/environment" do
  source "environment.erb"
  variables(:values => proxies)
end

template "/etc/profile.d/proxy.sh" do
  source "proxy.sh.erb"
  variables(:values => proxies)
end

case node["platform"]
when "redhat","centos"
  template "/etc/yum.conf" do
    source "yum.conf.erb"
    variables(
              :distro => node["platform"],
              :proxy => proxies["http_proxy"]
              )
  end
end
