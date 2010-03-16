# -*- perl -*-

package Bundle::DBD::CSV;

$VERSION = "1.03";

1;

__END__

=head1 NAME

Bundle::DBD::CSV - A bundle to install the DBD::CSV driver

=head1 SYNOPSIS

  perl -MCPAN -e 'install Bundle::DBD::CSV'

=head1 CONTENTS

DBI 1.611

Text::CSV_XS 0.71

SQL::Statement 1.25

DBD::File 0.38

DBD::CSV 0.28

=head1 DESCRIPTION

This bundle includes all that's needed to access so-called CSV (Comma
Separated Values) files via a pseudo SQL engine (SQL::Statement) and DBI.

=head1 AUTHOR

This module is currently maintained by

    H.Merijn Brand <h.m.brand@xs4all.nl>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009-2010 by H.Merijn Brand
Copyright (C) 2004-2009 by Jeff Zucker
Copyright (C) 1998-2004 by Jochen Wiedmann

All rights reserved.

You may distribute this module under the terms of either the GNU
General Public License or the Artistic License, as specified in
the Perl README file.

=cut
