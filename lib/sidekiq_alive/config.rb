# frozen_string_literal: true

module SidekiqAlive
  class Config
    include Singleton

    attr_accessor :host,
                  :port,
                  :liveness_probe_path,
                  :sidekiq_busy_count_path,
                  :liveness_key,
                  :time_to_live,
                  :callback,
                  :registered_instance_key,
                  :queue,
                  :server,
                  :server_mode,
                  :custom_liveness_probe

    def initialize
      set_defaults
    end

    def set_defaults
      @host = ENV.fetch('SIDEKIQ_ALIVE_HOST', '0.0.0.0')
      @port = ENV.fetch('SIDEKIQ_ALIVE_PORT', 7433)
      @liveness_probe_path = ENV.fetch('SIDEKIQ_ALIVE_LIVENESS_PROBE_PATH', '/liveness_probe')
      @sidekiq_busy_count_path = ENV.fetch('SIDEKIQ_ALIVE_SIDEKIQ_BUSY_COUNT_PATH', '/busy_count')
      @liveness_key = 'SIDEKIQ::LIVENESS_PROBE_TIMESTAMP'
      @time_to_live = 5 * 60
      @callback = proc {}
      @registered_instance_key = 'SIDEKIQ_REGISTERED_INSTANCE'
      @queue = :sidekiq_alive
      @server = ENV.fetch('SIDEKIQ_ALIVE_SERVER', 'webrick')
      @server_mode = :thread
      @custom_liveness_probe = proc { true }
    end

    def registration_ttl
      @registration_ttl || time_to_live + 60
    end
  end
end
