# The Old Reader Perl Tools

## Unofficial api
This is an unofficial perl api  based on the documentation found at https://github.com/theoldreader/api

## Dependencies
The following modules are used by the package:

* JSON
* LWP::UserAgent
* IO::Prompt
* Curses::UI (used for gui only, not  mandatory)

On debian you can install the packages using the apt command:

### If you want the gui

    $ apt-get install libjson-perl libwww-perl libio-prompt-perl libcurses-ui-perl

### If you don't want the gui

    $ apt-get install libjson-perl libwww-perl libio-prompt-perl

## First use

Use reader.pl script to create a configuration that contains the auth token. No username/password will be stored.

    $ ./reader.pl create_config
    Creating configuration:
    Username: my@mail
    Password: ************
    Max items displayed: 10
    File global.conf created.

## Commands

Once you have configured the script, you can use one of the following commands:

### Help

Use help command to display the list of commands you can use.

    $ ./reader.pl help
    Use: ./reader.pl [ create_config | unread | last | labels | mark_read | subscription_list | unread_feeds ]
    ...



### Last unread items

To display last unread items, just use the unread command:

    $ ./reader.pl unread
    tag:google.com,2005:reader/item/54ce6c62b88035d71a002a63
    "Amigos del @ppmadrid. Lo de la foto no es Auschwitz, es Burgos. Me parece que os queda más cerca"
    http://meneame.feedsportal.com/c/34737/f/639540/s/42ed29b3/sc/7/l/0M0Smeneame0Bnet0Cstory0Camigos0Eppmadrid0Efoto0Eno0Eauschwitz0Eburgos0Eparece0Eos0Equeda0Emas/story01.htm
    
    Mark items as read? [O/n]: 

When displaying unread items, you will be asked if you want to mark them as read.

### Last items

You can display already read items by using the 'last' command.

    $ ./reader.pl last


#### Filter by labels/category

If you have many feeds ordered by categories, you may want to display only the feeds that are in one category.

Just use the 'labels' command to get a list of the categories you have:

    $ ./reader.pl labels
    List of labels:
     - user/-/label/web dev : web dev 
     - user/-/label/news-big : news-big 
     - ...

You can use the 'last' or 'unread' commands, followed by the label to display only the items of that label:

    $ ./reader.pl last user/-/label/news-big

### Watch / Wait for new items

You can wait for new items to by using the 'watch' command. Basically it is loop that never ends, until you press CTRL+C.

    $ ./reader.pl watch
    ... unread items  displayed as they arrived

### List unread feeds

To display the name of the feeds that have unread items:

    ./reader.pl unread_feeds
    Unread items:
      - feed/52e1659d091452dd37000e44 : Menme: publicadas (1) 

    ./reader.pl unread feed/52e1659d091452dd37000e44 
    ...





