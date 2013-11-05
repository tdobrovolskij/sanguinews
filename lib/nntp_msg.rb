#
require 'date'

class NntpMsg
  attr_accessor :message, :from, :groups, :subject, :poster, :date

  def initialize(from,groups,subject,message='',date=nil,poster=nil)
    @from = from
    @groups = groups
    @subject = subject
    @message = message
    if date.nil?
      @date = DateTime.now().strftime(fmt='%a, %d %b %Y %T %z')
    else
      @date = date
    end
    @poster = poster if !poster.nil?
  end

  def create_header
    sio = StringIO.new("","w:ASCII-8BIT")
    sio.puts "From: #{@from}"
    sio.puts "Newsgroups: #{@groups}"
    sio.puts "Subject: #{@subject}"
    sio.puts "X-Newsposter: #{@poster}" if !poster.nil?
    sio.puts "Date: #{@date}"
    sio.puts
    header = sio.string
    sio.close
    return header
  end

  def yenc_body(current_part,parts,crc32,pcrc32,part_size,file_size,filename)
    chunk_start = ((current_part - 1) * part_size) + 1
    chunk_end = current_part * part_size
    if (parts==1)
      headerline = "=ybegin line=128 size=#{file_size} name=#{filename}"
      trailer = "=yend size=#{file_size} crc32=#{crc32}"
    else
      headerline = "=ybegin part=#{current_part} total=#{parts} line=128 size=#{file_size} name=#{filename}\n=ypart begin=#{chunk_start} end=#{chunk_end}"
      # last part
      if (current_part == parts)
        trailer = "=yend size=#{part_size} part=#{current_part} pcrc32=#{pcrc32} crc32=#{crc32}"
      else
        trailer = "=yend size=#{part_size} part=#{current_part} pcrc32=#{pcrc32}"
      end
    end
    @message = headerline + "\n#{@message}\n" + trailer
  end

  def return_self
    header = self.create_header
    return header + @message
  end

  def size
    return @message.length
  end
end
