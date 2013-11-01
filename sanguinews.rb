#!/usr/bin/env ruby
########################################################################
# sanguinews - usenet command line binary poster written in ruby
# Copyright (c) 2013, Tadeus Dobrovolskij
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
########################################################################
# We will be using nntp and yEnc gems
begin
  gem "yEnc", ">=0.0.30"
  gem "nntp"
  gem "parseconfig"
rescue Gem::LoadError
  # not installed
end

require 'date'
require 'tempfile'
require 'rubygems'
require 'optparse'
require 'parseconfig'
# Needed for crc32 calculation
require 'zlib'
# Following non-standard gems are needed
load 'lib/nntp.rb'
load 'lib/y_enc'
#require 'y_enc'

# Method returns yenc encoded string and crc32 value
def yencode(filepath,length,partnumber)
  offset = (partnumber - 1) * length
  puts "Offset: " + offset.to_s if @verbose
  bindata = IO.binread(filepath,length,offset)
  tmpfile = Tempfile.new('sanguinews')
  tmpfile.binmode
  tmppath = tmpfile.path
  IO.binwrite(tmpfile,bindata)
  y = YEnc.new(tmppath,"./")
  yencoded = y.encode
  crc = file_crc32(tmppath)
  result = [ yencoded, crc ]
  tmpfile.close
  tmpfile.unlink
  return result
end

# Method creates message according to yenc specifications
# returns string
def create_message(message,curpart,parts,crc32,pcrc32,psize,fsize,filename)
  chunk_start = ((curpart - 1) * psize) + 1
  chunk_end = curpart * psize
  if (parts==1)
    headerline = "=ybegin line=128 size=#{fsize} name=#{filename}"
    trailer = "=yend size=#{fsize} crc32=#{crc32}"
  else
    headerline = "=ybegin part=#{curpart} total=#{parts} line=128 size=#{fsize} name=#{filename}\n=ypart begin=#{chunk_start} end=#{chunk_end}"
# last part
    if (curpart == parts)
      trailer = "=yend size=#{psize} part=#{curpart} pcrc32=#{pcrc32} crc32=#{crc32}"
    else
      trailer = "=yend size=#{psize} part=#{curpart} pcrc32=#{pcrc32}"
    end
  end
  date = DateTime.now().strftime(fmt='%a, %d %b %Y %T %z')
  msgstr = <<END_OF_MESSAGE
From: #{@from}
Newsgroups: #{@groups}
Subject: #{@prefix}"#{filename}" yEnc (#{curpart}/#{parts})
Date: #{date}

#{headerline}
#{message}
#{trailer}
END_OF_MESSAGE

  return msgstr
end

# Method from y_enc gem
# Big thanks to Sam "madgeekfiend" Contapay(https://github.com/madgeekfiend)
def file_crc32 filepath
  f = nil
  File.open( filepath, "rb") { |h| f = h.read }
  Zlib.crc32(f,0).to_s(16)
end

# Method processes the file and uploads result
def process_and_upload(filepath,length,chunk)
  yencmsg = ''
  yenced = yencode(filepath,length,chunk)
  yencmsg = yenced[0]
  pcrc32 = yenced[1]
# usenet works with ASCII
  yencmsg.force_encoding('ASCII-8BIT')
  msg = create_message(yencmsg, chunk, @chunks, @crc32, pcrc32, length, @fsize, @basename)
  begin
    Net::NNTP.start(@server, @port, @username, @password, @mode) do |nntp|
      nntp.post msg
    end
  rescue
    puts $!, $@
    puts "Upload of chunk " + chunk.to_s + "from file #{@basename} unsuccesful. Retrying..." if @verbose
    sleep @delay
    retry
  end
  if @verbose
    puts "Uploaded chunk Nr:" + chunk.to_s
  else
    putc "."
  end
end

# Parse options in config file
config = "~/.sanguinews.conf"
config = File.expand_path(config)
if ! File.exist?(config)
  puts "Config file does not exist. Aborting..."
  exit
end
config = ParseConfig.new(config)
config.get_params()
@username = config['username']
@password = config['password']
@from = config['from']
@server = config['server']
@port = config['port']
@threads = config['connections'].to_i
@length = config['article_size'].to_i
@delay = config['reconnect_delay'].to_i
@groups = config['groups']
@prefix = config['prefix']
ssl = config['ssl']
if ssl == 'yes'
  @mode = :tls
else
  @mode = :original
end

# option parser
options = {}

opt_parser = OptionParser.new do |opt|
  opt.banner = "Usage: #{$0} [OPTIONS]"
  opt.separator  ""
  opt.separator  "Options"

  opt.on("-f","--file FILE","upload FILE") do |file|
    options[:file] = file
  end
  opt.on("-h","--help","help") do
    puts opt_parser
    exit
  end
  opt.on("-p","--password PASSWORD","use PASSWORD as your password(overwrites config file)") do |password|
    options[:password] = password
  end
  opt.on("-u","--user USERNAME","use USERNAME as your username(overwrites config file)") do |username|
    options[:username] = username
  end
  opt.on("-v","--verbose","be verbose?") do
    options[:verbose] = true
  end
end

opt_parser.parse!

puts options

file = options[:file].to_s
password = options[:password]
username = options[:username]
options[:verbose] ? @verbose = true : @verbose = false

#puts ARGV
#exit

@username = username if ! username.nil?
@password = password if ! password.nil?

if !File.file?(file) and !Dir.exist?(ARGV)
  puts "Nothing to upload!"
  exit
end

#  yencmsg.encode!('UTF-8')
@fsize = File.size?(file)
@chunks = @fsize.to_f / @length
@chunks = @chunks.ceil
puts "Chunks: " + @chunks.to_s if @verbose
@crc32 = file_crc32(file)
@basename = File.basename(file)
i = 1
arr = []

while i <= @chunks
  # c = current thread
  c = i % @threads

  if Thread.list.count <= @threads
    arr[c] =  Thread.new(i){ |j| process_and_upload(file,@length,j) }
  else
    arr[c].join if ! arr[c].nil?
    redo
  end
  puts "Current thread count: " + Thread.list.count.to_s if @verbose
  i += 1
end

# Wait for all threads to finish
arr.each do |t|
  t.join if ! t.nil?
end

puts
