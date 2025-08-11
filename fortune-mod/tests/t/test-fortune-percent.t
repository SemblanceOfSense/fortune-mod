#!/usr/bin/perl

use strict;
use warnings;
use 5.014;

use FindBin;
use lib "$FindBin::Bin/lib";
use FortTestInst ();

use Path::Tiny qw/ cwd path tempdir tempfile /;
use Test::More tests => 25;
use Test::Trap
    qw( trap $trap :flow:stderr(systemsafe):stdout(systemsafe):warn );

my $IS_WIN = ( $^O eq "MSWin32" );

# TEST:$_common_tests=2;
sub _common_tests
{
    my ( $blurb_base, $inst_dir ) = @_;

    my $sys = sub {
        my @cmd = @_;
        return system( $IS_WIN ? ( map { s/%/%%/gmrs } @cmd ) : @cmd );
    };

    {
        my @cmd = (
            $inst_dir->child( 'games', 'fortune' ),
            qw/ 70% all 30% computers /,
        );

        print "Running [@cmd]\n";
        trap
        {
            $sys->(@cmd);
        };

        # TEST*$_common_tests
        like( $trap->stdout(), qr/\S/ms,
            "$blurb_base : 70/30 percentages : stdout was used",
        );

        # TEST*$_common_tests
        like( $trap->stderr(), qr/\A\r?\n?\z/ms,
            "$blurb_base : 70/30 percentages : stderr is empty. ",
        );
    }

    {
        my @cmd = (
            $inst_dir->child( 'games', 'fortune' ),
            qw/ 99% all 1% computers /,
        );

        print "Running [@cmd]\n";
        trap
        {
            $sys->(@cmd);
        };

        # TEST*$_common_tests
        like( $trap->stdout(), qr/\S/ms,
            "$blurb_base : 99 percentages : stdout was used",
        );

        # TEST*$_common_tests
        like( $trap->stderr(), qr/\A\r?\n?\z/ms,
            "$blurb_base : 99 percentages : stderr is empty. ",
        );
    }

    {
        my @cmd = (
            $inst_dir->child( 'games', 'fortune' ),
            qw/ 1% all 99% computers /,
        );

        print "Running [@cmd]\n";
        trap
        {
            $sys->(@cmd);
        };

        # TEST*$_common_tests
        like( $trap->stdout(), qr/\S/ms,
            "$blurb_base : 1percent-vs-99 percentages : stdout was used",
        );

        # TEST*$_common_tests
        like( $trap->stderr(), qr/\A\r?\n?\z/ms,
            "$blurb_base : 1percent-vs-99 percentages : stderr is empty. ",
        );
    }
    return;
}

{
    my $inst_dir = FortTestInst::install("fortune-percent-overflow");

    {
        my @cmd = ( $inst_dir->child( 'games', 'fortune' ), "art" );

        print "Running [@cmd]\n";
        trap
        {
            system(@cmd);
        };

        {
            # TEST
            like( $trap->stdout(), qr/\S/ms, "basic test", );

            # TEST
            like( $trap->stderr(), qr/\A\r?\n?\z/ms, "basic test: stderr", );
        }
    }

    {
        my @cmd =
            ( $inst_dir->child( 'games', 'fortune' ), "notexisttttttttttt" );

        print "Running [@cmd]\n";
        trap
        {
            system(@cmd);
        };

        {
            # TEST
            unlike( $trap->stdout(), qr/\S/ms, "No fortunes found", );

            # TEST
            like(
                $trap->stderr(),
                qr/\ANo fortunes found/ms,
                "error message for No fortunes found",
            );
        }
    }

    _common_tests( "local-dir == system-dir", $inst_dir, );

    my @cmd = (
        $inst_dir->child( 'games', 'fortune' ),
        "999999999999999%", "songs-poems"
    );

    print "Running [@cmd]\n";
    trap
    {
        system(@cmd);
    };

    # TEST
    like( $trap->stderr(),
        qr/Overflow percentage detected at argument "999999999999999%"!/,
        "right error." );

    # TEST
    unlike( $trap->stderr(), qr/-[0-9]/, "negative integer" );
}

{
    my $LOCALDIR_suffix = "local/foo";
    my $inst_dir        = FortTestInst::install(
        "fortune-percent-LOCALDIR",
        +{
            LOCALDIR_suffix => $LOCALDIR_suffix,
        }
    );
    my $local_dir = path("$inst_dir/$LOCALDIR_suffix");
    $local_dir->mkdir();
    my $cookiefile_bn = "jokkkkkkkkkkkes";
    my $datfile_bn    = "$cookiefile_bn.dat";
    my $cookiefile    = $local_dir->child($cookiefile_bn);
    my $datfile       = $local_dir->child($datfile_bn);
    my $text          = <<"EOF";
This statement is false.
%
The diff between theory and practice is that, in theory, there isn't a diff
between theory and practice, while, in practice, there is.
%
EOF
    $cookiefile->spew_utf8($text);
    {
        my @cmd = ( $inst_dir->child( 'bin', 'strfile' ), $cookiefile, );

        print "Running [@cmd]\n";
        trap
        {
            system(@cmd);
        };

        # TEST
        like( $trap->stderr(), qr/\A\r?\n?\z/, "right error." );

    }
    {
        my @cmd = ( $inst_dir->child( 'games', 'fortune' ), "70%", "all" );

        print "Running [@cmd]\n";
        trap
        {
            system(@cmd);
        };

        {
            # TEST
            like(
                $trap->stderr(),
                qr/fortune: no place to put residual probability/ms,
"percent overflow: https://github.com/shlomif/fortune-mod/issues/79 [all percent when local+system dirs have fortunes]"
            );

            # TEST
            unlike(
                $trap->stderr(),
                qr/[pP]robabilities sum to 140\%/,
"percent overflow: https://github.com/shlomif/fortune-mod/issues/79 [all percent when local+system dirs have fortunes]"
            );
        }
    }

    {
        my @cmd = ( $inst_dir->child( 'games', 'fortune' ), "art" );

        print "Running [@cmd]\n";
        trap
        {
            system(@cmd);
        };

        {
            # TEST
            like( $trap->stdout(), qr/\S/ms, "basic test", );

            # TEST
            like( $trap->stderr(), qr/\A\r?\n?\z/ms, "basic test: stderr", );
        }
    }

    {
        my @cmd =
            ( $inst_dir->child( 'games', 'fortune' ), "notexisttttttttttt" );

        print "Running [@cmd]\n";
        trap
        {
            system(@cmd);
        };

        # TEST
        unlike( $trap->stdout(), qr/\S/ms,
            "[ local+system paths have fortunes ] No fortunes found",
        );

        # TEST
        like(
            $trap->stderr(),
            qr/\ANo fortunes found/ms,
"[ local+system paths have fortunes ] error message for No fortunes found",
        );
    }

    _common_tests( "local-dir is populated and not system-dir", $inst_dir, );
}
