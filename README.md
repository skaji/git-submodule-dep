# NAME

App::GitSubmoduleDep - manage module dependencies by git submodule + symlink

# SYNOPSIS

    > git-submodule-dep git://github.com/foo/Module-Name.git
    > git-submodule-dep --delete Module::Name

# DESCRIPTION

App::GitSubmoduleDep helps you manage module dependencies.
If your dependencies are not in cpan but in some git repository
(eg: Github Enterprise), it's difficult to manage them.

This module helps you manage them by git submodule + symlink.

# THANKS TO

[ytnobody](https://github.com/ytnobody), who taught me this technique

# LICENSE

Copyright (C) Shoichi Kaji.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

Shoichi Kaji <skaji@cpan.org>
