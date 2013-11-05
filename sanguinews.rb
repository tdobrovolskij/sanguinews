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

# TODO: implement normal check for installed gems
begin
  gem "yEnc", ">=0.0.30"
  gem "nntp"
  gem "parseconfig"
rescue Gem::LoadError
  # not installed
end

@version = '0.41'

require 'date'
require 'tempfile'
require 'rubygems'
require 'optparse'
require 'parseconfig'
# Needed for crc32 calculation
require 'zlib'
# Following non-standard gems are needed
require 'nzb'
load "#{File.dirname(__FILE__)}/lib/nntp.rb"
load "#{File.dirname(__FILE__)}/lib/nntp_msg.rb"
#load "#{File.dirname(__FILE__)}/lib/y_enc.rb"
#require 'y_enc'

def encode_in_memory(bindata)
  sio = StringIO.new("","w:ASCII-8BIT")
  bindata.force_encoding('ASCII-8BIT')
  i = 0
  bindata.each_byte do |b|
    char_to_write = (b + 42) % 256
    if [0, 10, 13, 61].include?(char_to_write)
      sio.putc '='
      char_to_write = (char_to_write + 64) % 256
    end
    sio.putc char_to_write
    if i == 127
      sio.puts "\n"
      i = 0
    else
      i += 1
    end
  end
  result = sio.string
  sio.close
  return result
end

# Method returns yenc encoded string and crc32 value
def yencode(filepath,length)
  i = 0
  #result = Array.new
  File.open(filepath,"rb") do |f|
    until f.eof?
      bindata = f.read(length)
      @lock.lock
      @messages[i] = Array.new
      @messages[i][0] = encode_in_memory(bindata)
      @messages[i][1] = Zlib.crc32(bindata,0).to_s(16)
      i += 1
      @lock.unlock
    end
  end
end

# Method from y_enc gem
# Big thanks to Sam "madgeekfiend" Contapay(https://github.com/madgeekfiend)
def file_crc32 filepath
  f = nil
  File.open( filepath, "rb") { |h| f = h.read }
  Zlib.crc32(f,0).to_s(16)
end

def upload(message,length,pcrc32,chunk)
  response = ''
# usenet works with ASCII
  subject="#{@prefix}#{@dirprefix}\"#{@basename}\" yEnc (#{chunk}/#{@chunks})"
  msg = NntpMsg.new(@from,@groups,subject)
  msg.poster = "sanguinews v#{@version} (ruby) - https://github.com/tdobrovolskij/sanguinews"
  msg.message = message.force_encoding('ASCII-8BIT')
  msg.yenc_body(chunk,@chunks,@crc32,pcrc32,length,@fsize,@basename)
  size = msg.size
  msg = msg.return_self
  begin
    Net::NNTP.start(@server, @port, @username, @password, @mode) do |nntp|
      response = nntp.post msg
    end
  rescue
    puts $!, $@ if @verbose
    puts "Upload of chunk " + chunk.to_s + " from file #{@basename} unsuccesful. Retrying..." if @verbose
    sleep @delay
    retry
  end
  if @verbose
    puts "Uploaded chunk Nr:" + chunk.to_s
  else
    putc "."
  end
  if @nzb
    msgid = ''
    response.each do |r|
      msgid = r.sub(/>.*/,'').tr("<",'') if r.end_with?('Article posted')
    end
    @lock.lock
    @nzb.write_segment(size,chunk,msgid)
    @lock.unlock
  end
end


