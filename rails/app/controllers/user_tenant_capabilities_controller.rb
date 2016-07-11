# Copyright 2016, RackN
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
class UserTenantCapabilitiesController < ::ApplicationController
  respond_to :html, :json

  def sample
    render api_sample(UserTenantCapability)
  end

  def match
    attrs = UserTenantCapability.attribute_names.map{|a|a.to_sym}
    objs = []
    ok_params = params.permit(attrs)
    objs = validate_match(ok_params, :tenant_id, "TENANT", UserTenantCapability)
    respond_to do |format|
      format.html {}
      format.json { render api_index UserTenantCapability, objs }
    end
  end

  def index
    t_ids = build_tenant_list("TENANT_READ")
    ut_ids = build_tenant_list("USER_READ")
    ct_ids = build_tenant_list("CAPABILITY_READ")
    @caps = UserTenantCapability.where(tenant_id: t_ids & ut_ids & ct_ids)
    respond_to do |format|
      format.html {
	@users = User.where(tenant_id: ut_ids)
	@tenants = Tenant.where(id: t_ids)
	unless ct_ids.empty?
	  @capabilities = Capability.all
	else
	  @capabilities = {}
	end
      }
      format.json { render api_index UserTenantCapability, @caps }
    end
  end

  def show
    @cap = UserTenantCapability.find_key params[:id]
    validate_read(@cap.tenant_id, "TENANT", UserTenantCapability, "#{params[:user_id]}:#{params[:tenant_id]}:#{params[:capabilitiy_id]}")
    validate_read(@cap.tenant_id, "USER", UserTenantCapability, "#{params[:user_id]}:#{params[:tenant_id]}:#{params[:capabilitiy_id]}")
    validate_read(@cap.tenant_id, "CAPABILITY", UserTenantCapability, "#{params[:user_id]}:#{params[:tenant_id]}:#{params[:capabilitiy_id]}")
    respond_to do |format|
      format.html { }
      format.json { render api_show @cap }
    end
  end
  
  def create
    [ :tenant_id, :user_id, :capability_id ].each do |tag|
      if params[tag] and params[tag].is_a?(String)
        params[tag] = params[tag].to_i
      end
    end

    validate_action(params[:tenant_id], "USER_TENANT_CAPABILITY", UserTenantCapability, params.to_s, "ADD")

    UserTenantCapability.transaction do
      @cap = UserTenantCapability.create! params.permit(:tenant_id,
                                             :user_id,
                                             :capability_id)
    end

    respond_to do |format|
      format.html { redirect_to :action=>:index }
      format.json { render api_show @cap }
    end
  end

  def update
    render api_not_supported 'put', 'user_tenant_capabilitiies/:id'
  end

  def destroy
    @cap = UserTenantCapability.find_key(params[:id])
    validate_action(@cap.tenant_id, "USER_TENANT_CAPABILITY", UserTenantCapability, params[:id], "DESTROY")
    @cap.destroy
    respond_to do |format|
      format.html { redirect_to :action=>:index }
      format.json { render api_delete @cap }
    end
  end

end
