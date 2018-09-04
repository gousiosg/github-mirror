#!/usr/bin/env ruby

require 'bunny'
require 'json'
 
puts 'starting ...'
conn = Bunny.new(:host => '40.117.209.29', :port => 5672, :username => '', :password => '')
conn.start

channel = conn.create_channel
channel.prefetch  1

exchange = channel.topic('github_temp', :durable => true,
                         :auto_delete => false)

puts "setting up queues" 
                        
channel.queue("repositories")
  .bind(exchange, :routing_key => "ent.repos.#")
  .subscribe(:manual_ack => true) do |delivery_info, properties, payload|
    hsh = JSON.parse(payload)
    puts "An update for Repositories: routing key is #{delivery_info.routing_key} - "\
         "Name: #{hsh['name']} "\
         "Forks: #{hsh['forks_count']}  "\
         "Watchers: #{hsh['watchers_count']} "\
         "Stargazers: #{hsh['stargazers_count']} "\
         "Language: #{hsh['language']}"
    channel.acknowledge(delivery_info.delivery_tag, false)
  end

channel.queue("users")
  .bind(exchange, :routing_key => "ent.users.#")
  .subscribe(:manual_ack => true) do |delivery_info, properties, payload|
    puts "An update for Users: routing key is #{delivery_info.routing_key}"
    channel.acknowledge(delivery_info.delivery_tag, false)
  end

channel.queue("commits")
  .bind(exchange, :routing_key => "ent.commits.#")
  .subscribe(:manual_ack => true) do |delivery_info, properties, payload|
    puts "An update for Users: routing key is #{delivery_info.routing_key}"
    channel.acknowledge(delivery_info.delivery_tag, false)
  end

channel.queue("orgs")
  .bind(exchange, :routing_key => "ent.org_members.#")
  .subscribe(:manual_ack => true) do |delivery_info, properties, payload|
    puts "An update for Orgs: routing key is #{delivery_info.routing_key}"
    channel.acknowledge(delivery_info.delivery_tag, false)
  end

channel.queue("forks")
  .bind(exchange, :routing_key => "ent.forks.#")
  .subscribe(:manual_ack => true) do |delivery_info, properties, payload|
    puts "An update for Forks: routing key is #{delivery_info.routing_key}"
    channel.acknowledge(delivery_info.delivery_tag, false)
  end

  channel.queue("issues")
  .bind(exchange, :routing_key => "ent.issues.#")
  .subscribe(:manual_ack => true) do |delivery_info, properties, payload|
    puts "An update for Issues: routing key is #{delivery_info.routing_key}"
    channel.acknowledge(delivery_info.delivery_tag, false)
  end

  channel.queue("pull_requests")
  .bind(exchange, :routing_key => "ent.pull_requests.#")
  .subscribe(:manual_ack => true) do |delivery_info, properties, payload|
    puts "An update for Pull Requests: routing key is #{delivery_info.routing_key}"
    channel.acknowledge(delivery_info.delivery_tag, false)
  end

  channel.queue("followers")
  .bind(exchange, :routing_key => "ent.followers.#")
  .subscribe(:manual_ack => true) do |delivery_info, properties, payload|
    puts "An update for Followers: routing key is #{delivery_info.routing_key}"
    channel.acknowledge(delivery_info.delivery_tag, false)
  end

  channel.queue("watchers")
  .bind(exchange, :routing_key => "ent.watchers.#")
  .subscribe(:manual_ack => true) do |delivery_info, properties, payload|
    puts "An update for Watchers: routing key is #{delivery_info.routing_key}"
    channel.acknowledge(delivery_info.delivery_tag, false)
  end

  stopped = false
  while not stopped
    begin
      sleep(1)
      `clear`
    rescue Interrupt => _
      puts 'Exit requested'
      stopped = true
    end
  end

  puts 'Closing AMQP connection'
  channel.close unless channel.nil?
  conn.close unless conn.nil?

  puts "done"

