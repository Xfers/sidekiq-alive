# frozen_string_literal: true

require 'rack'

module SidekiqAlive
  class Server
    class << self
      def run!
        @handler = Rack::Handler.get(server)

        Signal.trap('TERM') { @handler.shutdown } if SidekiqAlive.config.server_mode == :fork

        begin
          @handler.run(self, Port: port, Host: host, AccessLog: [], Logger: SidekiqAlive.logger)
        rescue Errno::EADDRINUSE
          SidekiqAlive.logger.warn("[SidekiqAlive] Other sidkiq processes binded the #{host}:#{port}")
        end
      end

      def shutdown!
        @handler.shutdown if SidekiqAlive.config.server_mode == :thread
      end

      def host
        SidekiqAlive.config.host
      end

      def port
        SidekiqAlive.config.port
      end

      def liveness_probe_path
        SidekiqAlive.config.liveness_probe_path
      end

      def sidekiq_busy_count_path
        SidekiqAlive.config.sidekiq_busy_count_path
      end

      def server
        SidekiqAlive.config.server
      end

      def sidekiq_busy_count
        hostname = SidekiqAlive.hostname
        sidekiq_processes = Sidekiq::ProcessSet.new
        sidekiq_processes.select { |process| process["hostname"] == hostname }.sum { |process| process["busy"] }
      end

      def sidekiq_process_alive?
        hostname = SidekiqAlive.hostname
        sidekiq_processes = Sidekiq::ProcessSet.new
        sidekiq_processes.any? { |ps| ps["hostname"] == hostname }
      end

      def call(env)
        case Rack::Request.new(env).path
        when liveness_probe_path
          if sidekiq_process_alive?
            [200, {}, ['Alive!']]
          else
            response = "Can't find the alive key"
            SidekiqAlive.logger.error(response)
            [404, {}, [response]]
          end
        when sidekiq_busy_count_path
          [200, {}, [sidekiq_busy_count.to_s]]
        else
          [404, {}, ['Not found']]
        end
      end
    end
  end
end
