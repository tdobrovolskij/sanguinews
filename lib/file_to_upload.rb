########################################################################
# FileToUpload - File class' extension specifically for sanguinews
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
require 'zlib'
require 'nzb'

class FileToUpload < File
  attr_accessor :name, :chunks, :subject
  attr_reader :crc32, :nzb, :dir_prefix, :cname, :working_nzb
  
  def initialize(var)
    @dir_prefix = ''

    var[:mode] = "rb" if var[:mode].nil?

    super(var[:name], var[:mode])
    @filemode = var[:filemode]
    @name = File.basename(var[:name])
    chunks?(var[:chunk_length])
    file_crc32
    common_name(var)
    nzb_init(var[:from], var[:groups]) if var[:nzb]
    return @name
  end

  def close
    if @nzb
      @working_nzb.write_file_footer
        if @filemode
          @working_nzb.write_footer
        else
          nzb_name = File.open(@working_nzb.nzb_filename,"r")
          nzb = nzb_name.read
          orig_nzb = File.open(@nzb.nzb_filename,"a")
          orig_nzb.puts nzb
          orig_nzb.close
          nzb_name.close
          File.delete(nzb_name)
        end
      @nzb.write_footer if !@filemode
    end
    super
  end

  private

  def chunks?(chunk_length)
    chunks = self.size.to_f / chunk_length
    @chunks = chunks.ceil
  end

  def common_name(var)
    if var[:filemode]
      @cname = File.basename(var[:name])
    else
      @cname = File.basename(File.dirname(var[:name]))
      @dir_prefix = @cname + " [#{var[:current]}/#{var[:last]}] - "
    end
      @subject = "#{var[:prefix]}#{@dir_prefix}#{@name} yEnc (1/#{@chunks})"
  end

  def nzb_init(from, groups)
    @nzb = Nzb.new(@cname,"sanguinews_")
    @nzb.write_header

    if @filemode
      @working_nzb = @nzb
    else
      @working_nzb = Nzb.new(@cname, "tmp_")
    end

    @working_nzb.write_file_header(from, @subject, groups)
  end

  # Method from y_enc gem
  # Big thanks to Sam "madgeekfiend" Contapay(https://github.com/madgeekfiend)
  def file_crc32
    f = self.read
    @crc32 = Zlib.crc32(f,0).to_s(16)
    self.rewind
  end

end
