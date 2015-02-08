#    railssettings.rb
#    ~~~~~~~~~
#    This module implements the RailsSettings class.
#    :authors: Konstantin Bokarius.
#    :copyright: (c) 2015 by Fanout, Inc.
#    :license: MIT, see LICENSE for more details.

class RailsSettings
  def self.get_prefix
    if Rails.application.config.respond_to?(:grip_prefix)
      return Rails.application.config.grip_prefix
    end
    return ''
  end

  def self.get_grip_proxies
    if Rails.application.config.respond_to?(:grip_proxies)
      return Rails.application.config.grip_proxies
    end
    return nil
  end

  def self.get_publish_servers
    if Rails.application.config.respond_to?(:publish_servers)
      return Rails.application.config.publish_servers
    end
    return nil
  end

  def self.get_grip_proxy_required
    if Rails.application.config.respond_to?(:grip_proxy_required)
      return Rails.application.config.grip_proxy_required
    end
    return false
  end
end
