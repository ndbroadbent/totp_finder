#!/usr/bin/env ruby
require 'rubygems'
require 'bundler/setup'

require 'yaml'
# https://github.com/mdp/rotp
require 'rotp'
require 'active_support/core_ext/numeric/time'
require 'active_support/core_ext/date_time'
require 'active_support/core_ext/time'
require 'pry-byebug'

# https://github.com/radar/distance_of_time_in_words
require 'dotiw'
include DOTIW::Methods

require 'icalendar'

# secrets = YAML.load_file('./secrets.yml')
# totps = {}
# secrets.each do |k, secret|
#   totps[k] = ROTP::TOTP.new(secret)
# end

# binding.pry

otpauth_lines = File.read('./otpauthexport.txt').strip.lines.map(&:strip)
totps = {}
otpauth_lines.each do |line|
  service = line.gsub('%20', ' ')[/otpauth:\/\/totp\/([^?]+)\?/, 1]
  details = line.split('?').last.split('&').map{ |v| v.split('=') }.to_h
  secret = details&.fetch('secret', nil)

  raise "Error! service: #{service}, secret: #{details['secret']}, details: #{details}"  \
    unless service && secret
  
    totps[service] = ROTP::TOTP.new(
    details['secret'], 
    interval: details['period'].to_i, 
    issuer: details['issuer']
  )
end

# Create a calendar with an event (standard method)
cal = Icalendar::Calendar.new

puts "Searching for interesting TOTP codes:"

# Round down to nearest 30 seconds
start_time = Time.at((DateTime.now.to_f / 30).floor * 30).to_datetime

offset_seconds = 0
loop do
  found = false
  time = start_time + offset_seconds.seconds

  totps.each do |service, totp|
    code = totp.at(time)
    
    next unless (code.split('').uniq.size == 1 || code == '123456')
    
    puts "#{code} - #{distance_of_time_in_words(Time.now, time)} from now (#{time.to_s(:long)}) [#{service}]"        

    event = cal.event
    event.dtstart = time
    event.dtend   = time + 30.seconds
    event.summary = "TOTP #{code}: #{service}"

    found = true
    break
  end
  # break if found
  # break if offset_seconds > (60 * 60 * 24 * 365 * 2)
  break if offset_seconds > (60 * 60 * 24 * 30)

  offset_seconds += 30
end

cal_string = cal.to_ical
puts "Writing iCal events to totp_ical.ics"
File.open('totp_ical.ics', 'w') {|f| f.puts cal_string }
