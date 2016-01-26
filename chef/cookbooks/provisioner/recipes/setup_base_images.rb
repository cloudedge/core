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
# This recipe sets up the general environmnet needed to PXE boot
# other servers.

Chef::Log.info("Provisioner: raw server data #{ node["rebar"]["provisioner"]["server"] }")

provisioner_web = node["rebar"]["provisioner"]["server"]["webservers"].first["url"]
os_token="#{node["platform"]}-#{node["platform_version"]}"
tftproot =  node["rebar"]["provisioner"]["server"]["root"]

unless default = node["rebar"]["provisioner"]["server"]["default_os"]
  node.normal["rebar"]["provisioner"]["server"]["default_os"] = default = os_token
end

unless node.normal["rebar"]["provisioner"]["server"]["repositories"]
  node.normal["rebar"]["provisioner"]["server"]["repositories"] = Mash.new
end
node.normal["rebar"]["provisioner"]["server"]["available_oses"] = Mash.new

node["rebar"]["provisioner"]["server"]["supported_oses"].each do |os,params|
  web_path = "#{provisioner_web}/#{os}"
  os_install_site = "#{web_path}/install"
  os_dir="#{tftproot}/#{os}"
  os_install_dir = "#{os_dir}/install"
  iso_dir="#{tftproot}/isos"
  initrd = params["initrd"]
  kernel = params["kernel"]

  # Don't bother for OSes that are not actaully present on the provisioner node.
  next unless File.file?("#{iso_dir}/#{params["iso_file"]}") or
    File.directory?(os_install_dir)
  node.normal["rebar"]["provisioner"]["server"]["available_oses"][os] = true
  node.normal["rebar"]["provisioner"]["server"]["repositories"][os] = Mash.new

  if os =~ /^(esxi)/
    # Extract esxi iso through rsync - bsdtar messes up the filenames
    tmpesxi="/tmp/esxi_mnt_pt/"
    bash "Extract rsync #{params["iso_file"]}" do
      code <<EOC
set -e
[[ -d "#{os_install_dir}.extracting" ]] && rm -rf "#{os_install_dir}.extracting"
mkdir -p "#{os_install_dir}.extracting"

mkdir -v #{tmpesxi}
mount -o loop "#{iso_dir}/#{params["iso_file"]}" #{tmpesxi}
rsync -av #{tmpesxi} "#{os_install_dir}.extracting"
sync && umount #{tmpesxi} && rmdir -v #{tmpesxi}
losetup -j "#{iso_dir}/#{params["iso_file"]}" | awk -F: '{ print $1 }' | xargs losetup -d

