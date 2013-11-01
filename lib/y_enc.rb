require 'zlib'

# yEnc
#
# This gem allows you to decode and encode files using the yenc standard.

class YEnc

  attr_reader :filepath, :outputpath, :filename, :filesize, :line

  def initialize filepath, outputpath
    @filepath = filepath
    @outputpath = outputpath
  end

  def crc32
    @crc32.upcase.strip
  end

  # Encode file into a yenc text file
  def encode_to_file outputfilename
    outputfile = File.new(@outputpath + outputfilename, "w")
    outputfile.puts "=ybegin size=#{File.size?(@filepath)} line=128 name=#{File.basename @filepath}\n"
    File.open(@filepath,'rb') do |f|
      until f.eof?
        #Read in 128 bytes at a time
        buffer = f.read(128)
        buffer.each_byte do |byte|
          char_to_write = (byte + 42) % 256
          if [0, 10, 13, 61].include?(char_to_write)
            outputfile.putc '='
            char_to_write = (char_to_write + 64) % 256
          end
          outputfile.putc char_to_write
        end
        outputfile.puts "\n"
      end
    end
    outputfile.puts "=yend size=312860 crc32=#{file_crc32(@filepath).upcase}\n"
    outputfile.close
  end

  # method only encodes given file and returns yenc encoded string; nothing more, nothing less
  # Author: Tadeus Dobrovolskij
  def encode
    sio = StringIO.new("","w:ASCII-8BIT")
    File.open(@filepath,'rb') do |b|
      until b.eof?
        buffer = b.read(128)
        buffer.each_byte do |byte|
          char_to_write = (byte + 42) % 256
          if [0, 10, 13, 61].include?(char_to_write)
            sio.putc '='
            char_to_write = (char_to_write + 64) % 256
          end
          sio.putc char_to_write
        end
        sio.puts "\n"
      end
    end
    result = sio.string
    sio.close
    return result
  end

  def decode
    if is_yenc?
            #Continue decoding
      begin_read = false

      File.open(@filepath, 'r').each_line do |line|

          if line.include?("=ybegin") #This is the begin size
            breakdown_header line
            begin_read = true
            next
          end
          if line.include?("=yend")
            breakdown_endline line
            begin_read=false
            break #stop looking through the file we are done
          end
          #end of reading lines

          if begin_read
            #puts "LINE COUNT: #{line.length}"
            #Decode and write to binary file
            esc = false
            line.each_byte do |c|
              next if c == 13 or c == 10

              if c == 61 and not esc #escape character hit goto the next one
                esc = true
                next
              else
                if esc
                  esc = false
                  c = c - 64
                end

                if c.between?(0,41)
                  decoded = c + 214
                else
                  decoded = c - 42
                end
              end
              @new_file.putc decoded
            end
          end

      end
      @new_file.close
    else
      false
    end
  end

  #Does this pass the crc32 check
  def pass_crc32?
    crc32 = file_crc32 @outputpath + @filename
    crc32.eql?(@crc32.downcase.strip)
  end

  # Get the CRC32 for a file
  def file_crc32 filepath
    f = nil
    File.open( filepath, "rb") { |h| f = h.read }
    Zlib.crc32(f,0).to_s(16)
  end

  private

  def is_yenc?
    File.read(@filepath).include?("=ybegin")
  end

  def breakdown_endline line
    @crc32 = line[/crc32=(.*)/,1] if @crc32.nil?
  end

  def breakdown_header line
    @filename=line[/name=(.*)/,1] if @filename.nil?
    @filesize =line[/size=([^\s]+)/,1] if @filesize.nil?
    @line=line[/line=([^\s]+)/,1] if @line.nil?
    @new_file = File.new(@outputpath + @filename, "wb")
  end

end
