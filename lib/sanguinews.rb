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

require 'rubygems'
require 'bundler/setup'
require 'optparse'
require 'monitor'
require 'date'
require 'tempfile'
# Following non-standard gems are needed
require 'parseconfig'
require 'speedometer'
# Our library
require_relative 'sanguinews/thread-pool'
require_relative 'sanguinews/nntp'
require_relative 'sanguinews/nntp_msg'
require_relative 'sanguinews/file_to_upload'
require_relative 'sanguinews/yencoded'
require_relative 'sanguinews/config'
require_relative 'sanguinews/version'

module Sanguinews
  module_function
  # Method returns yenc encoded string and crc32 value
  def yencode(file, length, queue)
     chunk = 1
     until file.eof?
        bindata = file.read(length)
        # We can't take all memory, so we wait
        queue.synchronize do
          @cond.wait_while do
            queue.length > @config.connections * 3
          end
        end
        data = {}
        final_data = []
        len = bindata.length
        yencoded = Yencoded::Data.yenc(bindata, len)
        data[:crc32] = yencoded[1].to_s(16)
        data[:yenc] = yencoded[0]
        data[:length] = len
        data[:chunk] = chunk
        data[:file] = file
        final_data[0] = form_message(data)
        final_data[1] = file
        queue.push(final_data)
        chunk += 1
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
    subject="#{@config.prefix}#{file.dir_prefix}\"#{basename}\" yEnc (#{chunk}/#{chunks})"
    msg = NntpMsg.new(@config.from, @config.groups, subject)
    msg.poster = "sanguinews v#{Sanguinews::VERSION} (ruby #{RUBY_VERSION}) - https://github.com/tdobrovolskij/sanguinews"
    msg.xna = @config.xna
    msg.message = message.force_encoding('ASCII-8BIT')
    msg.yenc_body(chunk, chunks, crc32, pcrc32, length, fsize, basename)
    msg = msg.return_self
    { message: msg, filename: basename, chunk: chunk, length: length }
  end

  def connect(conn_nr)
    begin
      nntp = Net::NNTP.start(
	@config.server, @config.port, @config.username, @config.password, @config.mode)
    rescue
      @s.log([$!, $@], stderr: true) if @config.debug
      if @config.verbose
        parse_error($!.to_s)
        @s.log("Connection nr. #{conn_nr} has failed. Reconnecting...\n", stderr: true)
      end
      sleep @config.reconnect_delay
      retry
    end
    return nntp
  end

  def get_msgid(responses)
    msgid = ''
    responses.each do |response|
      msgid = response.sub(/>.*/, '').tr("<", '') if response.end_with?('Article posted')
    end
    return msgid
  end

  def parse_error(msg, **info)
    if info[:file] && info[:chunk]
      fileinfo = '(' + info[:file] + ' / Chunk: ' + info[:chunk].to_s + ')'
    else
      fileinfo = ''
    end

    case
    when /\A411/ === msg
      @s.log("Invalid newsgroup specified.\n", stderr: true)
    when /\A430/ === msg
      @s.log("No such article. Maybe server is lagging...#{fileinfo}\n", stderr: true)
    when /\A(4\d{2}\s)?437/ === msg
      @s.log("Article rejected by server. Maybe it's too big.#{fileinfo}\n", stderr: true)
    when /\A440/ === msg
      @s.log("Posting not allowed.\n", stderr: true)
    when /\A441/ === msg
      @s.log("Posting failed for some reason.#{fileinfo}\n", stderr: true)
    when /\A450/ === msg
      @s.log("Not authorized.\n", stderr: true)
    when /\A452/ === msg
      @s.log("Wrong username and/or password.\n", stderr: true)
    when /\A500/ === msg
      @s.log("Command not recognized.\n", stderr: true)
    when /\A501/ === msg
      @s.log("Command syntax error.\n", stderr: true)
    when /\A502/ === msg
      @s.log("Access denied.\n", stderr: true)
    end
  end

  def create_upload_list(info_lock)
    files = @config.files

    # skip hidden files
    if !@config.filemode && Dir.exists?(@config.directory)
      Dir.foreach(@config.directory) do |item|
        next if item.start_with?('.')
        files << @config.directory+item
      end
    end

    files_to_process = []
    informed = {}
    unprocessed = 0
    current_file = 1
    # "max" is needed only in dirmode
    max = files.length

    files.each do |file|
      next if !File.file?(file)

      informed[file.to_sym] = false
      file = FileToUpload.new(
        name: file, chunk_length: @config.article_size, prefix: @config.prefix,
	current: current_file, last: max, filemode: @config.filemode,
	from: @config.from, groups: @config.groups, nzb: @config.nzb
      )
      @s.to_upload += file.size

      info_lock.synchronize do
        unprocessed += file.chunks
      end

      files_to_process << file
      current_file += 1
    end

    if files_to_process.empty?
      puts "Upload list is empty! Make sure that you spelled file/directory name(s) correctly!"
      exit 1
    end
    return files_to_process, informed, unprocessed
  end


  def process_and_upload(queue, nntp_pool, info_lock, informed)
    stuff = queue.pop
    queue.synchronize do
      @cond.signal
    end
    nntp = nntp_pool.pop

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
        @s.log(file.subject + "\n")
        @s.log("Chunks: #{file.chunks}\n", stderr: true) if @verbose
        informed[basename.to_sym] = true
      end
    end

    @s.start
    check_delay = 1
    begin
      response = nntp.post msg
      msgid = get_msgid(response)
      if @config.header_check
        sleep check_delay
        nntp.stat("<#{msgid}>")
      end
    rescue
      @s.log([$!, $@], stderr: true) if @config.debug
      if @config.verbose
        parse_error($!.to_s, file: basename, chunk: chunk)
        @s.log("Upload of chunk #{chunk} from file #{basename} unsuccessful. Retrying...\n", stderr: true)
      end
      sleep @config.reconnect_delay
      check_delay += 4
      retry
    end

    if @config.verbose
      @s.log("Uploaded chunk Nr:#{chunk}\n", stderr: true)
    end

    @s.done(length)
    @s.uploaded += full_size
    if @config.nzb
      file.write_segment_info(length, chunk, msgid)
    end
    nntp_pool.push(nntp)
  end

  def run!
    @config = Config.new(ARGV)
    info_lock=Mutex.new
    messages = Queue.new
    messages.extend(MonitorMixin)
    @cond = messages.new_cond
    @s = Speedometer.new(units: "KB", progressbar: true)
    @s.uploaded = 0

    pool = Queue.new
    Thread.new {
      @config.connections.times do |conn_nr|
        nntp = connect(conn_nr)
        pool.push(nntp)
      end
    }

    thread_pool = Pool.new(@config.connections)

    files_to_process, informed, unprocessed = create_upload_list(info_lock)

    # let's give a little bit higher priority for file processing thread
    @file_proc_thread = Thread.new {
      files_to_process.each do |file|
        @s.log("Calculating CRC32 value for #{file.name}\n", stderr: true) if @verbose
        file.file_crc32
        @s.log("Encoding #{file.name}\n")
        yencode(file, @config.article_size, messages)
      end
    }
    @file_proc_thread.priority += 2

    until unprocessed == 0
      thread_pool.schedule do
        process_and_upload(messages, pool, info_lock, informed)
      end
      unprocessed -= 1
    end

    thread_pool.shutdown

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
  end
end
