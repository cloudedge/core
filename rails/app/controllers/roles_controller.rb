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
#
class RolesController < ApplicationController
  self.model = Role
  self.cap_base = "ROLE"

  def match
    attrs = Role.attribute_names.map{|a|a.to_sym}
    objs = []
    ok_params = params.permit(attrs)
    objs = Role.where(ok_params) if !ok_params.empty?
    respond_to do |format|
      format.html {}
      format.json { render api_index Role, objs }
    end
  end
  
  def index
    @list = if params.include? :deployment_id
              d = Deployment.find_key(params[:deployment_id])
	      if capable(d.tenant_id, "DEPLOYMENT_READ")
                r = d.roles.to_a
	      else
		r = []
	      end
            elsif params.include? :node_id
              n = Node.find_key(params[:node_id])
	      if capable(n.tenant_id, "NODE_READ")
                r = n.roles.to_a
	      else
		r = []
	      end
            else
              Role.all.to_a
            end
    respond_to do |format|
      format.html { }
      format.json { render api_index Role, @list }
    end
  end

  def show
    @role = Role.find_key params[:id]
    respond_to do |format|
      format.html {  }
      format.json { render api_show @role, "role" }
    end
  end

  def create
    if params.include? :deployment_id
      @deployment = Deployment.find_key params[:deployment_id]
      validate_create(@deployment.tenant_id, "DEPLOYMENT", Deployment, params[:deployment_id])
      role = Role.find_key params[:deployment][:role_id].to_i 
      role.add_to_deployment @deployment
      respond_to do |format|
        format.html { redirect_to deployment_path(@deployment.id) }
        format.json { render api_show @deployment }
      end
    else
      render api_not_supported("post",Role)
    end
  end

  def update
    Role.transaction do
      @role = Role.find_key params[:id].lock!
      validate_update(@current_user.current_tenant_id, "ROLE", Role, params[:id])
      if request.patch?
        patch(@role, %w{description,template})
      else
        @role.update_attributes!(params.permit(:description))
        if params.key? :template
          @role.template = params[:template]
          @role.save!
        end
      end
    end
    respond_to do |format|
      format.html { render :action=>:show }
      format.json { render api_show @role }
    end
  end

  def destroy
    @role = Role.find_key params[:role_id]
    validate_destroy(@current_user.current_tenant_id, "ROLE", Role, params[:role_id])
    @role.destroy
    render api_delete @role
  end

end
