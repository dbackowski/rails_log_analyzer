#!/usr/bin/env ruby

REPORT_LIMIT = 20
  
controller = nil
action = nil
method = nil

top_slowest_actions = {}
top_error_500_actions = {}
top_db_queries_actions = {}
top_most_requested_actions = {}

begin
  lines = File.readlines(ARGV[0])

  lines.each { |line|
    total_time = nil
    view_time = nil
    db_time = nil
    status = nil
    queries = nil
    
    line.scan(/Processing ([a-z\:]+)#([a-z\_]+).+(GET|PUT|POST|DELETE)/i).each { |t|
      controller = t[0]
      action = t[1]
      method = t[2]
    }

    line.scan(/Completed in ([0-9]+)ms \((View: ([0-9]+), DB: ([0-9]+)|DB: ([0-9]+)) ([0-9]+) queries\) \| ([0-9]+)/i).each { |t|
      total_time = t[0].to_i
      
      unless t[2].nil?
        view_time = t[2]
        db_time = t[3].to_i
        queries = t[5].to_i
        status = t[6].to_i
      else
        db_time = t[4].to_i
        queries = t[5].to_i
        status = t[6].to_i
      end
    }

    if status.nil?
      if line =~ /500 Error/i
        status = 500
      end
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

      if top_slowest_actions.keys.size > REPORT_LIMIT
        min = top_slowest_actions.map{|a,x| x["total_time"]}[0 .. REPORT_LIMIT].sort{|a,b| b <=> a}.min
        top_slowest_actions.delete_if{|key, value| value["total_time"] <= min && top_slowest_actions.keys.size > REPORT_LIMIT}
      end

      if top_db_queries_actions.size > REPORT_LIMIT
        min = top_db_queries_actions.map{|a,x| x["queries"]}[0 .. REPORT_LIMIT].sort{|a,b| b <=> a}.min
        top_db_queries_actions.delete_if{|key, value| value["queries"] <= min && top_db_queries_actions.keys.size > REPORT_LIMIT}
      end

      if top_most_requested_actions.size > REPORT_LIMIT
        min = top_most_requested_actions.map{|a,x| x}[0 .. REPORT_LIMIT].sort{|a,b| b <=> a}.min
        top_most_requested_actions.delete_if{|key, value| value <= min && top_most_requested_actions.keys.size > REPORT_LIMIT}
      end
    end

    if !status.nil? && status == 500
      unless top_error_500_actions.has_key?("#{controller}##{action}")
        top_error_500_actions["#{controller}##{action}"] = 1
      else
        top_error_500_actions["#{controller}##{action}"] += 1
      end

      if top_error_500_actions.size > REPORT_LIMIT
        min = top_error_500_actions.map{|a,x| x}[0 .. REPORT_LIMIT].sort{|a,b| b <=> a}.min
        top_error_500_actions.delete_if{|key, value| value <= min && top_error_500_actions.keys.size > REPORT_LIMIT}
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
  for d in top_most_requested_actions.map{|a,x| [a, x]}.sort{|a,b| b[1] <=> a[1]}
    puts "#{d[0]} #{d[1]}"
  end

  puts "\nTop error 500 actions:"
  for d in top_error_500_actions.map{|a,x| [a, x]}.sort{|a,b| b[1] <=> a[1]}
    puts "#{d[0]} #{d[1]}"
  end
rescue Exception => e
  puts e
  exit(1)
end