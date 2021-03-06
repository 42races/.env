#!/usr/bin/env ruby

require 'bundler'
require 'yaml'

Bundler.require(:default)

$pastel = Pastel.new

module Bro

  module OutputHelpers

    def print_line(msg, color = :green)
      puts $pastel.send(color.to_sym, msg)
    end

    def print_error(msg, color = :red)
      puts $pastel.send(color.to_sym, msg)
    end
  end

  module CommandHelpers

    def run_secure_connect_command(type, server, user)
      ip = Bro.config['servers'][server]

      if ip.nil?
        print_error "#{server}: server not found in the list"
        exit(1)
      end

      command = "#{type} #{user}@#{ip}"

      begin
        print_line "Running: #{command} use Password: #{Bro.config['dev_password']} for dev"
        system(command)
      rescue => ex
        print_error ex.message
      end
    end

    def histogram(label, n, max=100)
      max = max < 100 ? 100 : max
      count = (n/max.to_f)*100
      count = 1 if count < 1
      str = "*" * count
      [label, n, "#{str} #{n}"].join("\t")
    end
  end

  class Bro < Thor
    def self.config
      @config ||= YAML.load(File.read(File.expand_path("../../config.yml", __FILE__)))
    end

    no_commands do
      include OutputHelpers
      include CommandHelpers
    end

    desc "hello", "Say hello to bro"
    def hello
      print_line "Hello, Bro. Good to see you today. Need some help ? Just call help.", :yellow
      progress = ProgressBar.create
      50.times { progress.increment; sleep 0.1 }
    end

    desc "list servers", "bro servers"
    def servers
      require 'terminal-table'
      rows = Bro.config['servers'].to_a
      table = Terminal::Table.new(:title => "Server List", :headings => ['Name', 'IP'], :rows => rows)
      table.align_column(1, :right)
      puts table
    end

    desc "ssh to servers", "bro ssh <server_name>"
    def ssh(server, user='dev')
      run_secure_connect_command("ssh", server, user)
    end

    desc "sftp to servers", "bro sftp <server_name>"
    def sftp(server, user='dev')
      run_secure_connect_command("sftp", server, user)
    end

    desc "start service", "bro start <service_name>"
    def start(name)
      case name
      when 'server' then
        command = "ruby -run -e httpd -- -p 5000 ."
        print_line "Running #{command}"
        system(command)
      when 'mongodb' then
        command = "mongod --journal --fork --logpath=/dev/null"
        print_line "Starting mongodb server"
        print_line "Running #{command}"
        system(command)
      when 'redis'
        command = "redis-server ~/.env/conf/redis.conf"
        print_line "Starting redis server"
        print_line "Running #{command}"
        system(command)
      when 'vm', 'tm'
        command = "VBoxManage startvm turingmachine --type headless"
        print_line "Starting VirtualBox loading turingmachine"
        print_line "Running #{command}"
        system(command)
      else
        print_line "Teach me how to start #{name}, I will do it next time."
      end
    end

    desc "scan port", "bro scan <hostname> range"
    def scan(hostname, range=0)
      command = "nmap -n -sP #{hostname}/#{range}"
      system(command)
    end

    desc "view commit histogram", "bro commits"
    def commits
      command = 'git log --date=short | grep Date: | cut -d " " -f4 | uniq -c'
      result = IO.popen(command).read
      lines = result.split("\n")
      max = lines.map { |line| line.split.first.to_i }.max

      puts max

      lines.each do |line|
        label, count = line.split.reverse
        print_line histogram(label, count.to_i, max), :cyan
      end
    end

    desc "view authors commits histogram", "bro authors commits"
    def authors_commits
      command = 'git log | grep Author: |  cut -d "<" -f2 | cut -d "@" -f1 | sort | uniq -c'
      result = IO.popen(command).read
      lines = result.split("\n")
      max = lines.map { |line| line.split.first.to_i }.max

      to_name = Proc.new do |name|
        name.gsub(/\W/, " ").strip.split.map(&:capitalize).join(" ")
      end

      lines.each do |line|
        label, count = line.split.reverse
        print_line histogram(to_name.call(label).ljust(30), count.to_i, max), :cyan
      end
    end
  end
end

Bro::Bro.start(ARGV)
