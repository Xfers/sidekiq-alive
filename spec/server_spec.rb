# frozen_string_literal: true

require 'rack/test'
require 'net/http'
require 'sidekiq_alive/server'
RSpec.describe SidekiqAlive::Server do
  include Rack::Test::Methods

  subject(:app) { described_class }

  describe '#run!' do
    subject { app.run! }

    before { allow(Rack::Handler).to receive(:get).with('webrick').and_return(fake_webrick) }

    let(:fake_webrick) { double }

    it 'runs the handler with sidekiq_alive logger, host and no access logs' do
      expect(fake_webrick).to receive(:run).with(
        described_class,
        hash_including(Logger: SidekiqAlive.logger,
                       Host: '0.0.0.0',
                       AccessLog: [])
      )

      subject
    end

    context 'when we change the host config' do
      around do |example|
        ENV['SIDEKIQ_ALIVE_HOST'] = '1.2.3.4'
        SidekiqAlive.config.set_defaults

        example.run

        ENV['SIDEKIQ_ALIVE_HOST'] = nil
      end

      it 'respects the SIDEKIQ_ALIVE_HOST environment variable' do
        expect(fake_webrick).to receive(:run).with(
          described_class,
          hash_including(Host: '1.2.3.4')
        )

        subject
      end
    end
  end

  describe 'responses' do
    it 'responds with success when the service is alive' do
      allow(described_class).to receive(:sidekiq_process_alive?) { true }
      get SidekiqAlive.config.liveness_probe_path
      expect(last_response).to be_ok
      expect(last_response.body).to eq('Alive!')
    end

    it 'responds with an error when the service is not alive' do
      allow(described_class).to receive(:sidekiq_process_alive?) { false }
      get SidekiqAlive.config.liveness_probe_path
      expect(last_response).not_to be_ok
      expect(last_response.body).to eq("Can't find the alive key")
    end

    it 'responds not found on an unknown path' do
      get '/unknown-path'
      expect(last_response).not_to be_ok
      expect(last_response.body).to eq("Not found")
    end

    it 'responds busy count' do
      allow(described_class).to receive(:sidekiq_busy_count) { 10 }
      get SidekiqAlive.config.sidekiq_busy_count_path
      expect(last_response).to be_ok
      expect(last_response.body).to eq("10")

      allow(described_class).to receive(:sidekiq_busy_count) { 0 }
      get SidekiqAlive.config.sidekiq_busy_count_path
      expect(last_response).to be_ok
      expect(last_response.body).to eq("0")
    end

  end

  describe 'SidekiqAlive setup host' do
    before do
      ENV['SIDEKIQ_ALIVE_HOST'] = '1.2.3.4'
      SidekiqAlive.config.set_defaults
    end

    after do
      ENV['SIDEKIQ_ALIVE_HOST'] = nil
    end

    it 'respects the SIDEKIQ_ALIVE_HOST environment variable' do
      expect(described_class.host).to eq '1.2.3.4'
    end
  end

  describe 'SidekiqAlive setup port' do
    before do
      ENV['SIDEKIQ_ALIVE_PORT'] = '4567'
      SidekiqAlive.config.set_defaults
    end

    after do
      ENV['SIDEKIQ_ALIVE_PORT'] = nil
    end

    it 'respects the SIDEKIQ_ALIVE_PORT environment variable' do
      expect(described_class.port).to eq '4567'
      expect(described_class.server).to eq 'webrick'
    end
  end

  describe 'SidekiqAlive setup server' do
    before do
      ENV['SIDEKIQ_ALIVE_SERVER'] = 'puma'
      SidekiqAlive.config.set_defaults
    end

    after do
      ENV['SIDEKIQ_ALIVE_SERVER'] = nil
    end

    it 'respects the SIDEKIQ_ALIVE_PORT environment variable' do
      expect(described_class.server).to eq 'puma'
    end
  end

  describe 'SidekiqAlive setup path' do
    before do
      ENV['SIDEKIQ_ALIVE_LIVENESS_PROBE_PATH'] = '/sidekiq-liveness-probe'
      ENV['SIDEKIQ_ALIVE_SIDEKIQ_BUSY_COUNT_PATH'] = '/sidekiq-busy-probe'
      SidekiqAlive.config.set_defaults
    end

    after do
      ENV['SIDEKIQ_ALIVE_LIVENESS_PROBE_PATH'] = nil
      ENV['SIDEKIQ_ALIVE_SIDEKIQ_BUSY_COUNT_PATH'] = nil
    end

    it 'respects the path environment variable' do
      expect(described_class.liveness_probe_path).to eq '/sidekiq-liveness-probe'
      expect(described_class.sidekiq_busy_count_path).to eq '/sidekiq-busy-probe'
    end

    it 'responds ok to the given path' do
      allow(described_class).to receive(:sidekiq_process_alive?) { true }
      get '/sidekiq-liveness-probe'
      expect(last_response).to be_ok
    end
  end
end
