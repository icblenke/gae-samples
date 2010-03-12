ActionController::Routing::Routes.draw do |map|

   map.with_options :controller => 'home', :path_prefix => '' do |r|
      r.index               '',                                         :action => 'index',                :conditions => { :method => :get }
      r.openid_start   'openid_start',                   :action => 'openid_start',    :conditions => { :method => :post }
      r.openid_stop   'openid_stop',                   :action => 'openid_stop'
     r.cron                 'cron',                                 :action => 'cron',                    :conditions => { :method => :get }
   end

  map.root :controller => "home", :action => "index"
end
