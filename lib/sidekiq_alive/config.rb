# frozen_string_literal: true

module SidekiqAlive
  class Config
    include Singleton

    attr_accessor :host,
                  :port,
                  :liveness_probe_path,
                  :sidekiq_busy_count_path,
                  :queue,
                  :server,
                  :server_mode

    def initialize
      set_defaults
    end

    def set_defaults
      @host = ENV.fetch('SIDEKIQ_ALIVE_HOST', '0.0.0.0')
      @port = ENV.fetch('SIDEKIQ_ALIVE_PORT', 7433)
      @liveness_probe_path = ENV.fetch('SIDEKIQ_ALIVE_LIVENESS_PROBE_PATH', '/liveness_probe')
      @sidekiq_busy_count_path = ENV.fetch('SIDEKIQ_ALIVE_SIDEKIQ_BUSY_COUNT_PATH', '/busy_count')
      @queue = :default
      @server = ENV.fetch('SIDEKIQ_ALIVE_SERVER', 'webrick')
      @server_mode = :thread
    end
  end
end
