#######################################################################
# Config -  specifically for sanguinews
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
#########################################################################
module Sanguinews
  class Config
    attr_reader :config, :data

    %w(username password from connections
       article_size reconnect_delay groups prefix 
       ssl xna nzb header_check debug filemode).each do |meth|
      define_method(meth) { @data[meth.to_sym] }
    end

    def parse_config(config)
      config = ParseConfig.new(config)
      config.get_params().each do |key, value|
	value = true if value == 'yes'
	value = false if value == 'no'
	value = value.to_i if %(connections article_size reconnect_delay).include? value
	@data[key.to_s] = value
      end
    end

    def mode
      self.ssl ? :tls : :original
    end

    def parse_options(args)
      # version and legal info presented to user
      banner = []
      banner << ""
      banner << "sanguinews v#{Sanguinews::VERSION}. Copyright (c) 2013-2014 Tadeus Dobrovolskij."
      banner << "Comes with ABSOLUTELY NO WARRANTY. Distributed under GPL v2 license(http://www.gnu.org/licenses/gpl-2.0.txt)."
      banner << "sanguinews is a simple nntp(usenet) binary poster. It supports multithreading and SSL. More info in README."
      banner << ""
      # option parser
      options = {}
      options[:filemode] = false
      options[:files] = []
  
      opt_parser = OptionParser.new do |opt|
        opt.banner = "Usage: #{$0} [OPTIONS] [DIRECTORY] | -f FILE1..[FILEX]"
        opt.separator  ""
        opt.separator  "Options"
  
        opt.on("-c", "--config CONFIG", "use different config file") do |cfg|
          options[:config] = cfg
        end
        opt.on("-C", "--check", "check headers while uploading; slow but reliable") do
          options[:header_check] = true
        end
        opt.on("-f", "--file FILE", "upload FILE, treat all additional parameters as files") do |file|
          options[:filemode] = true
          options[:files] << file
        end
        opt.on("-g", "--groups GROUP_LIST", "use these groups(comma separated) for upload") do |group_list|
          options[:groups] = group_list
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
  
      options[:directory] = args[0] unless options[:filemode]
  
      # in file mode treat every additional parameter as a file
      if !args.empty? && options[:filemode]
        args.each do |file|
          options[:files] << file.to_s
        end
      end
  
      # exit when no file list is provided
      if !options[:directory] && options[:files].empty?
        puts "You need to specify something to upload!"
        puts opt_parser
        exit 1
      end
  
      return options
    end

    def initialize
      # Parse options in config file
      config = "~/.sanguinews.conf"
      config = File.expand_path(config)
      # variable to store if config was parsed
      saw_config = false
      if File.exist?(config)
        saw_config = true
        parse_config(config)
      end

      options = parse_options(ARGV)

      optconfig = options[:config]
      optconfig ||= ''
      if !File.exist?(optconfig) && !saw_config
        puts "No config information specified. Aborting..."
        exit
      end
      parse_config(optconfig) if File.exist?(optconfig)

      options[:verbose] ? @verbose = true : @verbose = false
      @header_check = true if options[:header_check]
      filemode = options[:filemode]

      @username = options[:username] if options[:username]
      @password = options[:password] if options[:password]
      @groups = options[:groups] if options[:groups]
      directory = options[:directory] unless filemode
      files = options[:files]
    end
  
  end
end
