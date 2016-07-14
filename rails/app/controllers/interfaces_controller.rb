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
class InterfacesController < ::ApplicationController
  respond_to :html, :json

  # GREG: What the heck to do with this??

  def match
    attrs = Interface.attribute_names.map{|a|a.to_sym}
    objs = []
    ok_params = params.permit(attrs)
    objs = Interface.where(ok_params) if !ok_params.empty?
    respond_to do |format|
      format.html {}
      format.json { render api_index Interface, objs }
    end
  end

  def create
    pattern = params[:pattern]
    bus_order = params[:bus_order].split(" | ")
    r = Role.find_key 'network-server'
    r.update_interface(pattern, bus_order)
    r.save!    
    @interfaces = r.interfaces
    respond_to do |format|
      format.html { render :action=>:index   } 
      format.json { render api_index :interface, @interfaces }
    end
  end

  def update
    pattern = params[:id]
    bus_order = params[:bus_order].split(" | ")
    r = Role.find_key 'network-server'
    r.update_interface(pattern, bus_order)
    r.save!    
    @interfaces = r.interfaces
    respond_to do |format|
      format.html { render :action=>:index } 
      format.json { render api_index :interface, @interfaces }
    end
  end

  def show
    r = Role.find_key 'network-server'
    @interfaces = r.interfaces
    render :action=>:index
  end
  
  def index
    r = Role.find_key 'network-server'
    @interfaces = r.interfaces rescue []
    respond_to do |format|
      format.html { }
      format.json { render api_index :interface, @interfaces }
    end
  end

end
