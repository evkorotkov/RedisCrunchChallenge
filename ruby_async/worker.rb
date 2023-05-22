# frozen_string_literal: true

require 'oj'
require 'json'
require 'csv'
require 'openssl'
require 'async'
require 'async/container'
require 'async/io'
require 'async/redis'

class Worker
  DISCOUNTS_MAP = {
    0 => 0,
    1 => 5,
    2 => 10,
    3 => 15,
    4 => 20,
    5 => 25,
    6 => 30
  }.freeze
  CONCURRENCY = Async::Container.processor_count
  TASKS = 8

  attr_reader :io, :redis

  def initialize
    redis_uri = URI("redis://#{ENV['REDIS_HOST']}:6379")
    @redis = Async::Redis::Client.new(
      Async::IO::Endpoint.tcp(redis_uri.hostname, redis_uri.port)
    )
    @io = Async::IO::Stream.open("/scripts/output/ruby_async-#{Time.now.to_i}.csv", 'a+', deferred: true, sync: false)
  end

  def run
    async_task do |csv|
      while data = redis.call('BRPOP', 'events_queue', '5')
        data = JSON.parse(data[1], symbolize_names: true)
        signature = process_event(data)
        csv << [Time.now.to_i, data[:index], signature]
      end
    end
  end

  def async_task
    container = Async::Container::Forked.new
    container.run(count: CONCURRENCY) do
      Async do |task|
        csv = CSV.new(io)
        TASKS.times.map { task.async { yield(csv) } }.each(&:wait)
        io.close
        redis.close
      end
    end
    container.wait
  ensure
    container&.stop
  end

  def process_event(data)
    data[:total] = (data[:price] * (1 - DISCOUNTS_MAP.fetch(data[:wday], 0) / 100.0)).round(2)

    OpenSSL::Digest::MD5.hexdigest(JSON.dump(data))
  end
end

Worker.new.run
