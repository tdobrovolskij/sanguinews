sanguinews
==========
[![Gem Version](https://badge.fury.io/rb/sanguinews.svg)](http://badge.fury.io/rb/sanguinews)

Sanguinews is a simple, commandline client for Usenet(nntp) uploads. Inspired by [newsmangler](https://github.com/madcowfred/newsmangler). Sanguinews is written in ruby(yenc encoding is done in C). Supports multithreading and SSL.

INSTALLATION
============
Because of some C code, C compiler is needed(GCC or Apple's clang). On Debian-based systems it can be installed by:

    apt-get install build-essential

Debian systems need also additional ruby development headers:

    apt-get install ruby-dev

Now you can simply install `sanguinews` as a gem:

    gem install sanguinews

How to use
==========
  You will get a sample config in your home directory when you run sanguinews for the first time. Open it in your favourite text editor and adjust accordingly:

    vi ~/.sanguinews.conf

Hopefully comments inside will explain everything.

To upload a file:

    sanguinews -f file_to_upload

To upload a directory:

    sanguinews /path/to/directory

View help:

    sanguinews --help

CREDITS
=======
* nntp library(crudely modified by me) from http://nntp.rubyforge.org/ project.
* [Sam "madgeekfiend" Contapay](https://github.com/madgeekfiend) for inspiration/ideas from his [yEnc](https://github.com/madgeekfiend/yenc) project.
* [Kim Burgestrand](https://github.com/Burgestrand) for his [thread-pool library](https://gist.github.com/Burgestrand/2040175).
* [john3voltas](https://github.com/john3voltas) for helping with excess authentication bug(fixed in v0.51) and some proofreading.
* [Stephan Brumme](http://stephan-brumme.com/aboutme/vitae.html) for his [wonderful explanation of CRC32 algorithms](http://create.stephan-brumme.com/crc32/).

HISTORY
=======
* 0.63 - Using my own CRC32 gem now for better performance.
* 0.62 - CRC32 calculation is performed during yencoding now.
* 0.61 - Users will get sample config in their home directory now.
* 0.60 - Complete refactoring. Sanguinews is distributed as a gem now.
* 0.57 - More user friendly error messages. No need for debug mode for regular user.
* 0.56 - Debug and header checking options in config.
* 0.55 - Better logging.
* 0.54 - Header checking.
* 0.53 - Added progress bar for uploads.
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
