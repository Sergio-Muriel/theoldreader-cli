package TheOldReader::Constants;

use strict;
use warnings;
use parent qw(Exporter);

use constant GUI_CATEGORIES_WIDTH => 30;
use constant GUI_UPDATE => 20;

use constant DEFAULT_MAX => 10;
use constant WAIT_WATCH => 10;
use constant CACHE_DIR => './cache/';
use constant DEFAULT_HOST => 'http://theoldreader.com';
use constant DEFAULT_CONFIG => 'global.conf';

use constant LOGIN_PATH => '/accounts/ClientLogin';
use constant STATUS => '/reader/api/0/status?output=json';
use constant UNREAD_COUNTS => '/reader/api/0/unread-count?output=json';
use constant STARRED => '/reader/api/0/stream/items/ids?output=json&s=user/-/state/com.google/starred';
use constant SUBSCRIPTION_LIST => '/reader/api/0/subscription/list?output=json';
use constant ITEMS => '/reader/api/0/stream/items/ids?output=json';
use constant CONTENTS => '/reader/api/0/stream/items/contents?output=json';
use constant USER_INFO => '/reader/api/0/user-info?output=json';
use constant LABELS => '/reader/api/0/preference/stream/list?output=json';
use constant EDIT => '/reader/api/0/edit-tag?output=json';
use constant MARK_ALL => '/reader/api/0/mark-all-as-read';


use constant FOLDER_ALL => 'user/-/state/com.google/reading-list';

1;
