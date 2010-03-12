# Be sure to restart your server when you modify this file.

# Your secret key for verifying cookie session data integrity.
# If you change this key, all old sessions will become invalid!
# Make sure the secret is at least 30 characters and all random, 
# no regular words or you'll be exposed to dictionary attacks.
ActionController::Base.session = {
  :key         => '_rails-2.3.5-openid-consumer-dm_session',
  :secret      => 'f737cf8fcf2464811db9b846c0a954504e16217bb049799f2d1dbee907c1e68378ac45dc75177b209d740794cb498d82f71dd2a216b2d6fa7dbcbe90bd1f0387'
}

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rake db:sessions:create")
# ActionController::Base.session_store = :active_record_store

if defined? JRuby::Rack
  require 'action_controller/session/java_servlet_store'
  ActionController::Base.session_store = :java_servlet_store
end
