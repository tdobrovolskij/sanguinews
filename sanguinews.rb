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

@version = '0.50'

require 'rubygems'
require 'bundler/setup'
require 'optparse'
require 'monitor'
require 'date'
require 'tempfile'
# Following non-standard gems are needed
require 'parseconfig'
require 'speedometer'
require_relative 'lib/thread-pool'
require_relative 'lib/nntp'
require_relative 'lib/nntp_msg'
require_relative 'lib/file_to_upload'
require_relative 'lib/yencoded'

# Method returns yenc encoded string and crc32 value
def yencode(file, length, queue)
   i = 1
   until file.eof?
      bindata = file.read(length)
      # We can't take all memory, so we wait
      queue.synchronize do
	@cond.wait_while do
	  queue.length > @threads * 3
	end
      end
      data = {}
      final_data = []
      len = bindata.length
      data[:yenc] = Yencoded.new.yenc(bindata, len)
      data[:crc32] = Zlib.crc32(bindata, 0).to_s(16)
      data[:length] = len
      data[:chunk] = i
      data[:file] = file
      final_data[0] = form_message(data)
      final_data[1] = file
      queue.push(final_data)
      i += 1
   end
end

def form_message(data)
  message = data[:yenc]
  length = data[:length]
  pcrc32 = data[:crc32]
  file = data[:file]
  chunk = data[:chunk]
  crc32 = file.crc32
  fsize = file.size
  chunks = file.chunks
  basename = file.name
  # usenet works with ASCII
  subject="#{@prefix}#{file.dir_prefix}\"#{basename}\" yEnc (#{chunk}/#{chunks})"
  msg = NntpMsg.new(@from, @groups, subject)
  msg.poster = "sanguinews v#{@version} (ruby #{RUBY_VERSION}) - https://github.com/tdobrovolskij/sanguinews"
  msg.xna = @xna
  msg.message = message.force_encoding('ASCII-8BIT')
  msg.yenc_body(chunk, chunks, crc32, pcrc32, length, fsize, basename)
  msg = msg.return_self
  { message: msg, filename: basename, chunk: chunk, length: length }
end

def connect(x)
  begin
    nntp = Net::NNTP.start(@server, @port, @username, @password, @mode)
  rescue
    #puts $!, $@ if @verbose
    @s.log("Connection nr. #{x} has failed. Reconnecting...") if @verbose
    sleep @delay
    retry
  end
  return nntp
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
filemode = false

opt_parser = OptionParser.new do |opt|
  opt.banner = "Usage: #{$0} [OPTIONS] [DIRECTORY] | -f FILE1..[FILEX]"
  opt.separator  ""
  opt.separator  "Options"

  opt.on("-c", "--config CONFIG", "use different config file") do |cfg|
    options[:config] = cfg
  end
  opt.on("-f", "--file FILE", "upload FILE, treat all additional parameters as files") do |file|
    options[:file] = file
    filemode = true
  end
  opt.on("-h", "--help", "help") do
    banner.each do |msg|
      puts msg
    end
    puts opt_parser
    puts
    exit
  end
  opt.on("-p", "--password PASSWORD", "use PASSWORD as your password(overwrites config file)") do |password|
    options[:password] = password
  end
  opt.on("-u", "--user USERNAME", "use USERNAME as your username(overwrites config file)") do |username|
    options[:username] = username
  end
  opt.on("-v", "--verbose", "be verbose?") do
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

@username = username unless username.nil?
@password = password unless password.nil?
directory = ARGV[0] unless filemode
# in file mode treat every additional parameter as a file
if !ARGV.empty? && filemode
  ARGV.each do |file|
    files << file.to_s
  end
end

# skip hidden files
if !filemode
  directory = directory + "/" unless directory.end_with?('/')
  Dir.foreach(directory) do |item|
    next if item.start_with?('.')
    files << directory+item
  end
end

# "max" is needed only in dirmode
max = files.length
c = 1

unprocessed = 0
info_lock=Mutex.new
messages = Queue.new
messages.extend(MonitorMixin)
@cond = messages.new_cond
files_to_process = []
@s = Speedometer.new("KB")
@s.uploaded = 0

pool = Queue.new
Thread.new {
  @threads.times do |x|
    nntp = connect(x)
    pool.push(nntp)
  end
}

p = Pool.new(@threads)
informed = {}

files.each do |file|
  next if !File.file?(file)

  informed[file.to_sym] = false
  file = FileToUpload.new(
    name: file, chunk_length: @length,
    prefix: @prefix, current: c, last: max, filemode: filemode,
    from: @from, groups: @groups, nzb: @nzb
  )

  info_lock.synchronize do
    unprocessed += file.chunks
  end

  files_to_process << file
  c += 1
end

# let's give a little bit higher priority for file processing thread
@t = Thread.new {
  files_to_process.each do |file|
    file.file_crc32
    @s.log("Encoding #{file.name}\n")
    yencode(file, @length, messages)
  end
}
@t.priority += 2

until unprocessed == 0
  p.schedule do
    stuff = messages.pop
    messages.synchronize do
      @cond.signal
    end
    nntp = pool.pop

    data = stuff[0]
    file = stuff[1]
    msg = data[:message] 
    chunk = data[:chunk]
    basename = data[:filename]
    length = data[:length]
    full_size = msg.length
    info_lock.synchronize do
      if !informed[basename.to_sym]
        @s.log("Uploading #{basename}\n")
        @s.log(file.subject)
        @s.log("Chunks: #{file.chunks}") if @verbose
        informed[basename.to_sym] = true
      end
    end
    response = ''

    @s.start
    begin
      response = nntp.post msg
    rescue
      #puts $!, $@ if @verbose
      @s.log("Upload of chunk #{chunk} from file #{basename} unsuccesful. Retrying...") if @verbose
      sleep @delay
      retry
    end

    if @verbose
      @s.log("Uploaded chunk Nr:#{chunk}")
    end

    @s.uploaded = @s.uploaded + full_size
    if @nzb
      msgid = ''
      response.each do |r|
        msgid = r.sub(/>.*/, '').tr("<", '') if r.end_with?('Article posted')
      end
      file.write_segment_info(length, chunk, msgid)
    end
    pool.push(nntp)
  end
  unprocessed -= 1
end

p.shutdown

until pool.empty?
  nntp = pool.pop
  nntp.finish
end

@s.stop
puts

files_to_process.each do |file|
  if files_to_process.last == file
    last = true
  else
    last = false
  end
  file.close(last)
end
