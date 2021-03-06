#!/usr/bin/env ruby

$stdout.sync = true

require 'open3'

class Test
  attr_reader :number, :infile, :outfile

  def initialize infile, outfile
    @infile = infile
    @outfile = outfile
    @number = File.basename(@infile.path, ".cfm")
  end
end

class Result
  attr_reader :test, :actual

  TMP_FILE = "/tmp/cfscriptify_test"

  def initialize test, actual
    @test = test
    @actual = actual
  end

  def print
    expected = test.outfile.read
    if expected == actual
      green "."
    else
      red "\nTest #{number} failed\n"
      File.open(TMP_FILE, "w") { |f| f.write(actual) }
      system "diff -U 3 #{test.outfile.path} #{TMP_FILE} | tail +4"
    end
  end

  private

  def green str
    $stdout.print "\e[32m" + str.to_s + "\e[0m"
  end

  def red str
    $stdout.print "\e[31m" + str.to_s + "\e[0m"
  end

  def number
    test.number
  end
end

class TestSuite
  INPUTS = 'src/test/input'
  OUTPUTS = 'src/test/output'

  def initialize
    @tests = find_tests
  end

  def run
    results.each(&:print)
    puts # LF
  end

  private

  def results
    run_concatenated.zip(@tests).map { |a| Result.new(a[1], a[0]) }
  end

  def run_concatenated
    Open3.popen3(cmd) { |stdin, stdout, stderr, wait_thr|
      @tests.each do |test|
        stdin.print test.infile.read
        stdin.print "<!--- most awkward delimiter, ever --->"
      end
      stdin.close
      $stderr.print(stderr.read)
      stdout.read
    }.split("/* most awkward delimiter, ever */\n")
  end

  def cmd
    "java -jar target/cfscriptify-0.0.1.jar"
  end

  def paths
    Dir.glob "#{INPUTS}/*.cfm"
  end

  def find_tests
    paths.map { |p|
      outfile = File.join([OUTPUTS, File.basename(p)])
      if File.exists?(outfile)
        Test.new(File.new(p), File.new(outfile))
      else
        $stderr.puts "File not found: #{outfile}"
      end
    }.compact
  end
end

TestSuite.new.run
