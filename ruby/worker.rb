# frozen_string_literal: true

require 'oj'
require 'redis'
require 'json'
require 'csv'
require 'connection_pool'
require 'digest'

class Worker
  STOP_SIGNALS = ['QUIT', 'INT', 'TERM'].freeze
  OUTPUT_FILE_NAME = 'output/ruby.csv'
  CSV_MUTEX = Mutex.new
  DISCOUNTS_MAP = {
    0 => 0,
    1 => 5,
    2 => 10,
    3 => 15,
    4 => 20,
    5 => 25,
    6 => 30
  }.freeze

  attr_reader :threads_count, :threads, :redis_pool, :redis, :csv

  def initialize(threads_count: nil)
    @threads_count = threads_count&.to_i || 1
    @threads = []

    # @redis_pool = ConnectionPool.new(size: threads_count * 1.5) { Redis.new }
    @redis = Redis.new
    @csv = CSV.open("#{OUTPUT_FILE_NAME}.#{Time.now.to_i}", 'a+')
  end

  def run
    setup_stop_signal
    spawn_threads
  end

  private

  def setup_stop_signal
    STOP_SIGNALS.each do |signal|
      trap(signal) do
        puts "stopping..."
        @stopped = true
      end
    end
  end

  def spawn_threads
    threads_count.times.each do
      @threads << Thread.new do
        while true
          if @stopped || @finished
            puts "stopped..."
            Thread.current.exit
          end

          handle_events
        end
      end
    end

    @threads.each(&:join)
  end

  def handle_events
    # _, data = redis_pool.with do |redis|
    #   redis.brpop(:events_queue, 5)
    # end

    _, data = redis.brpop(:events_queue, 5)

    if data.nil?
      @finished = true
      return
    end

    data = JSON.parse(data, symbolize_names: true)
    signature = process_event(data)

    CSV_MUTEX.synchronize do
      csv << [Time.now.to_i, data[:index], signature]
    end
  end

  def process_event(data)
    data[:total] = data[:price] * (1 - DISCOUNTS_MAP.fetch(data[:wday], 0) / 100.0)

    Digest::MD5.hexdigest(JSON.dump(data))
  end
end

Worker.new(threads_count: ARGV[0]).run
