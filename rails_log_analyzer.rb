#!/usr/bin/env ruby

require 'optparse'                                                                                                                                                                                                                                                                                                                                                                                               

options = {:limit => 20}

optparse = OptionParser.new do |opts|
  script_name = File.basename($0)
  opts.banner = "Usage: ruby #{script_name} [options] number"

  opts.separator ""
  
  opts.on('-f', '--file FILE', 'Log file to analyze') do |f|
    options[:file] = f
  end

  opts.on('-l', '--limit NUMBER', Integer, "Limit report max size (default #{options[:limit]})") do |l|
    options[:limit] = l 
  end

  opts.on('-h', '--help', 'Display this screen') do
    puts opts
    exit
  end
end

begin
  optparse.parse!
  required = [:file]
  missing = required.select{ |param| options[param].nil? }
  
  if not missing.empty?               
    puts "Missing options: #{missing.join(', ')}"
    puts optparse
    exit
  end
rescue OptionParser::InvalidOption, OptionParser::MissingArgument
  puts $!.to_s
  puts optparse
  exit
end

controller = nil
action = nil
method = nil

top_slowest_actions = {}
top_error_500_actions = {}
top_db_queries_actions = {}
top_most_requested_actions = {}

begin
  lines = File.readlines(options[:file])

  lines.each { |line|
    total_time = nil
    view_time = nil
    db_time = nil
    status = nil
    queries = nil

    if line =~ /Processing ([a-z\:]+)#([a-z\_]+).+(GET|PUT|POST|DELETE)/i
      controller = $1
      action = $2
      method = $3
    elsif line =~ /Completed in ([0-9]+)ms \((View: ([0-9]+), DB: ([0-9]+)|DB: ([0-9]+)) ([0-9]+) queries\) \| ([0-9]+)/i
      total_time = $1.to_i

      unless $3.nil?
        view_time = $3
        db_time = $4.to_i
        queries = $6.to_i
        status = $7.to_i
      else
        db_time = $5.to_i
        queries = $6.to_i
        status = $7.to_i
      end
    elsif line =~ /Completed in ([0-9]+)ms \((View: ([0-9]+), DB: ([0-9]+)|DB: ([0-9]+)) ([0-9]+) queries\) \| ([0-9]+)/i
      total_time = $1.to_i
      
      unless $3.nil?
        view_time = $3
        db_time = $4.to_i
        queries = $6.to_i
        status = $7.to_i
      else
        db_time = $5.to_i
        queries = $6.to_i
        status = $7.to_i
      end
    elsif line =~ /500 Error/i
      status = 500
    end

    if !total_time.nil? && status < 400
      unless top_slowest_actions.has_key?("#{controller}##{action}")
        top_slowest_actions["#{controller}##{action}"] = {"total_time" => total_time}
      else
        if top_slowest_actions["#{controller}##{action}"]["total_time"] < total_time
          top_slowest_actions["#{controller}##{action}"] = {"total_time" => total_time}
        end
      end

      unless queries.nil?
        unless top_db_queries_actions.has_key?("#{controller}##{action}")
          top_db_queries_actions["#{controller}##{action}"] = {"queries" => queries}
        else
          if top_db_queries_actions["#{controller}##{action}"]["queries"] < queries
            top_db_queries_actions["#{controller}##{action}"] = {"queries" => queries}
          end
        end
      end

      unless top_most_requested_actions.has_key?("#{controller}##{action}")
        top_most_requested_actions["#{controller}##{action}"] = 1
      else
        top_most_requested_actions["#{controller}##{action}"] += 1
      end

      if top_slowest_actions.keys.size > options[:limit]
        tmp = {}

        for a in top_slowest_actions.map{|a,x| [a, x["total_time"]]}.sort{|a,b| b[1] <=> a[1]}[0 .. options[:limit]]
          if tmp.size < options[:limit]
            tmp[a[0]] = {"total_time" => a[1]}
          end
        end

        top_slowest_actions = tmp
      end

      if top_db_queries_actions.size > options[:limit]
        tmp = {}

        for a in top_db_queries_actions.map{|a,x| [a, x["queries"]]}.sort{|a,b| b[1] <=> a[1]}[0 .. options[:limit]]
          if tmp.size < options[:limit]
            tmp[a[0]] = {"queries" => a[1]}
          end
        end

        top_db_queries_actions = tmp
      end
    end

    if !status.nil? && status == 500
      unless top_error_500_actions.has_key?("#{controller}##{action}")
        top_error_500_actions["#{controller}##{action}"] = 1
      else
        top_error_500_actions["#{controller}##{action}"] += 1
      end
    end
  }

  puts "Top slowest actions:"
  for d in top_slowest_actions.map{|a,x| [a, x["total_time"]]}.sort{|a,b| b[1] <=> a[1]}
    puts "#{d[0]} #{d[1]/1000}s"
  end

  puts "\nTop most DB queries actions:"
  for d in top_db_queries_actions.map{|a,x| [a, x["queries"]]}.sort{|a,b| b[1] <=> a[1]}
    puts "#{d[0]} #{d[1]}"
  end

  puts "\nTop most requested actions:"
  for d in top_most_requested_actions.map{|a,x| [a, x]}.sort{|a,b| b[1] <=> a[1]}[0 .. options[:limit] - 1]
    puts "#{d[0]} #{d[1]}"
  end

  puts "\nTop error 500 actions:"
  for d in top_error_500_actions.map{|a,x| [a, x]}.sort{|a,b| b[1] <=> a[1]}[0 .. options[:limit] - 1]
    puts "#{d[0]} #{d[1]}"
  end
rescue Exception => e
  puts e
  exit(1)
end
