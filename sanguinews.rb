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

@version = '0.44'

require 'date'
require 'tempfile'
require 'rubygems'
require 'optparse'
require 'parseconfig'
require 'monitor'
# Following non-standard gems are needed
require 'nzb'
require 'parallel'
load "#{File.dirname(__FILE__)}/lib/thread-pool.rb"
load "#{File.dirname(__FILE__)}/lib/nntp.rb"
load "#{File.dirname(__FILE__)}/lib/nntp_msg.rb"
load "#{File.dirname(__FILE__)}/lib/file_to_upload.rb"
#load "#{File.dirname(__FILE__)}/lib/y_enc.rb"
#require 'y_enc'

def encode_in_memory(bindata)
  sio = StringIO.new("","w:ASCII-8BIT")
  data = StringIO.open(bindata,"rb")
  special = { 0 => nil, 10 => nil, 13 => nil, 61 => nil }
  until data.eof?
    buffer = data.read(128)
    buffer.each_byte do |b|
      char_to_write = (b + 42) % 256
      if special.has_key?(char_to_write)
        sio.putc '='
        char_to_write = (char_to_write + 64) % 256
      end
      sio.putc char_to_write
    end
    sio.puts "\n"
  end
  result = sio.string
  sio.close
  data.close
  return result
end

# Method returns yenc encoded string and crc32 value
def yencode(file,length)
#  File.open(filepath,"rb") 
   i = 1
   until file.eof?
      bindata = file.read(length)
      message = {}
      message[:yenc] = encode_in_memory(bindata)
      message[:crc32] = Zlib.crc32(bindata,0).to_s(16)
      message[:length] = bindata.length
      message[:chunk] = i
      message[:file] = file
      @messages.push(message)
      i += 1
   end
end

def upload(data)
  message = data[:yenc]
  length = data[:length]
  pcrc32 = data[:crc32]
  file = data[:file]
  chunk = data[:chunk]
  response = ''
  crc32 = file.crc32
  fsize = file.size
  chunks = file.chunks
  basename = file.name
# usenet works with ASCII
  subject="#{@prefix}#{@dirprefix}\"#{basename}\" yEnc (#{chunk}/#{chunks})"
  msg = NntpMsg.new(@from,@groups,subject)
  msg.poster = "sanguinews v#{@version} (ruby) - https://github.com/tdobrovolskij/sanguinews"
  msg.message = message.force_encoding('ASCII-8BIT')
  msg.yenc_body(chunk,chunks,crc32,pcrc32,length,fsize,basename)
  size = msg.size
  msg = msg.return_self
  begin
    Net::NNTP.start(@server, @port, @username, @password, @mode) do |nntp|
      response = nntp.post msg
    end
  rescue
    puts $!, $@ if @verbose
    puts "Upload of chunk " + chunk.to_s + " from file #{basename} unsuccesful. Retrying..." if @verbose
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
c = 1
# for dirmode nzb file's header should be written before we start processing
if dirmode
  dirname = File.basename(directory)
  if @nzb
    @nzb = Nzb.new(dirname,"sanguinews_")
    @nzb.write_header
  end
end

p = Pool.new(@threads)
@unprocessed = 0

files.each do |file|
  next if !File.file?(file)
  if filemode
    if @nzb
      basename = File.basename(file)
      @nzb = Nzb.new(basename,"sanguinews_")
      @nzb.write_header
    end
  end

  @dirprefix = dirname + " [#{c}/#{max}] - " if dirmode

  puts "Uploading #{file}\n"
  file = FileToUpload.new(file)
  fsize = file.size
  crc32 = file.file_crc32
  chunks = file.chunks?(@length)
  puts "Chunks: " + chunks.to_s if @verbose
  basename = file.name
  subject = "#{@prefix}#{@dirprefix}#{basename} yEnc (1/#{chunks})"
  puts subject
  # running this part only once
  if c == 1
    @lock=Mutex.new
    @messages = Queue.new
    @messages.extend(MonitorMixin)
    @cond = @messages.new_cond
  end

  @unprocessed += chunks

  # let's give a little bit higher priority for file processing thread
  @t = Thread.new { yencode(file,@length) }
  @t.priority += 1

#    @nzb.write_file_header(@from,subject,@groups) if @nzb
    while @unprocessed > 0
      p.schedule do
	data = {}
        puts "Current thread count: " + Thread.list.count.to_s if @verbose
        data = @messages.pop
	upload(data)
      end
      @unprocessed -= 1
    end
  
    @nzb.write_file_footer if @nzb

  if !@t.nil?
    @t.join
  end
  
  @nzb.write_footer if @nzb and filemode
  c += 1
end

p.shutdown 

@nzb.write_footer if @nzb and dirmode
