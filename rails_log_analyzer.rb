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

def table_output(labels=[], data=[])
  first_column_length = data.sort{ |a,b| b[0].length <=> a[0].length }[0][0].length
  second_column_length = data.sort{ |a,b| b[1].length <=> a[1].length }[0][1].length
  third_column_length = data.sort{ |a,b| b[2].to_s.length <=> a[2].to_s.length }[0][2].to_s.length
  
  if first_column_length < labels[0].length
    first_column_length = labels[0].length
  end
  
  if second_column_length < labels[1].length
    second_column_length = labels[1].length
  end
  
  if third_column_length < labels[2].length
    third_column_length = labels[2].length
  end
  
  tmp = ''
  (first_column_length + second_column_length + third_column_length + 10).times { tmp << '_' }
  puts tmp
  puts "| %-#{first_column_length}s | %-#{second_column_length}s | %-#{third_column_length}s |" % [labels[0], labels[1], labels[2]]
  
  tmp = ''
  (first_column_length + second_column_length + third_column_length + 10).times { tmp << '-' }
  tmp[0] = '|'
  tmp[first_column_length+3] = '+'
  tmp[first_column_length+3 + second_column_length+3] = '+'
  tmp[tmp.length - 1] = '|'
  puts tmp
  
  for line in data
    puts "| %-#{first_column_length}s | %-#{second_column_length}s | %-#{third_column_length}s |" % [line[0], line[1], line[2]]
  end
  
  tmp = ''
  (first_column_length + second_column_length + third_column_length + 10).times { tmp << '-' }
  puts tmp
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
  table_output(['Controller', 'Action', 'Total time [seconds]'], top_slowest_actions.map{|a,x| [a.split('#')[0], a.split('#')[1], x["total_time"]/1000]}.sort{|a,b| b[2] <=> a[2]})

  puts "\nTop most DB queries actions:"
  table_output(['Controller', 'Action', 'Queries count'], top_db_queries_actions.map{|a,x| [a.split('#')[0], a.split('#')[1], x["queries"]]}.sort{|a,b| b[2] <=> a[2]})

  puts "\nTop most requested actions:"
  table_output(['Controller', 'Action', 'Requested count'], top_most_requested_actions.map{|a,x| [a.split('#')[0], a.split('#')[1], x]}.sort{|a,b| b[2] <=> a[2]}[0 .. options[:limit] - 1])

  puts "\nTop error 500 actions:"
  table_output(['Controller', 'Action', 'Errors count'], top_error_500_actions.map{|a,x| [a.split('#')[0], a.split('#')[1], x]}.sort{|a,b| b[2] <=> a[2]}[0 .. options[:limit] - 1])
rescue Exception => e
  puts e
  exit(1)
end