def process(file)
  puts "Uploading #{file}\n"
  @fsize = File.size?(file)
  @chunks = @fsize.to_f / @length
  @chunks = @chunks.ceil
  puts "Chunks: " + @chunks.to_s if @verbose
  @crc32 = file_crc32(file)
  @basename = File.basename(file)
  i = 0
  arr = []
  subject = "#{@prefix}#{@dirprefix}#{@basename} yEnc (1/#{@chunks})"
  puts subject
  @nzb.write_file_header(@from,subject,@groups) if @nzb
  @lock=Mutex.new
  @messages = []
  done = 0
  
  arr[i] = Thread.new { yencode(file,@length) }
  arr[i].priority += 1
  while done < @chunks
    if !@messages.empty?
      puts "Current thread count: " + Thread.list.count.to_s if @verbose
      if Thread.list.count <= @threads + 1 and !@messages.empty?
	message = ''
	@lock.lock
        message = @messages[0][0].force_encoding('ASCII-8BIT')
	pcrc32 = @messages[0][1]
	@messages.drop(1)
	i += 1
	@lock.unlock
	if i <= @chunks and !message.empty?
          arr[i] =  Thread.new(i){ |j|
	    upload(message,@length,pcrc32,j)
	    sleep 0.5
	    @lock.lock
	    done += 1
	    @lock.unlock
          }
	else
          sleep 0.5
	end
      else
        sleep 0.5
      end
    else
      sleep 0.5
    end
  end


  # Wait for all threads to finish
  arr.each do |t|
    t.join if ! t.nil?
  end

  puts
  @nzb.write_file_footer if @nzb
end

def parse_config(config)
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
  @dirprefix = ''
  ssl = config['ssl']
  if ssl == 'yes'
    @mode = :tls
  else
    @mode = :original
  end
  @nzb = false
  @nzb = true if config['nzb'] == 'yes'
end


# Parse options in config file
config = "~/.sanguinews.conf"
config = File.expand_path(config)
# variable to store if config was parsed
saw_config = false
if File.exist?(config)
  saw_config = true
  parse_config(config)
end

# version and legal info presented to user
banner = []
banner << ""
banner << "sanguinews v#{@version}. Copyright (c) 2013 Tadeus Dobrovolskij."
banner << "Comes with ABSOLUTELY NO WARRANTY. Distributed under GPL v2 license(http://www.gnu.org/licenses/gpl-2.0.txt)."
banner << "sanguinews is a simple nntp(usenet) binary poster. It supports multithreading and SSL. More info in README."
banner << ""
# option parser
options = {}
dirmode = true
filemode = false

opt_parser = OptionParser.new do |opt|
  opt.banner = "Usage: #{$0} [OPTIONS] [DIRECTORY] | -f FILE1..[FILEX]"
  opt.separator  ""
  opt.separator  "Options"

  opt.on("-c","--config CONFIG","use different config file") do |config|
    options[:config] = config
  end
  opt.on("-f","--file FILE","upload FILE, treat all additional parameters as files") do |file|
    options[:file] = file
    filemode = true
    dirmode = false
  end
  opt.on("-h","--help","help") do
    banner.each do |msg|
      puts msg
    end
    puts opt_parser
    puts
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

files = []
password = options[:password]
username = options[:username]

optconfig = options[:config]
optconfig = '' if optconfig.nil?
if !File.exist?(optconfig) && !saw_config
  puts "No config information specified. Aborting..."
  exit
end
parse_config(optconfig) if File.exist?(optconfig)

options[:verbose] ? @verbose = true : @verbose = false
files << options[:file].to_s if filemode

@username = username if ! username.nil?
@password = password if ! password.nil?
directory = ARGV[0] if dirmode
# in file mode treat every additional parameter as a file
if !ARGV.empty? and filemode
  ARGV.each do |file|
    files << file.to_s
  end
end

# skip hidden files
if dirmode
  directory = directory + "/" if !directory.end_with?('/')
  Dir.foreach(directory) do |item|
    next if item.start_with?('.')
    files << directory+item
  end
end

# "max" is needed only in dirmode
max = files.length
i = 1
# for dirmode nzb file's header should be written before we start processing
if dirmode
  dirname = File.basename(directory)
  if @nzb
    @nzb = Nzb.new(dirname,"sanguinews_")
    @nzb.write_header
  end
end
files.each do |file|
  next if !File.file?(file)
  if filemode
    if @nzb
      basename = File.basename(file)
      @nzb = Nzb.new(basename,"sanguinews_")
      @nzb.write_header
    end
  end

  @dirprefix = dirname + " [#{i}/#{max}] - " if dirmode
  process(file)
  @nzb.write_footer if @nzb and filemode
  i += 1
end

@nzb.write_footer if @nzb and dirmode
