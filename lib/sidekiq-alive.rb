require 'sidekiq'
require 'sidekiq/api'
require 'singleton'
require 'sidekiq_alive/version'
require 'sidekiq_alive/config'

module SidekiqAlive
  def self.start
    Sidekiq.configure_server do |sq_config|

      sq_config.options[:queues].unshift(current_queue)

      sq_config.on(:startup) do
        SidekiqAlive::Worker.sidekiq_options queue: current_queue
        SidekiqAlive.tap do |sa|
          sa.logger.info(banner)
          sa.register_current_instance
          sa.store_alive_key
          sa::Worker.perform_async(hostname)

          # set/increase fork counter for current process group id key
          fork_count = redis.incr(current_instance_pgid_key)
          # only start web server on first process
          sa.logger.info("fork_count: #{fork_count}")
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

      sq_config.on(:quiet) do
        SidekiqAlive.unregister_current_instance
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

        SidekiqAlive.unregister_current_instance

        # remove process group id key for current instance
        redis.del(current_instance_pgid_key)
      end
    end
  end

  def self.current_queue
    config.queue
  end

  def self.register_current_instance
    register_instance(current_instance_register_key)
  end

  def self.unregister_current_instance
    # Delete any pending jobs for this instance
    logger.info(shutdown_info)
    purge_pending_jobs
    redis.del(current_instance_register_key)
  end

  def self.registered_instances
    deep_scan("#{config.registered_instance_key}::*")
  end

  def self.deep_scan(keyword, keys = [], cursor = 0)
    loop do
      cursor, found_keys = SidekiqAlive.redis.scan(cursor, match: keyword, count: 1000)
      keys += found_keys
      break if cursor.to_i == 0
    end
    keys
  end

  def self.purge_pending_jobs
    # TODO:
    # Sidekiq 6 allows better way to find scheduled jobs:
    # https://github.com/mperham/sidekiq/wiki/API#scan
    scheduled_set = Sidekiq::ScheduledSet.new
    # jobs = scheduled_set.select { |job| job.klass == 'SidekiqAlive::Worker' && job.queue == current_queue }
    jobs = scheduled_set.scan("\"class\":\"SidekiqAlive::Worker\"")
    logger.info("[SidekiqAlive] Purging #{jobs.count} pending for #{hostname}")
    jobs.each(&:delete)
  end

  def self.current_instance_register_key
    "#{config.registered_instance_key}::#{hostname}"
  end

  def self.current_instance_pgid_key
    "#{config.registered_instance_key}_PGRP::#{hostname}::#{Process.getpgrp}"
  end

  def self.store_alive_key
    redis.set(current_liveness_key,
              Time.now.to_i,
              ex: config.time_to_live.to_i)
  end

  def self.redis
    Sidekiq.redis { |r| r }
  end

  def self.alive?
    redis.ttl(current_liveness_key) != -2
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

  def self.current_liveness_key
    "#{config.liveness_key}::#{hostname}"
  end

  def self.hostname
    ENV['HOSTNAME'] || Socket.gethostname || 'HOSTNAME_NOT_SET'
  end

  def self.shutdown_info
    <<~BANNER

    =================== Shutting down SidekiqAlive =================

    Hostname: #{hostname}
    Liveness key: #{current_liveness_key}
    Current instance register key: #{current_instance_register_key}
    Worker running on queue: #{current_queue}

    BANNER
  end

  def self.banner
    <<~BANNER

    =================== SidekiqAlive =================

    Hostname: #{hostname}
    Liveness key: #{current_liveness_key}
    Port: #{config.port}
    Time to live: #{config.time_to_live}s
    Current instance register key: #{current_instance_register_key}
    Worker running on queue: #{current_queue}


    starting ...
    BANNER
  end

  def self.successful_startup_text
    <<~BANNER
    Registered instances:

    - #{registered_instances.join("\n\s\s- ")}

    =================== SidekiqAlive Ready! =================
    BANNER
  end

  def self.register_instance(instance_name)
    redis.set(instance_name,
              Time.now.to_i,
              ex: config.registration_ttl.to_i)
  end
end

require 'sidekiq_alive/worker'
require 'sidekiq_alive/server'

SidekiqAlive.start if ENV.fetch('DISABLE_SIDEKIQ_ALIVE', '') == '' && (ENV["RAILS_ENV"].to_s.downcase != "test" || ENV["RACK_ENV"].to_s.downcase != "test")
