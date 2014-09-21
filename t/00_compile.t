use strict;
use Test::More 0.98;

use_ok $_ for qw(
    App::GitSubmoduleDep
);

ok system($^X, "-wc", "script/git-submodule-dep") == 0;

done_testing;

