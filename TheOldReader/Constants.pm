package TheOldReader::Constants;

use strict;
use warnings;
use parent qw(Exporter);

use constant GUI_CATEGORIES_WIDTH => 30;
use constant GUI_CATEGORIES_WIDTHSMALL => 15;
use constant GUI_UPDATE => 120;

use constant DEFAULT_MAX => 10;
use constant WAIT_WATCH => 10;
use constant CACHE_DIR => './cache/';
use constant DEFAULT_HOST => 'https://theoldreader.com';
use constant DEFAULT_CONFIG => 'global.conf';

use constant LOGIN_PATH => '/accounts/ClientLogin';
use constant STATUS => '/reader/api/0/status?output=json';
use constant UNREAD_COUNTS => '/reader/api/0/unread-count?output=json';
use constant SUBSCRIPTION_LIST => '/reader/api/0/subscription/list?output=json';
use constant ITEMS => '/reader/api/0/stream/items/ids?output=json';
use constant CONTENTS => '/reader/api/0/stream/items/contents?output=json';
use constant USER_INFO => '/reader/api/0/user-info?output=json';
use constant EDIT => '/reader/api/0/edit-tag?output=json';
use constant FRIENDS => '/reader/api/0/friend/list?output=json';
use constant EDIT_FRIEND => '/reader/api/0/friend/edit';
use constant ADD_FEED => '/reader/api/0/subscription/quickadd';
use constant EDIT_FEED => '/reader/api/0/subscription/edit';


use constant STATE_ALL => 'user/-/state/com.google/reading-list';
use constant STATE_LIKE => 'user/-/state/com.google/like';
use constant STATE_READ => 'user/-/state/com.google/read';
use constant STATE_STARRED => 'user/-/state/com.google/starred';
use constant STATE_BROADCAST => 'user/-/state/com.google/broadcast';
use constant STATE_FRIENDS => 'user/-/state/com.google/broadcast-friends';

1;
