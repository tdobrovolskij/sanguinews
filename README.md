sanguinews
==========

Sanguinews is a simple, commandline client for Usenet(nntp) uploads. Inspired by newsmangler(https://github.com/madcowfred/newsmangler). It's written entirely in ruby. Supports multithreading and SSL.

INSTALLATION
============
Use git clone to get the newest version:

    git clone git://github.com/tdobrovolskij/sanguinews.git

How to use
==========
Copy and rename sample.conf to your home directory:

    cp sample.conf ~/.sanguinews.conf

Adjust it with you favourite text editor. I hope that no explanation will be needed.

    ./sanguinews.rb -f file_to_upload

CREDITS
=======
nntp library(crudely modified by me) from http://nntp.rubyforge.org/ project.
yenc decoder gem by Sam "madgeekfiend" Contapay(https://github.com/madgeekfiend/yenc)

HISTORY
=======
* 0.1 - Initial release; Only file mode exists
