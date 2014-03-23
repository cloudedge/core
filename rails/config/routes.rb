# Copyright 2013-4, Dell
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
Crowbar::Application.routes.draw do

  # UI scope

  # special case items that allow IDs to have .s 
  constraints(:id => /.*/ ) do
    resources :nodes do
      resources :node_roles
      resources :attribs
    end
  end

  # UI resources (should generally match the API paths)
  get "annealer", :to => "node_roles#anneal", :as => :annealer
  resources :attribs
  resources :barclamps
  resources :deployment_roles
  resources :deployments do
    get :head
    get :next
    resources :roles
  end
  resources :docs, constraints: {id: /[^\?]*/}

  resources :groups
  resources :jigs
  resources :node_roles  do
    put :retry
  end
  resources :roles
  resources :snapshots do
    resources :node_roles
    get :graph
    get :cohorts
    put :propose
    put :commit
    put :recall
  end

  resources :interfaces
  resources :networks do
    resources :network_ranges
    resources :network_routers
    # special views
  end
  resources :network_ranges
  get 'network_map' => "networks#map", :as=> :network_map

  # UI only functionality to help w/ visualization
  scope 'dashboard' do
    get 'list(/:deployment)'  => 'dashboard#list', :as => :bulk_edit
    put 'list'                => 'dashboard#list', :as => :bulk_update
    get 'layercake'           => 'dashboard#layercake', :as => :layercake
  end
  
  # UI only functionality to help w/ visualization
  scope 'utils' do
    get '/'             => 'support#index', :as => :utils
    get 'i18n/:id'      => 'support#i18n', :as => :utils_i18n, :constraints => { :id => /.*/ }
    get 'marker/:id'    => 'support#marker', :as => :utils_marker
    get 'files/:id'     => 'support#index', :as => :utils_files
    get 'import(/:id)'  => 'support#import', :as => :utils_import
    get 'upload/:id'    => 'support#upload', :as => :utils_upload
    get 'restart/:id'   => 'support#restart', :as => :restart
    get 'digest'        => "support#digest"
    get 'fail'          => "support#fail"
    get 'settings'      => "support#settings", :as => :utils_settings
    put 'settings(/:id/:value)' => "support#settings_put", :as => :utils_settings_put
    get  "bootstrap"     => "support#bootstrap", :as => :bootstrap
    post "bootstrap"     => "support#bootstrap_post", :as => :bootstrap_post
    namespace :scaffolds do
      resources :attribs do as_routes end
      resources :barclamps do as_routes end
      resources :docs do as_routes end
      resources :deployment_roles do as_routes end
      resources :deployments do as_routes end
      resources :groups do as_routes end
      resources :jigs do as_routes end
      resources :navs do as_routes end
      resources :network_allocations do as_routes end
      resources :network_ranges do as_routes end
      resources :network_routers do as_routes end
      resources :networks do as_routes end
      resources :nodes do as_routes end
      resources :node_roles do as_routes end
      resources :roles do as_routes end
      resources :role_requires do as_routes end
      resources :runs do as_routes end
      resources :snapshots do as_routes end
    end
  end

  # UI scope - legacy methods
  scope 'support' do
    get 'logs', :controller => 'support', :action => 'logs'
    get 'get_cli', :controller => 'support', :action => 'get_cli'
  end

  devise_for :users, { :path_prefix => 'my', :module => :devise, :class_name=> 'User' }
  resources :users, :except => :new

  # API routes (must be json and must prefix v2)()
  scope :defaults => {:format => 'json'} do

    constraints(:id => /([a-zA-Z0-9\-\.\_]*)/, :version => /v[1-9]/) do

      # framework resources pattern (not barclamps specific)
      scope 'api' do
        scope 'status' do
          get "nodes(/:id)" => "nodes#status", :as => :nodes_status
          get "snapshots(/:id)" => "snapshots#status", :as => :snapshots_status
          get "queue" => "support#queue", :as => :queue_status
        end
        scope 'test' do
          put "nodes(/:id)" => "nodes#test_load_data"
        end
        scope ':version' do
          # These are not restful.  They poke the annealer and wait if you pass "sync=true".
          get "anneal", :to => "node_roles#anneal", :as => :anneal
          resources :attribs, :as=>:attribs_api
          resources :barclamps
          resources :deployment_roles do
            resources :attribs
          end
          resources :deployments do
            get :head
            get :next
            resources :roles
            resources :nodes
            resources :attribs
            # These just do the appropriate action on the relavent snapshot.
            put :propose
            put :commit
            put :recall
          end
          resources :groups do
            member do
              get 'nodes'
            end
          end

          resources :networks do
            resources :network_ranges
            resources :network_routers, :as => :network_routers_api
            member do
              match 'ip', via: [:get, :delete]
              post 'allocate_ip'
              get 'allocations'
            end
          end
          resources :network_ranges
          resources :interfaces

          resources :runs
          resources :jigs
          resources :nodes do
            resources :node_roles
            resources :attribs
            resources :roles
            put :reboot
            put :debug
            put :undebug
            put :redeploy
            put :commit
            put :alive
            put :available
          end
          resources :node_roles do
            resources :attribs
            put :retry
          end
          resources :roles do
            resources :attribs
            resources :deployment_roles
          end
          resources :snapshots do
            resources :node_roles
            resources :nodes
            resources :roles
            resources :deployment_roles
            resources :attribs
            get :graph
            put :propose
            put :commit
            put :recall
          end
          resources :users do
            post "admin", :controller => "users", :action => "make_admin"
            delete "admin", :controller => "users", :action => "remove_admin"
            post "lock", :controller => "users", :action => "lock"
            delete "lock", :controller => "users", :action => "unlock"
            put "reset_password", :controller => "users", :action => "reset_password"
          end

          resources :dhcps

        end # version
      end # api
    end # id constraints
  end # json

  # Install route from each root barclamp (should be done last so CB gets priority).
  Dir.glob("/opt/opencrowbar/**/crowbar_engine/barclamp_*/config/routes.rb") do |routefile|
    bc = routefile.split('/')[-3].partition('_')[2]
    bc_engine = "#{routefile.split('/')[-3].camelize}::Engine"
    bc_mount = "mount #{bc_engine}, at: '#{bc}'"
    eval(bc_mount, binding)
  end

  root :to => 'dashboard#layercake'
end
