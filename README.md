# SidekiqAlive
This project is forked from [sidekiq_alive](https://github.com/arturictus/sidekiq_alive) project.

Besides the original features. this project modified and added some features.

* Set static sidekiq queue instead of run liveness probing jobs in an independent queue for each instance/replica

* Add sidekiq busy count checking HTTP endpoint (default: /busy_count)

* Support multi-process sidekiq mode (`sidekiqswarm`)

* Support both fork/threaded server mode (default: `SidekiqAlive.config.server_mode = :fork`)
## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
