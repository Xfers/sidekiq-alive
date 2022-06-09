RSpec.describe SidekiqAlive do
  it 'has a version number' do
    expect(SidekiqAlive::VERSION).not_to be nil
  end

  it 'configures the host from the #setup' do
    described_class.setup do |config|
      config.host = '1.2.3.4'
    end

    expect(described_class.config.host).to eq '1.2.3.4'
  end

  it 'configures the host from the SIDEKIQ_ALIVE_HOST ENV var' do
    ENV['SIDEKIQ_ALIVE_HOST'] = '1.2.3.4'

    SidekiqAlive.config.set_defaults

    expect(described_class.config.host).to eq '1.2.3.4'

    ENV['SIDEKIQ_ALIVE_HOST'] = nil
  end

  it 'configures the port from the #setup' do
    described_class.setup do |config|
      config.port = 4567
    end

    expect(described_class.config.port).to eq 4567
  end

  it 'configures the port from the SIDEKIQ_ALIVE_PORT ENV var' do
    ENV['SIDEKIQ_ALIVE_PORT'] = '4567'

    SidekiqAlive.config.set_defaults

    expect(described_class.config.port).to eq '4567'

    ENV['SIDEKIQ_ALIVE_PORT'] = nil
  end

  it 'configurations behave as expected' do
    k = described_class.config

    expect(k.host).to eq '0.0.0.0'
    k.host = '1.2.3.4'
    expect(k.host).to eq '1.2.3.4'

    expect(k.port).to eq 7433
    k.port = 4567
    expect(k.port).to eq 4567
  end

  before do
    allow(SidekiqAlive).to receive(:redis).and_return(MockRedis.new)
  end

  it '::hostname' do
    expect(SidekiqAlive.hostname).to eq 'test-hostname'
  end
end
