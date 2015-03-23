# The Old Reader Cli (Client)

![The Old Reader GUI](http://tfeserver.be/dl/theoldreader_client/theoldreader-cli6.png)

## Unofficial program
This is an unofficial perl client/gui  based on the documentation found at https://github.com/theoldreader/api.


## Dependencies
The following modules are used by the package:

* JSON
* LWP::UserAgent
* IO::Prompt
* Curses::UI (used for gui only, not  mandatory)

On debian you can install the packages using the apt command:

### If you want the gui

    $ apt-get install libjson-perl libwww-perl libio-prompt-perl libcurses-ui-perl libnotify-bin

    $ cpan -i Curses::UI::POE

### If you don't want the gui, just install

    $ apt-get install libjson-perl libwww-perl libio-prompt-perl

### For OS X (using Homebrew/cpanm)

    $ brew install cpanm
    $ sudo perl -MCPAN -e 'install JSON,LWP::UserAgent,IO::Prompt,Curses::UI,Curses::UI::POE,Mozilla::CA'

## First run and creation of configuration file

When running for the first time, the gui will ask you to create a configuration file.


    $ ./gui.pl
    Creating configuration:
    Username: my@mail
    Password: ************
    ....

## GUI

### Run the GUI

To run the gui, run the gui.pl script

    $ ./gui.pl

When loaded, you will find a list of labels (on the left), and a list of associated items, on the right.

![The Old Reader GUI](http://tfeserver.be/dl/theoldreader_client/theoldreader-cli6.png)

Use tab to switch between windows, and press enter to select an item.

Press ? key at any time to display the shortcuts you can use.

### Triggers

A list of automatic commands can be runned using triggers.

You will need to edit the configuration file manually since there is no gui (for now) to edit them.

The syntax is simple, there is one trigger per line, and a trigger must have 2 parts:

- Condition(s)
- Action(s)

Available conditions:

- title=value # Check for title containing value
- label=value # Check for feed containing this label
- unread=1 # Check for item not read already
- unread=0 # Check for item read already

Available actions:

- open # Auto open on browser
- read # Mark item as read
- star # Mark item as  starred
- like # Mark item as liked
- share # Mark item as shared (without message)
- notify # Display a desktop notification with the feed title

Example:

    # Default structure is:
    # trigger:"conditions","run actions"

    # Auto mark as read sponsored feeds
    trigger:"title=[Sponsored]","read"

    # This trigger auto open on browser all the items displayed that have the label "Download"
    trigger:"label=Download","open"


    # This trigger auto flag to read all the unread items
    trigger:"unread=0","read"

    # This trigger auto open on browser all the items which title contains the word video
    trigger:"title=video","open"

    # This trigger send a desktop notification of each new item displayed
    trigger:"unread=1","notify"

    # You can also mix all them together:
    # Auto open and read  the unread items that are on label "News", and which title contains the word video
    trigger:"unread=0,label=News,title=video","open,read"


