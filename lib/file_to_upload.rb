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

class FileToUpload < File
  attr_accessor :name, :chunks, :crc32, :subject
  
  def initialize(var)
    var[:mode] = "rb" if var[:mode].nil?

    super(var[:name], var[:mode])
    self.chunks?(var[:chunk_length])
    self.subj(var[:prefix], var[:dir_prefix])
    self.file_crc32
    @name = File.basename(var[:name])
  end

  def subj(prefix, dir_prefix)
    @subject = "#{prefix}#{dir_prefix}#{@name} yEnc (1/#{@chunks})"
  end

  private

  def chunks?(chunk_length)
    chunks = self.size.to_f / chunk_length
    @chunks = chunks.ceil
  end

  # Method from y_enc gem
  # Big thanks to Sam "madgeekfiend" Contapay(https://github.com/madgeekfiend)
  def file_crc32
    f = self.read
    @crc32 = Zlib.crc32(f,0).to_s(16)
    self.rewind
  end

end
