# frozen_string_literal: true

require 'oj'
require 'redis'
require 'hiredis-client'
require 'json'
require 'csv'
require 'openssl'
require 'concurrent-ruby'

class Reader
  DISCOUNTS_MAP = {
    0 => 0,
    1 => 5,
    2 => 10,
    3 => 15,
    4 => 20,
    5 => 25,
    6 => 30
  }.freeze

  BRPOP_OPTIONS = { timeout: 5 }.freeze

  attr_reader :redis, :thread, :results

  def initialize(results)
    @redis = Redis.new(driver: :hiredis, host: ENV['REDIS_HOST'])
    @results = results
  end

  def start
    @thread = Thread.new do
      while !results.closed?
        process_events
      end
    end
  end

  def join
    thread.join
  end

  def process_events
    popped = redis.brpop(:events_queue, BRPOP_OPTIONS)

    if popped.nil?
      results.close unless results.closed?

      return
    end

    _, data = popped

    data = JSON.parse(data, symbolize_names: true)
    signature = process_event(data)

    results.push([Time.now.to_i, data[:index], signature])
  end

  def process_event(data)
    data[:total] = (data[:price] * (1 - DISCOUNTS_MAP.fetch(data[:wday], 0) / 100.0)).round(2)

    OpenSSL::Digest::MD5.hexdigest(JSON.dump(data))
  end
end

class Writer
  attr_reader :csv, :thread, :results

  def initialize(results)
    @csv = CSV.open("/scripts/output/ruby-#{Time.now.to_i}.csv", 'a+')

    @results = results
  end

  def start
    @thread = Thread.new do
      written = 0

      checker = Concurrent::TimerTask.new(execution_interval: 1) do
        puts "Written: #{written} Size: #{results.size} Waiting: #{results.num_waiting}"
        written = 0
      end

      checker.execute

      while !results.closed?
        item = results.pop

        unless item.nil?
          written = written + 1
          csv << item
        end
      end
    end
  end

  def join
    thread.join
  end
end

class Watcher
  STOP_SIGNALS = ['QUIT', 'INT', 'TERM'].freeze

  attr_reader :results, :thread

  def initialize(results)
    @result = results
  end

  def start
    @thread = Thread.new do
      STOP_SIGNALS.each do |signal|
        trap(signal) do
          puts "Got, #{signal}. Stopping..."

          stop
        end
      end
    end
  end

  def stop
    results.close
  end

  def join
    thread.join
  end
end

class Worker
  attr_reader :threads

  def initialize
    @threads = []
  end

  def run
    results = SizedQueue.new(1024)

    watcher = Watcher.new(results)
    writer = Writer.new(results)

    threads << watcher
    threads << writer

    threads_count.times.each do
      threads << Reader.new(results)
    end

    threads.each(&:start)
    threads.each(&:join)
  end

  def threads_count
    (ENV['WORKERS'] || Concurrent.processor_count).to_i
  end
end

Worker.new.run
