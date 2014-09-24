sanguinews
==========

Sanguinews is a simple, commandline client for Usenet(nntp) uploads. Inspired by newsmangler(https://github.com/madcowfred/newsmangler). Sanguinews is written almost entirely in ruby(almost, because in version 0.45 I have switched from pure ruby yEnc class to inline C code). Supports multithreading and SSL.

INSTALLATION
============
Use git clone to get the newest version:

    git clone https://github.com/tdobrovolskij/sanguinews.git

Because of inline C code, C compiler is needed(GCC or Apple's clang). On Debian-based systems it can be installed by:
```
apt-get install build-essential
```

Some gems are required. Use bundler to resolve dependencies swiftly:
```
gem install bundler
bundle install
```
"bundle install" will check if all dependencies are satisfied and install all the needed gems.

Update process is pretty much straightforward:

    cd sanguinews && git pull

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
* [Sam "madgeekfiend" Contapay](https://github.com/madgeekfiend) for inspiration/ideas from his [yEnc](https://github.com/madgeekfiend/yenc) project.
* thread-pool library from https://gist.github.com/Burgestrand/2040175
* [john3voltas](https://github.com/john3voltas) for helping with excess authentication bug(fixed in v0.51).

HISTORY
=======
* 0.52 - CRC32 calculation won't crash the program on low-end boxes.
* 0.51 - Won't be trying to log in 2nd time if already authenticated.
* 0.50 - Rewrote big part of the code. New libraries. More stable speed.
* 0.48 - Got rid of memory leaks.
* 0.47 - Reusing old connections instead of opening new ones.
* 0.46 - Upload speed is now displayed.
* 0.45 - 3500% performance gain in yencoding.
* 0.44 - Lots of improvements in upload scheduler.
* 0.43 - Improved yEnc encoding algorithm.
* 0.42 - Uploads shouldn't be corrupted anymore.
* 0.41 - Excess parts aren't uploaded anymore.
* 0.40 - Performance problems resolved.
* 0.38 - Stable upload speed achieved.
* 0.37 - Subdirectories cause no more crashes, if present in a uploaded directory.
* 0.36 - yEnc encoding is done fully in memory.
* 0.35 - Minor performance tweaks.
* 0.34 - No more errors if there is at least one config.
* 0.33 - There is now an option to specify config file.
* 0.32 - Multiple files can be specified. 
* 0.30 - Nzb files can now be generated.
* 0.22 - Less verbosity in normal mode. More helpful help.
* 0.20 - Directories can be uploaded as well.
* 0.10 - Initial release; Only file mode exists
