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
#
class EventsController < ApplicationController


  def sample
    render api_sample(Event)
  end

  def match
    attrs = Event.attribute_names.map{|a|a.to_sym}
    objs = []
    ok_params = params.permit(attrs)
    objs = Event.where(ok_params) if !ok_params.empty?
    respond_to do |format|
      format.html {}
      format.json { render api_index Event, objs }
    end
  end

    # API GET /api/v2/hammers
  def index
    @events = Event.all
    respond_to do |format|
      format.html { } 
      format.json { render api_index Event, @events }
    end
  end

  def show
    @event = Event.find_key(params[:id])
    respond_to do |format|
      format.html {  }
      format.json { render api_show @event }
    end
  end

  def destroy
    render api_delete Event
  end


end
