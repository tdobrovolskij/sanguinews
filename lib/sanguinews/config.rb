#######################################################################
# Config - class designed specifically for sanguinews
# Copyright (c) 2013-2014, Tadeus Dobrovolskij
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
#########################################################################
module Sanguinews
  class Config
    attr_reader :config, :data

    %w(username password server port from connections
       article_size reconnect_delay groups prefix ssl
       xna nzb header_check verbose debug filemode files directory).each do |meth|
      define_method(meth) { @data[meth.to_sym] }
    end

    def parse_config(config)
      config = ParseConfig.new(config)
      config.get_params().each do |key|
	value = config[key]
	value = true if value == 'yes'
	value = false if value == 'no'
	value = value.to_i if %w(connections article_size reconnect_delay).include? key
	@data[key.to_sym] ||= value
      end
    end

    def mode
      self.ssl ? :tls : :original
    end

    def parse_options!(args)
      # version and legal info presented to user
      banner = []
      banner << ""
      banner << "sanguinews v#{Sanguinews::VERSION}. Copyright (c) 2013-2014 Tadeus Dobrovolskij."
      banner << "Comes with ABSOLUTELY NO WARRANTY. Distributed under GPL v2 license(http://www.gnu.org/licenses/gpl-2.0.txt)."
      banner << "sanguinews is a simple nntp(usenet) binary poster. It supports multithreading and SSL. More info in README."
      banner << ""
      # option parser
  
      opt_parser = OptionParser.new do |opt|
        opt.banner = "Usage: sanguinews [OPTIONS] [DIRECTORY] | -f FILE1..[FILEX]"
        opt.separator  ""
        opt.separator  "Options"
  
        opt.on("-c", "--config CONFIG", "use different config file") do |cfg|
          @config = cfg
        end
        opt.on("-C", "--check", "check headers while uploading; slow but reliable") do
          @data[:header_check] = true
        end
        opt.on("-f", "--file FILE", "upload FILE, treat all additional parameters as files") do |file|
          @data[:filemode] = true
          @data[:files] << file
        end
        opt.on("-g", "--groups GROUP_LIST", "use these groups(comma separated) for upload") do |group_list|
          @data[:groups] = group_list
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
          @data[:password] = password
        end
        opt.on("-u", "--user USERNAME", "use USERNAME as your username(overwrites config file)") do |username|
          @data[:username] = username
        end
        opt.on("-v", "--verbose", "be verbose?") do
          @data[:verbose] = true
        end
        opt.on("-V", "--version", "print version information and then exit") do
          puts Sanguinews::VERSION
          exit
        end
      end
  
      begin
        opt_parser.parse!(args)
      rescue OptionParser::InvalidOption, OptionParser::MissingArgument
        puts opt_parser
        exit 1
      end
  
      @data[:directory] = args[0] unless @data[:filemode]
      @data[:directory] += '/' if @data[:directory] && !@data[:directory].end_with?('/')
  
      # in file mode treat every additional parameter as a file
      if !args.empty? && @data[:filemode]
        args.each do |file|
          @data[:files] << file.to_s
        end
      end
  
      # exit when no file list is provided
      if !@data[:directory] && @data[:files].empty?
        puts "You need to specify something to upload!"
        puts opt_parser
        exit 1
      end
  
    end

    def initialize(args)
      @data = {}
      @data[:filemode] = false
      @data[:files] = []

      parse_options!(args)

      # Parse options in config file
      if @data[:config] && File.exist?(File.expand_path(@data[:config]))
	config = @data[:config]
      else
	config = File.expand_path("~/.sanguinews.conf")
      end

      if File.exist?(config)
	parse_config(config)
      else
	puts "No config specified!"
	exit 1
      end
    end
  
  end
end
