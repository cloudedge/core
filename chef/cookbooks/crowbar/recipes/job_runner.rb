# Copyright 2015, RackN
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

# GREG: Add the code to configure and start the runner here

bash "reload consul runner server" do
  code "/usr/local/bin/consul reload"
  action :nothing
end

ip_addr = (IP.coerce(node["crowbar"]["job_runner"]["service_address"]).addr rescue nil)

template "/etc/consul.d/crowbar-job-runner.json" do
  source "consul-job-runner.json.erb"
  mode 0644
  owner "root"
  variables(:ip_addr => ip_addr)
  notifies :run, "bash[reload consul runner server]", :immediately
end

