########################################################################
# NntpMsg - class creates NNTP message specifically for sanguinews
# Copyright (c) 2013, Tadeus Dobrovolskij
# This library is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this library; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
########################################################################
#
require 'date'

module Sanguinews
  class NntpMsg
    attr_accessor :message, :from, :groups, :subject, :poster, :date, :xna, :crc32, :part_crc32, :length
  
    def initialize(from, groups, subject, message='', **opts)
      @from = from
      @groups = groups
      @subject = subject
      @message = message
      @date = opts[:date] if opts[:date]
      @date ||= DateTime.now().strftime('%a, %d %b %Y %T %z')
      @poster = "sanguinews v#{Sanguinews::VERSION} (ruby #{RUBY_VERSION}) - https://github.com/tdobrovolskij/sanguinews"
    end
  
    def create_header
      sio = StringIO.new("", "w:ASCII-8BIT")
      sio.puts "From: #{@from}"
      sio.puts "Newsgroups: #{@groups}"
      sio.puts "Subject: #{@subject}"
      sio.puts "X-Newsposter: #{@poster}" if @poster
      sio.puts "X-No-Archive: yes" if @xna
      sio.puts "Date: #{@date}"
      sio.puts
      header = sio.string
      sio.close
      return header
    end
  
    def yenc_body(current_part, parts, file_size, filename)
      chunk_start = ((current_part - 1) * @length) + 1
      chunk_end = current_part * @length
      if (parts==1)
        headerline = "=ybegin line=128 size=#{file_size} name=#{filename}"
        trailer = "=yend size=#{file_size} crc32=#{@crc32}"
      else
        headerline = "=ybegin part=#{current_part} total=#{parts} line=128 size=#{file_size} name=#{filename}\n=ypart begin=#{chunk_start} end=#{chunk_end}"
        # last part
        if (current_part == parts)
          trailer = "=yend size=#{@length} part=#{current_part} pcrc32=#{@part_crc32} crc32=#{@crc32}"
        else
          trailer = "=yend size=#{@length} part=#{current_part} pcrc32=#{@part_crc32}"
        end
      end
      headerline << "\n#{@message}\n"
      headerline << trailer
      @message = headerline
    end
  
    def return_self
      header = self.create_header
      header << @message
    end
  
    def size
      return @message.length
    end

    def unset
      @from = nil
      @groups = nil
      @subject = nil
      @poster = nil
      @date = nil
      @message = nil
    end
  end
end
