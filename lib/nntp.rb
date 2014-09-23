# = nntp.rb
#
# NNTP Client Library
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation; either version 2.1 of the License, or (at
# your option) any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY  or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program; if not, write to the Free Software Foundation,
# Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA
#
# See Net::NNTP for detailed documentation.
#
# ==Download
#
# (http://rubyforge.org/projects/nntp)
#
# == Copyright
#
# Copyright  (C) 2004-2007 by Dr Balwinder Singh Dheeman.  Distributed  under
# the GNU GPL (http://www.gnu.org/licenses/gpl.html).  See the files "COPYING"
# and, or "Copyright" , supplied with  all  distributions for additional
# information.
#
# == Authors
#
# Balwinder Singh Dheeman <bsd.SANSPAM@rubyforge.org> (http://cto.homelinux.net/~bsd)
# Albert Vernon <aevernon.SANSPAM@rubyforge.org>
# Bob Schafer <rschafer.SANSPAM@rubyforge.org>
# Mark Triggs <mark.SANSPAM@dishevelled.net>

require 'net/protocol'
require 'digest/md5'
require 'openssl'
module Net  #:nodoc:

  # Module mixed in to all NNTP error classes
  module NNTPError
    # This *class* is module for some reason.
    # In ruby 1.9.x, this module becomes a class.
  end

  # Represents an NNTP authentication error.
  class NNTPAuthenticationError < ProtoAuthError
    include NNTPError
  end

  # Represents NNTP error code 420 or 450, a temporary error.
  class NNTPServerBusy < ProtoServerError
    include NNTPError
  end

  # Represents NNTP error code 440, posting not permitted.
  class NNTPPostingNotAllowed < ProtoServerError
    include NNTPError
  end

  # Represents an NNTP command syntax error (error code 500)
  class NNTPSyntaxError < ProtoSyntaxError
    include NNTPError
  end

  # Represents a fatal NNTP error (error code 5xx, except for 500)
  class NNTPFatalError < ProtoFatalError
    include NNTPError
  end

  # Unexpected reply code returned from server.
  class NNTPUnknownError < ProtoUnknownError
    include NNTPError
  end

  # Error in NNTP response data.
  class NNTPDataError
    include NNTPError
  end

  # = Net::NNTP
  #
  # == What is This Library?
  #
  # This library provides functionality to retrieve and, or post Usenet news
  # articles via NNTP, the Network News Transfer Protocol. The Usenet is a
  # world-wide distributed discussion system. It consists of a set of
  # "newsgroups" with names that are classified hierarchically by topic.
  # "articles" or "messages" are "posted" to these newsgroups by people on
  # computers with the appropriate software -- these articles are then
  # broadcast to other interconnected NNTP servers via a wide variety of
  # networks. For details of NNTP itself, see [RFC977]
  # (http://www.ietf.org/rfc/rfc977.txt).
  #
  # == What is This Library NOT?
  #
  # This library does NOT provide functions to compose Usenet news. You
  # must create and, or format them yourself as per guidelines per
  # Standard for Interchange of Usenet messages, see [RFC850], [RFC2047]
  # and a fews other RFC's (http://www.ietf.org/rfc/rfc850.txt),
  # (http://www.ietf.org/rfc/rfc2047.txt).
  #
  # FYI: the official documentation on Usenet news extentions is: [RFC2980]
  # (http://www.ietf.org/rfc/rfc2980.txt).
  #
  # == Examples
  #
  # === Posting Messages
  #
  # You must open a connection to an NNTP server before posting messages.
  # The first argument is the address of your NNTP server, and the second
  # argument is the port number. Using NNTP.start with a block is the simplest
  # way to do this. This way, the NNTP connection is closed automatically
  # after the block is executed.
  #
  #     require 'rubygems'
  #     require 'nntp'
  #     Net::NNTP.start('your.nntp.server', 119) do |nntp|
  #       # Use the NNTP object nntp only in this block.
  #     end
  #
  # Replace 'your.nntp.server' with your NNTP server. Normally your system
  # manager or internet provider supplies a server for you.
  #
  # Then you can post messages.
  #
  #     require 'date'
  #     date = DateTime.now().strftime(fmt='%a, %d %b %Y %T %z')
  #
  #     msgstr = <<END_OF_MESSAGE
  #     From: Your Name <your@mail.address>
  #     Newsgroups: news.group.one, news.group.two ...
  #     Subject: test message
  #	Date: #{date}
  #
  #     This is a test message.
  #     END_OF_MESSAGE
  #
  #     require 'rubygems'
  #     require 'nntp'
  #     Net::NNTP.start('your.nntp.server', 119) do |nntp|
  #       nntp.post msgstr
  #     end
  #
  # *NOTE*: The NNTP message headers such as +Date:+, +Message-ID:+ and, or
  # +Path:+ if ommited, may also be generated and added by your Usenet news
  # server; better you verify the behavior of your news server.
  #
  # === Closing the Session
  #
  # You MUST close the NNTP session after posting messages, by calling the
  # Net::NNTP#finish method:
  #
  #     # using NNTP#finish
  #     nntp = Net::NNTP.start('your.nntp.server', 119)
  #     nntp.post msgstr
  #     nntp.finish
  #
  # You can also use the block form of NNTP.start/NNTP#start.  This closes
  # the NNTP session automatically:
  #
  #     # using block form of NNTP.start
  #     Net::NNTP.start('your.nntp.server', 119) do |nntp|
  #       nntp.post msgstr
  #     end
  #
  # I strongly recommend this scheme.  This form is simpler and more robust.
  #
  # === NNTP Authentication
  #
  # The Net::NNTP class may support various authentication schemes depending
  # on your news server's reponse to CAPABILITIES command.  To use NNTP
  # authentication, pass extra arguments to  NNTP.start/NNTP#start.
  #
  # See NNTP Extension for Authentication:
  # (http://www.ietf.org/internet-drafts/draft-ietf-nntpext-authinfo-07.txt)
  #
  #     Net::NNTP.start('your.nntp.server', 119,
  #                     'YourAccountName', 'YourPassword', :method)
  #
  # Where +:method+ can be one of the 'gassapi', 'digest_md5',
  # 'cram_md5', 'starttls', 'external', 'plain', 'generic', 'simple' or
  # 'original'; the later and, or unencrypted ones are less secure!
  #
  # In the case of method +:generic+ argumnents should be passed to a format
  # string as follows:
  #
  #     Net::NNTP.start('your.nntp.server', 119,
  #                     "format", *arguments, :generic)
  #
  # *NOTE*: The Authentication mechanism will fallback to a lesser secure
  # scheme, if your Usenet server does not supports method opted by you,
  # except for the +:generic+ option.
  #
  class NNTP

    # The default NNTP port, port 119.
    def NNTP.default_port
      119
    end

    # Creates a new Net::NNTP object.
    #
    # +address+ is the hostname or ip address of your NNTP server. +port+ is
    # the port to connect to; it defaults to port 119.
    #
    # This method does not opens any TCP connection. You can use NNTP.start
    # instead of NNTP.new if you want to do everything at once.  Otherwise,
    # follow NNTP.new with optional changes to +:open_timeout+,
    # +:read_timeout+ and, or +NNTP#set_debug_output+ and then NNTP#start.
    #
    def initialize(address, port = nil)
      @address = address
      @port = (port || NNTP.default_port)
      @socket = nil
      @started = false
      @open_timeout = 30
      @read_timeout = 60
      @error_occured = false
      @debug_output = nil
    end

    # Provide human-readable stringification of class state.
    def inspect  #:nodoc:
      "#<#{self.class} #{@address}:#{@port} started=#{@started}>"
    end

    # The address of the NNTP server to connect to.
    attr_reader :address

    # The port number of the NNTP server to connect to.
    attr_reader :port

    # Seconds to wait while attempting to open a connection. If the
    # connection cannot be opened within this time, a TimeoutError is raised.
    attr_accessor :open_timeout

    # Seconds to wait while reading one block (by one read(2) call). If the
    # read(2) call does not complete within this time, a TimeoutError is
    # raised.
    attr_reader :read_timeout

    # Set the number of seconds to wait until timing-out a read(2) call.
    def read_timeout=(sec)
      @socket.read_timeout = sec if @socket
      @read_timeout = sec
    end

    # Set an output stream for debug logging. You must call this before
    # #start.
    #
    # === Example
    #
    #     nntp = Net::NNTP.new(addr, port)
    #     nntp.set_debug_output $stderr
    #     nntp.start do |nntp|
    #       ....
    #     end
    #
    # *WARNING*: This method causes serious security holes. Use this method
    # for only debugging.
    #
    def set_debug_output(arg)
      @debug_output = arg
    end

    #
    # NNTP session control
    #

    # Creates a new Net::NNTP object and connects to the server.
    #
    # This method is equivalent to:
    #
    #   Net::NNTP.new(address, port).start(account, password, :method)
    #
    # === Example
    #
    #     Net::NNTP.start('your.nntp.server') do |nntp|
    #       nntp.post msgstr
    #     end
    #
    # === Block Usage
    #
    # If called with a block, the newly-opened Net::NNTP object is yielded to
    # the block, and automatically closed when the block finishes.  If called
    # without a block, the newly-opened Net::NNTP object is returned to the
    # caller, and it is the caller's responsibility to close it when
    # finished.
    #
    # === Parameters
    #
    # +address+ is the hostname or ip address of your nntp server.
    #
    # +port+ is the port to connect to; it defaults to port 119.
    #
    # The remaining arguments are used for NNTP authentication, if required
    # or desired.  +user+ is the account name, +secret+ is your password or
    # other authentication token, and +method+ is the authentication
    # type; defaults to 'original'.  Please read the discussion of NNTP
    # Authentication in the overview notes above.
    #
    # === Errors
    #
    # This method may raise:
    #
    # * Net::NNTPAuthenticationError
    # * Net::NNTPFatalError
    # * Net::NNTPServerBusy
    # * Net::NNTPSyntaxError
    # * Net::NNTPUnknownError
    # * IOError
    # * TimeoutError
    #
    def NNTP.start(address, port = nil,
                   user = nil, secret = nil, method = nil,
                   &block) # :yield: nntp
      new(address, port).start(user, secret, method, &block)
    end

    # +true+ if the NNTP session has been started.
    def started?
      @started
    end

    # Opens a TCP connection and starts the NNTP session.
    #
    # === Parameters
    #
    # If both of +user+ and +secret+ are given, NNTP authentication  will be
    # attempted using the AUTH command. The +method+ specifies  the type of
    # authentication to attempt; it must be one of :original, :simple,
    # :generic, :plain, :starttls, :external, :cram_md5, :digest_md5 and, or
    # :gassapi may be used.  See the discussion of NNTP Authentication in the
    # overview notes.
    #
    #
    # === Block Usage
    #
    # When this methods is called with a block, the newly-started NNTP object
    # is yielded to the block, and automatically closed after the block call
    # finishes.  Otherwise, it is the caller's  responsibility to close the
    # session when finished.
    #
    # === Example
    #
    # This is very similar to the class method NNTP.start.
    #
    #     require 'rubygems'
    #     require 'nntp'
    #     nntp = Net::NNTP.new('nntp.news.server', 119)
    #     nntp.start(account, password, method) do |nntp|
    #       nntp.post msgstr
    #     end
    #
    # The primary use of this method (as opposed to NNTP.start) is probably
    # to set debugging (#set_debug_output), which must be done before the
    # session is started.
    #
    # === Errors
    #
    # If session has already been started, an IOError will be raised.
    #
    # This method may raise:
    #
    # * Net::NNTPAuthenticationError
    # * Net::NNTPFatalError
    # * Net::NNTPServerBusy
    # * Net::NNTPSyntaxError
    # * Net::NNTPUnknownError
    # * IOError
    # * TimeoutError
    #
    def start(user = nil, secret = nil, method = nil) # :yield: nntp
      if block_given?
        begin
          do_start(user, secret, method)
          return yield(self)
        ensure
          do_finish
        end
      else
        do_start(user, secret, method)
        return self
      end
    end

    def do_start(user, secret, method)  #:nodoc:
      raise IOError, 'NNTP session already started' if @started
      check_auth_args user, secret, method if user or secret

      if InternetMessageIO.respond_to?(:old_open)
        @socket = InternetMessageIO.old_open(@address, @port, @open_timeout,
                                         @read_timeout, @debug_output)

      else
        socket = timeout(@open_timeout) { TCPSocket.open(@address, @port) }
        @socket = InternetMessageIO.new(socket)
        @socket.read_timeout = @read_timeout
        @socket.debug_output = @debug_output
        # Use OpenSSL to wrap socket
        # Introduced by: Tadeus Dobrovolskij
	if method == :tls
          ssl_context = OpenSSL::SSL::SSLContext.new
          ssl = OpenSSL::SSL::SSLSocket.new socket, ssl_context
	  ssl.sync_close = true
	  ssl.connect
          @socket = InternetMessageIO.new(ssl)
	  @socket.read_timeout = @read_timeout
	  @socket.debug_output = @debug_output
	end
      end

      check_response(critical { recv_response() })

      mode_reader_success = false
      tried_authenticating = false
      until mode_reader_success
        begin
          mode_reader
          mode_reader_success = true
        rescue NNTPAuthenticationError
          if tried_authenticating
            raise
          end
        rescue ProtocolError
          raise
        end
        authenticate user, secret, method if user
        tried_authenticating = true
      end

      @started = true
    ensure
      @socket.close if not @started and @socket and not @socket.closed?
    end
    private :do_start

    # Finishes the NNTP session and closes TCP connection. Raises IOError if
    # not started.
    def finish
      raise IOError, 'not yet started' unless started?
      do_finish
    end

    def do_finish  #:nodoc:
      quit if @socket and not @socket.closed? and not @error_occured
    ensure
      @started = false
      @error_occured = false
      @socket.close if @socket and not @socket.closed?
      @socket = nil
    end
    private :do_finish

    public

    # POST
    #
    # Posts +msgstr+ as a message.  Single CR ("\r") and LF ("\n") found in
    # the +msgstr+, are converted into the CR LF pair.  You cannot post a
    # binary message with this method. +msgstr+ _should include both the
    # message headers and body_. All non US-ASCII, binary and, or multi-part
    # messages should be submitted in an encoded form as per MIME standards.
    #
    # === Example
    #
    #     Net::NNTP.start('nntp.example.com') do |nntp|
    #       nntp.post msgstr
    #     end
    #
    # === Errors
    #
    # This method may raise:
    #
    # * Net::NNTPFatalError
    # * Net::NNTPPostingNotAllowed
    # * Net::NNTPServerBusy
    # * Net::NNTPSyntaxError
    # * Net::NNTPUnknownError
    # * IOError
    # * TimeoutError
    #
    def post(msgstr)
      stat = post0 {
        @socket.write_message msgstr
      }
      return stat[0..3], stat[4..-1].chop
    end

    # Opens a message writer stream and gives it to the block. The stream is
    # valid only in the block, and has these methods:
    #
    # puts(str = '')::       outputs STR and CR LF.
    # print(str)::           outputs STR.
    # printf(fmt, *args)::   outputs sprintf(fmt,*args).
    # write(str)::           outputs STR and returns the length of written bytes.
    # <<(str)::              outputs STR and returns self.
    #
    # If a single CR ("\r") or LF ("\n") is found in the message, it is
    # converted to the CR LF pair.  You cannot post a binary message with
    # this method.
    #
    # === Parameters
    #
    # Block
    #
    # === Example
    #
    #     Net::NNTP.start('nntp.example.com', 119) do |nntp|
    #       nntp.open_message_stream do |f|
    #         f.puts 'From: from@example.com'
    #         f.puts 'Newsgroups: news.group.one, news.group.two ...'
    #         f.puts 'Subject: test message'
    #         f.puts
    #         f.puts 'This is a test message.'
    #       end
    #     end
    #
    # === Errors
    #
    # This method may raise:
    #
    # * Net::NNTPFatalError
    # * Net::NNTPPostingNotAllowed
    # * Net::NNTPServerBusy
    # * Net::NNTPSyntaxError
    # * Net::NNTPUnknownError
    # * IOError
    # * TimeoutError
    #
    def open_message_stream(&block) # :yield: stream
      post0 { @socket.write_message_by_block(&block) }
    end

    # ARTICLE [<Message-ID>|<Number>]
    def article(id_num = nil)
      stat, text = longcmd("ARTICLE #{id_num}".strip)
      return stat[0..2], text
    end

    # BODY [<Message-ID>|<Number>]
    def body(id_num = nil)
      stat, text = longcmd("BODY #{id_num}".strip)
      return stat[0..2], text
    end

    # IO_BODY <output IO object> [<Message-ID>|<Number>]
    def io_body (io_output, id_num = nil)
      stat = io_longcmd(io_output, "BODY #{id_num}".strip)
      return stat[0..2], io_output
    end

    # DATE
    def date
      text = []
      stat = shortcmd("DATE")
      text << stat[4...12]
      text << stat[12...18]
      raise NNTPDataError, stat, caller unless text[0].length == 8 and text[1].length == 6
      return stat[0..2], text
    end

    # GROUP <Newsgroup>
    def group(ng)
      stat = shortcmd("GROUP %s", ng)
      return stat[0..2], stat[4..-1].chop
    end

    # HEAD [<Message-ID>|<Number>]
    def head(id_num = nil)
      stat, text = longcmd("HEAD #{id_num}".strip)
      return stat[0..2], text
    end

    # HELP
    def help
      stat, text = longcmd('HELP')
      text.each_with_index do |line, index|
        text[index] = line.gsub(/\A\s+/, '')
      end
      return stat[0..2], text
    end

    # LAST
    def last
      stat = shortcmd('LAST')
      return stat[0..2], stat[4..-1].chop
    end

    # LIST [ACTIVE|NEWSGROUPS] [<Wildmat>]]:br:
    # LIST [ACTIVE.TIMES|EXTENSIONS|SUBSCRIPTIONS|OVERVIEW.FMT]
    def list(opts = nil)
      stat, text = longcmd("LIST #{opts}".strip)
      return stat[0..2], text
    end

    # LISTGROUP <Newsgroup>
    def listgroup(ng)
      stat, text = longcmd("LISTGROUP #{ng}".strip)
      return stat[0..2], text
    end

    # MODE READER
    def mode_reader
      stat = shortcmd('MODE READER')
      return stat[0..2], stat[4..-1].chop
    end
    private :mode_reader  #:nodoc:

    # NEWGROUPS <yymmdd> <hhmmss> [GMT]
    def newgroups(date, time, tzone = nil)
      stat, text = longcmd("NEWGROUPS #{date} #{time} #{tzone}".strip)
      return stat[0..2], text
    end

    # NEXT
    def next
      stat = shortcmd('NEXT')
      return stat[0..2], stat[4..-1].chop
    end

    # OVER <Range>  # e.g first[-[last]]
    def over(range)
      stat, text = longcmd("OVER #{range}".strip)
      return stat[0..2], text
    end

    # QUIT
    def quit
      stat = shortcmd('QUIT')
    end
    private :quit  #:nodoc:

    # SLAVE
    def slave
      stat = shortcmd('SLAVE')
      return stat[0..2], stat[4..-1].chop
    end

    # STAT [<Message-ID>|<Number>]
    def stat(id_num = nil)
      stat = shortcmd("STAT #{id_num}".strip)
      return stat[0..2], stat[4..-1].chop
    end

    # XHDR <Header> <Message-ID>|<Range>  # e.g first[-[last]]
    def xhdr(header, id_range)
      stat, text = longcmd("XHDR #{header} #{id_range}".strip)
      return stat[0..2], text
    end

    # XOVER <Range>  # e.g first[-[last]]
    def xover(range)
      stat, text = longcmd("XOVER #{range}".strip)
      return stat[0..2], text
    end

    private

    #
    # row level library
    #

    def post0
      raise IOError, 'closed session' unless @socket
      stat = critical {
        check_response(get_response('POST'), true)
        yield
        recv_response()
      }
      check_response(stat)
    end

    #
    # auth
    #

    def check_auth_args(user, secret, method)
      raise ArgumentError, 'both user and secret are required'\
      unless user and secret
        authmeth = "auth_#{method || 'original'}"
        raise ArgumentError, "wrong auth type #{method}"\
        unless respond_to?(authmeth, true)
      end

      def authenticate(user, secret, method)
        methods = %w(original simple generic plain tls starttls external cram_md5 digest_md5 gassapi)
        method = "#{method || 'original'}"
        authmeth = methods.index(method)
        begin
          __send__("auth_#{method}", user, secret)
        rescue NNTPAuthenticationError
          if authmeth and authmeth > 0
            authmeth -= 1  # fallback
            method = methods[authmeth]
            @error_occured = false
            retry
          else
            raise
          end
        end
      end

      # AUTHINFO USER username
      # AUTHINFO PASS password
      def auth_original(user, secret)
        stat = critical {
          check_response(get_response("AUTHINFO USER %s", user), true)
          check_response(get_response("AUTHINFO PASS %s", secret), true)
        }
        raise NNTPAuthenticationError, stat unless /\A2../ === stat
      end

      # AUTHINFO SIMPLE
      # username password
      def auth_simple(user, secret)
        stat = critical {
          check_response(get_response('AUTHINFO SIMPLE'), true)
          check_response(get_response('%s %s', user, secret), true)
        }
        raise NNTPAuthenticationError, stat unless /\A2../ === stat
      end

      # AUTHINFO GENERIC authenticator arguments ...
      #
      # The authentication protocols are not inculeded in RFC2980,
      # see [RFC1731] (http://www.ieft.org/rfc/rfc1731.txt).
      def auth_generic(fmt, *args)
        stat = critical {
          cmd = 'AUTHINFO GENERIC ' + sprintf(fmt, *args)
          check_response(get_response(cmd), true)
        }
        raise NNTPAuthenticationError, stat unless /\A2../ === stat
      end

      # AUTHINFO SASL PLAIN
      def auth_plain(user, secret)
        stat = critical {
          check_response(get_response('AUTHINFO SASL PLAIN %s',
          base64_encode("\0#{user}\0#{secret}")), true)
        }
        raise NNTPAuthenticationError, stat unless /\A2../ === stat
      end

      # ORIGINAL OVER ENCRYPTED CONNECTION
      # Introduced by: Tadeus Dobrovolskij
      # AUTHINFO USER username
      # AUTHINFO PASS password
      def auth_tls(user, secret)
        stat = critical {
          check_response(get_response("AUTHINFO USER %s", user), true)
          check_response(get_response("AUTHINFO PASS %s", secret), true)
        }
        raise NNTPAuthenticationError, stat unless /\A2../ === stat
      end

      # STARTTLS
      def auth_starttls(user, secret)
        stat = critical {
          check_response(get_response('STARTTLS'), true)
          ### FIXME:
        }
        raise NNTPAuthenticationError, 'not implemented as yet!'
      end

      # AUTHINFO SASL EXTERNAL =
      def auth_external(user, secret)
        stat = critical {
          check_response(get_response('AUTHINFO SASL EXTERNAL ='), true)
          ### FIXME:
        }
        raise NNTPAuthenticationError, 'not implemented as yet!'
      end

      # AUTHINFO SASL CRAM-MD5 [RFC2195]
      def auth_cram_md5(user, secret)
        stat = nil
        critical {
          stat = check_response(get_response('AUTHINFO SASL CRAM-MD5'), true)
          challenge = stat.split(/ /)[1].unpack('m')[0]
          secret = Digest::MD5.digest(secret) if secret.size > 64

          isecret = secret + "\0" * (64 - secret.size)
          osecret = isecret.dup
          0.upto(63) do |i|
            isecret[i] ^= 0x36
            osecret[i] ^= 0x5c
          end
          tmp = Digest::MD5.digest(isecret + challenge)
          tmp = Digest::MD5.hexdigest(osecret + tmp)

          stat = get_response(base64_encode(user + ' ' + tmp))
        }
        raise NNTPAuthenticationError, stat unless /\A2../ === stat
      end

      # AUTHINFO SASL DIGEST-MD5
      def auth_digest_md5(user, secret)
        stat = critical {
          check_response(get_response('AUTHINFO SASL DIGEST-MD5'), true)
          ### FIXME:
        }
        raise NNTPAuthenticationError, 'not implemented as yet!'
      end

      # AUTHINFO SASL GASSAPI
      def auth_gassapi(user, secret)
        stat = critical {
          check_response(get_response('AUTHINFO SASL GASSAPI'), true)
          ### FIXME:
        }
        raise NNTPAuthenticationError, 'not implemented as yet!'
      end

      def base64_encode(str)
        # expects "str" may not become too long
        [str].pack('m').gsub(/\s+/, '')
      end

      def longcmd(fmt, *args)
        text = []
        stat = io_longcmd(text, fmt, *args)
        return stat, text.map { |line| line.chomp! }
      end

      def io_longcmd(target, fmt, *args)
        if stat = shortcmd(fmt, *args)
          while true
            line = @socket.readline
            break if line =~ /^\.\s*$/   # done
            line = line[1..-1] if line.to_s[0...2] == '..'
            target << line + $/
          end
        end

        return stat, target
      end

      def shortcmd(fmt, *args)
        stat = critical {
          @socket.writeline sprintf(fmt, *args)
          recv_response()
        }
        check_response(stat)
      end

      def get_response(fmt, *args)
        @socket.writeline sprintf(fmt, *args)
        recv_response()
      end

      def recv_response
        stat = ''
        while true
          line = @socket.readline
          stat << line << "\n"
          break unless line[3] == ?-   # "210-PIPELINING"
        end
        stat
      end

      def check_response(stat, allow_continue = false)
        return stat if /\A1/ === stat			  # 1xx info msg
        return stat if /\A2/ === stat			  # 2xx cmd k
        return stat if allow_continue and /\A[35]/ === stat # 3xx cmd k, snd rst
        exception = case stat
      when /\A440/ then NNTPPostingNotAllowed		  # 4xx cmd k, bt nt prfmd
      when /\A48/  then NNTPAuthenticationError
      when /\A4/   then NNTPServerBusy
      when /\A50/  then NNTPSyntaxError		  # 5xx cmd ncrrct
      when /\A55/  then NNTPFatalError
      else
        NNTPUnknownError
      end
      raise exception, stat
    end

    def critical(&block)
      return '200 dummy reply code' if @error_occured
      begin
        return yield()
      rescue Exception
        @error_occured = true
        raise
      end
    end

  end # class_NNTP

  NNTPSession = NNTP
end # module_Net
