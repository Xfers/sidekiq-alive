require 'sidekiq'
require 'sidekiq/api'
require 'sidekiq/util'
require 'singleton'
require 'sidekiq_alive/version'
require 'sidekiq_alive/config'

module SidekiqAlive
  def self.start
    Sidekiq.configure_server do |sq_config|
      sq_config.on(:startup) do
        SidekiqAlive.tap do |sa|
          sa.logger.info(banner)

          # set/increase fork counter for current process group id key
          fork_count = redis.incr(current_instance_pgrp_key)
          # only start web server on first process
          if fork_count == 1
            if config.server_mode == :thread
              sa.logger.info("[SidekiqAlive] Run http server in new thread")
              @server_thread = Thread.new do
                sa::Server.run!
              end
            else
              sa.logger.info("[SidekiqAlive] Run http server in new process")
              @server_pid = fork do
                sa::Server.run!
              end
            end
          end

          sa.logger.info(successful_startup_text)
        end
      end

      sq_config.on(:shutdown) do
        if config.server_mode == :thread
          unless @server_thread.nil?
            SidekiqAlive::Server.shutdown!
            @server_thread.terminate
            @server_thread.join
          end
        else
          unless @server_pid.nil?
            Process.kill('TERM', @server_pid)
            Process.wait(@server_pid)
          end
        end

        # remove process group id key for current instance
        redis.del(current_instance_pgrp_key)
      end
    end
  end

  def self.current_instance_pgrp_key
    "#SIDEKIQ_INSTANCE_PGRP::#{hostname}::#{Process.getpgrp}"
  end

  def self.redis
    Sidekiq.redis { |r| r }
  end

  # CONFIG ---------------------------------------

  def self.setup
    yield(config)
  end

  def self.logger
    Sidekiq.logger
  end

  def self.config
    @config ||= SidekiqAlive::Config.instance
  end

  def self.hostname
    ENV['HOSTNAME'] || Socket.gethostname || 'HOSTNAME_NOT_SET'
  end

  def self.shutdown_info
    <<~BANNER

    =================== Shutting down SidekiqAlive =================

    Hostname: #{hostname}

    BANNER
  end

  def self.banner
    <<~BANNER

    =================== SidekiqAlive =================

    Hostname: #{hostname}
    Port: #{config.port}
    Liveness Probe Path: #{config.liveness_probe_path}
    Sidekiq Busy Count Path: #{config.sidekiq_busy_count_path}
    starting ...
    BANNER
  end

  def self.successful_startup_text
    <<~BANNER

    =================== SidekiqAlive Ready! =================
    BANNER
  end

end

require 'sidekiq_alive/server'

SidekiqAlive.start if ENV.fetch('DISABLE_SIDEKIQ_ALIVE', '') == '' && (ENV["RAILS_ENV"].to_s.downcase != "test" || ENV["RACK_ENV"].to_s.downcase != "test")
