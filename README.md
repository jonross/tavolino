
This is just an undisciplined pile of hackery at the moment.

I'm dumping it all here and will start to put some structure around it.

Thoughts

    * Python-based features accessible as individual shell commands, optionally
      with a prefix to avoid conflicts with other commands (like sum(1))

    * Will need a Makefile to generate the shell aliases... or perhaps not.  The
      driver itself could write eval'able shell syntax.  Then it would be fully
      distributable as a single Python script.  If I want that.

    * Do I want that?  What's the correct way to distribute a Python script
      that's backed by a library?  Do I care if it's library-ized?

    * File serving / decompression in a separate process because I/O.  Don't
      make every stage a separate process because it complicates the metadata.
      Plus multi-threading is available from the shell... just say a | b.

    * Custom parsing requirements are well beyond argparse; don't use.

    * Import pandas / matplotlib only when needed or performance will suffer.



