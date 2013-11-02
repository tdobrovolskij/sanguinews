sanguinews
==========

Sanguinews is a simple, commandline client for Usenet(nntp) uploads. Inspired by newsmangler(https://github.com/madcowfred/newsmangler). Sanguinews is written entirely in ruby. Supports multithreading and SSL.

INSTALLATION
============
Use git clone to get the newest version:

    git clone https://github.com/tdobrovolskij/sanguinews.git

Install nzb gem for nzb file creation:

    gem install nzb

How to use
==========
Copy and rename sample.conf to your home directory:

    cp sample.conf ~/.sanguinews.conf

Adjust it with you favourite text editor. I hope that no explanation will be needed.
To upload a file:

    ./sanguinews.rb -f file_to_upload

To upload a directory:

    ./sanguinews.rb /path/to/directory

View help:

    ./sanguinews.rb --help

CREDITS
=======
* nntp library(crudely modified by me) from http://nntp.rubyforge.org/ project.
* yenc decoder gem by Sam "madgeekfiend" Contapay(https://github.com/madgeekfiend/yenc)

HISTORY
=======
* 0.30 - Nzb files can now be generated.
* 0.22 - Less verbosity in normal mode. More helpful help.
* 0.20 - Directories can be uploaded as well.
* 0.10 - Initial release; Only file mode exists
