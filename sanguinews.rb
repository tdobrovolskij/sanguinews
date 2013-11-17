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

@version = '0.45.1'

require 'rubygems'
require 'bundler/setup'
require 'optparse'
require 'monitor'
require 'date'
require 'tempfile'
# Following non-standard gems are needed
require 'nzb'
require 'parseconfig'
load "#{File.dirname(__FILE__)}/lib/thread-pool.rb"
load "#{File.dirname(__FILE__)}/lib/nntp.rb"
load "#{File.dirname(__FILE__)}/lib/nntp_msg.rb"
load "#{File.dirname(__FILE__)}/lib/file_to_upload.rb"
load "#{File.dirname(__FILE__)}/lib/yencoded.rb"

# Method returns yenc encoded string and crc32 value
def yencode(file,length)
   i = 1
   until file.eof?
      bindata = file.read(length)
      # We can't take all memory, so we wait
      @messages.synchronize do
	@cond.wait_while do
	  @messages.length > @threads * 2
	end
      end
      data = {}
      len = bindata.length
      data[:yenc] = Yencoded.new.yenc(bindata,len)
      data[:crc32] = Zlib.crc32(bindata,0).to_s(16)
      data[:length] = len
      data[:chunk] = i
      data[:file] = file
      @messages.push(data)
      i += 1
   end
end

def upload(data,nzb_file)
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
  msg.poster = "sanguinews v#{@version} (ruby #{RUBY_VERSION}) - https://github.com/tdobrovolskij/sanguinews"
  msg.xna = @xna
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
    nzb_file.write_segment(size,chunk,msgid)
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
  xna = config['xna']
  if xna == 'yes'
    @xna = true
  else
    @xna = false
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
unprocessed = 0
@lock=Mutex.new
@messages = Queue.new
@messages.extend(MonitorMixin)
@cond = @messages.new_cond
nzbs = []

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

  unprocessed += chunks

  # let's give a little bit higher priority for file processing thread
  @t = Thread.new { yencode(file,@length) }
  @t.priority += 1

  if @nzb
    if filemode
      nzb = @nzb
    else
      nzb = Nzb.new(basename,"tmp_")
    end
    nzb.write_file_header(@from,subject,@groups)
  end

  while unprocessed > 0
    p.schedule do
      data = {}
      puts "Current thread count: " + Thread.list.count.to_s if @verbose
      data = @messages.pop
      upload(data,nzb)
      @messages.synchronize do
	@cond.signal
      end
    end
    unprocessed -= 1
  end

  if !@t.nil?
    @t.join
  end
  
  nzbs << nzb
  c += 1
end

p.shutdown 

puts

if @nzb
  nzbs.each do |n|
    n.write_file_footer
    if filemode
      n.write_footer
    else
      nzb_name = File.open(n.nzb_filename,"r")
      nzb = nzb_name.read
      orig_nzb = File.open(@nzb.nzb_filename,"a")
      orig_nzb.puts nzb
      orig_nzb.close
      nzb_name.close
      File.delete(nzb_name)
    end
  end
  @nzb.write_footer if @nzb and dirmode
end
