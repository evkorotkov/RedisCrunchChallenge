require 'csv'
require 'digest'
require 'set'

Signature = Struct.new(:index, :signature) do
  def <=>(other)
    index <=> other.index
  end
end

class Stats
  def initialize(file_name:)
    @file_name = file_name
  end

  def present
    th = Hash.new(0)
    signatures = SortedSet.new

    CSV.foreach(@file_name) do |row|
      time = row[0]
      second = time[0..9].to_i

      th[second] += 1
      signatures << Signature.new(row[1].to_i, row[2])
    end

    puts "Processed- #{signatures.size}"

    th.each_with_index do |(sec, value), idx|
      puts "sec- #{idx}; TH- #{value}"
    end

    md5 = Digest::MD5.new
    signatures.each { |s| md5 << s.signature }

    puts "Signature- #{md5.hexdigest}"
  end
end

Stats.new(file_name: ARGV[0]).present