chmod +w "#{os_install_dir}.extracting"/*
sed -e "s:/::g" -e "3s:^:prefix=/../#{os}/install/\\n:" -i.bak "#{os_install_dir}.extracting"/boot.cfg

touch "#{os_install_dir}.extracting/.#{params["iso_file"]}.rebar_canary"
[[ -d "#{os_install_dir}" ]] && rm -rf "#{os_install_dir}"
mv "#{os_install_dir}.extracting" "#{os_install_dir}"
EOC
      only_if do File.file?("#{iso_dir}/#{params["iso_file"]}") &&
          !File.file?("#{os_install_dir}/.#{params["iso_file"]}.rebar_canary") end
    end
  else
    # Extract the ISO install image.
    # Do so in such a way the we avoid using loopback mounts and get
    # proper filenames in the end.
    bash "Extract #{params["iso_file"]}" do
      code <<EOC
set -e
[[ -d "#{os_install_dir}.extracting" ]] && rm -rf "#{os_install_dir}.extracting"
mkdir -p "#{os_install_dir}.extracting"
(cd "#{os_install_dir}.extracting"; bsdtar -x -f "#{iso_dir}/#{params["iso_file"]}")
touch "#{os_install_dir}.extracting/.#{params["iso_file"]}.rebar_canary"
[[ -d "#{os_install_dir}" ]] && rm -rf "#{os_install_dir}"
mv "#{os_install_dir}.extracting" "#{os_install_dir}"
EOC
      only_if do File.file?("#{iso_dir}/#{params["iso_file"]}") &&
          !File.file?("#{os_install_dir}/.#{params["iso_file"]}.rebar_canary") end
    end
  end

  #
  # TODO:Make generic NFS one day
  # Make sure we setup an nfs server and export the fuel directory
  #
  if os =~ /^(fuel)/
    package "nfs-utils"

    service "rpcbind" do
      action [ :enable, :start ]
    end

    service "nfs" do
      action [ :enable, :start ]
    end

    utils_line "#{os_install_dir} *(ro,async,no_subtree_check,no_root_squash,crossmnt)" do
      action :add
      file '/etc/exports'
      notifies :restart, "service[nfs]", :delayed
    end
  end

  # For CentOS and RHEL, we need to rewrite the package metadata
  # to make sure it does not refer to packages that do not exist on the first DVD.
  bash "Rewrite package repo metadata for #{params["iso_file"]}" do
    cwd os_install_dir
    code <<EOC
set -e
groups=($(echo repodata/*comps*.xml))
createrepo -g "${groups[-1]}" .
touch "repodata/.#{params["iso_file"]}.rebar_canary"
EOC
    not_if do File.file?("#{os_install_dir}/repodata/.#{params["iso_file"]}.rebar_canary") end
    only_if do os =~ /^(redhat|centos|fedora)/ end
  end

  # Figure out what package type the OS takes.  This is relatively hardcoded.
  pkgtype = case
            when os =~ /^(ubuntu|debian)/ then "debs"
            when os =~ /^(redhat|centos|suse|fedora)/ then "rpms"
            when os =~ /^(coreos|fuel|esxi|xenserver)/ then "custom"
            else raise "Unknown OS type #{os}"
            end
  # Download and create local packages repositories for any raw_pkgs for this OS.
  if (bc[pkgtype][os]["raw_pkgs"] rescue nil)
    destdir = "#{os_dir}/rebar-extra/raw_pkgs"

    directory destdir do
      action :create
      recursive true
    end

    bash "Delete #{destdir}/gen_meta" do
      code "rm -f #{destdir}/gen_meta"
      action :nothing
    end

    bash "Update package metadata in #{destdir}" do
      cwd destdir
      action :nothing
      notifies :run, "bash[Delete #{destdir}/gen_meta]", :immediately
      code case pkgtype
           when "debs" then "dpkg-scanpackages . |gzip -9 >Packages.gz"
           when "rpms" then "createrepo ."
           else raise "Cannot create package metadata for #{pkgtype}"
           end
    end

    file "#{destdir}/gen_meta" do
      action :nothing
      notifies :run, "bash[Update package metadata in #{destdir}]", :immediately
    end

    bc[pkgtype][os]["raw_pkgs"].each do |src|
      dest = "#{destdir}/#{src.split('/')[-1]}"
      bash "#{destdir}: Fetch #{src}" do
        code "curl -fgL -o '#{dest}' '#{src}'"
        notifies :create, "file[#{destdir}/gen_meta]", :immediately
        not_if "test -f '#{dest}'"
      end
    end
  end

  # Index known barclamp repositories for this OS
  ruby_block "Index the current local package repositories for #{os}" do
    block do
      if File.exists? "#{os_dir}/rebar-extra" and File.directory? "#{os_dir}/rebar-extra"
        Dir.glob("#{os_dir}/rebar-extra/*") do |f|
          reponame = f.split("/")[-1]
          node.normal["rebar"]["provisioner"]["server"]["repositories"][os][reponame] = []
          case
          when os =~ /(ubuntu|debian)/
            bin="deb #{provisioner_web}/#{os}/rebar-extra/#{reponame} /"
            src="deb-src #{provisioner_web}/#{os}/rebar-extra/#{reponame} /"
            if File.exists? "#{os_dir}/rebar-extra/#{reponame}/Packages.gz"
              node.normal["rebar"]["provisioner"]["server"]["repositories"][os][reponame] << bin
            end
            if File.exists? "#{os_dir}/rebar-extra/#{reponame}/Sources.gz"
              node.normal["rebar"]["provisioner"]["server"]["repositories"][os][reponame] << src
            end
          when os =~ /(redhat|centos|suse|fedora)/
            bin="bare #{provisioner_web}/#{os}/rebar-extra/#{reponame}"
            node.normal["rebar"]["provisioner"]["server"]["repositories"][os][reponame] << bin
          else
            raise ::RangeError.new("Cannot handle repos for #{os}")
          end
        end
      end
    end
  end

  unless node["rebar"]["provisioner"]["server"]["boot_specs"]
    node.normal["rebar"]["provisioner"]["server"]["boot_specs"] = Mash.new
  end
  unless node["rebar"]["provisioner"]["server"]["boot_specs"][os]
    node.normal["rebar"]["provisioner"]["server"]["boot_specs"][os] = Mash.new
  end
  node.normal["rebar"]["provisioner"]["server"]["boot_specs"][os]["kernel"] = "#{os}/install/#{kernel}"
  node.normal["rebar"]["provisioner"]["server"]["boot_specs"][os]["initrd"] = "#{os}/install/#{initrd}"

  node.normal["rebar"]["provisioner"]["server"]["boot_specs"][os]["os_install_site"] = os_install_site
  node.normal["rebar"]["provisioner"]["server"]["boot_specs"][os]["kernel_params"] = params["append"] || ""

  ruby_block "Set up local base OS install repos for #{os}" do
    block do

      loc = case
            when (/^ubuntu/ =~ os and File.exists?("#{tftproot}/#{os}/install/dists/stable"))
              ["deb #{provisioner_web}/#{os}/install stable main restricted"]
            when /^(suse)/ =~ os
              ["bare #{provisioner_web}/#{os}/install"]
            when /^(redhat|centos|fedora)/ =~ os
              # Add base OS install repo for redhat/centos
              if ::File.exists? "#{tftproot}/#{os}/install/repodata"
                ["bare #{provisioner_web}/#{os}/install"]
              elsif ::File.exists? "#{tftproot}/#{os}/install/Server/repodata"
                ["bare #{provisioner_web}/#{os}/install/Server"]
              end
            end
      node.normal["rebar"]["provisioner"]["server"]["repositories"][os]["provisioner"] = loc
    end
  end
end

# Build coreos chef code tgz - fix ip issue for ohai and dmidecode
bash "Build CoreOS chef code" do
  code <<EOC
set -e -x
cp -r /opt/chef /tmp
cd /tmp/chef
while read file; do
  sed -i "s:/sbin/ip:/bin/ip:g" "$file"
done < <(find . -type f | xargs grep -l "/sbin/ip")
while read file; do
  sed -i 's:"dmidecode":"/opt/chef/dmidecode/usr/sbin/dmidecode":g' "$file"
done < <(find . -type f | xargs grep -l 'shell_out("dmidecode")' | grep -v spec)
mkdir -p /tmp/chef/dmidecode
cd /tmp/chef/dmidecode
[[ -f #{tftproot}/files/dmidecode-2.10.tbz2 ]] || \
    curl -fgL -o '#{tftproot}/files/dmidecode-2.10.tbz2' \
        http://storage.core-os.net/coreos/amd64-generic/38.0.0/pkgs/sys-apps/dmidecode-2.10.tbz2
bzip2 -d -c #{tftproot}/files/dmidecode-2.10.tbz2 | tar xf -
cd /tmp
tar -zcf #{tftproot}/files/coreos-chef.tgz chef
cd
rm -rf /tmp/chef
EOC
  not_if do File.file?("#{tftproot}/files/coreos-chef.tgz") end
end

bash "Restore selinux contexts for #{tftproot}" do
  code "restorecon -R -F #{tftproot}"
  only_if "which selinuxenabled && selinuxenabled"
end
