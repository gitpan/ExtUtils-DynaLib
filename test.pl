# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..8\n"; }
END {print "not ok 1\n" unless $loaded;}
use ExtUtils::DynaLib qw(DeclareSub);
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

eval {
    # The original name of this module was "DumpCore"...
    # ...and it was very good at it...
    # the moral being that segmentation faults and the like
    # should be expected when using this code.

    $SIG{SEGV} = sub { use Carp; confess "Illegal memory operation" };
    $SIG{ILL} = $SIG{SEGV};
};

unless (defined(&DeclareSub)) {
  # Perl 5.003's Exporter behaved differently.
  sub DeclareSub { &ExtUtils::DynaLib::DeclareSub }
}

$num = 2;
sub assert {
    my ($assertion, $got, $expected) = @_;
    if ($assertion && $got eq $expected) {
	print "ok $num\n";
    } elsif ($got ne $expected) {
	print "not ok $num; expected \"$expected\", got \"$got\"\n";
    } else {
	print "not ok $num\n";
    }
    ++ $num;
}

use Config;
$libc_arg = $Config{libc} || "-lc";
eval { $libc = new ExtUtils::DynaLib($libc_arg); };

if ($@) {
  if ($^O eq "cygwin3295" || $^O eq "MSWin32") {
    $libc_arg = "\\WINDOWS\\SYSTEM\\MSVCRT40.DLL";
    eval { $libc = new ExtUtils::DynaLib($libc_arg); };
    $@ && eval { $libc = new ExtUtils::DynaLib("MSVCRT40.DLL"); };
  } elsif ($^O eq 'linux') {
    eval { $libc = new ExtUtils::DynaLib("libc.so.6"); };
  }
}
if ($@) {
    assert(0);
    die "Can't load -lc: $@", "Giving up.\n";
}

$libm_arg = DynaLoader::dl_findfile("-lm");
$@ = "";
if (! $libm_arg || $libm_arg =~ /libm\.a$/) {
    $libm = $libc;
} else {
    eval { $libm = new ExtUtils::DynaLib("-lm"); };
}
$@ || eval {
    $pow = $libm->DeclareSub ({ "name" => "pow",
				 "return" => "double",
				 "args" => ["d", "d"],
			     });
};
if ($@ || ! $pow) {
    warn "$0: Can't find dynamic -lm!  Skipping the math lib tests.\n";
    assert(1);
} else {
    $sqrt2 = &$pow(2, 0.5);
    assert(1, $sqrt2, 2**0.5);
}

$strlen = $libc->DeclareSub ({ "name" => "strlen",
				"return" => "int",
				"args" => ["p"],
			    });

# Can't do this in perl <= 5.00401 because it results in a
# pack("p", constant)...
#
# $len = &$strlen("oof rab zab");

$len = &$strlen($tmp = "oof rab zab");
assert(1, $len, 11);

sub my_sprintf {
    my ($fmt, @args) = @_;
    my (@arg_types) = ("P", "p");
    my ($width) = (length($fmt) + 1);

    # note this is a *simplified* (non-crash-proof) printf parser!
    while ($fmt =~ m/(?:%[-#0 +']*\d*(?:\.\d*)?h?(.).*?)[^%]*/g) {
			  my $spec = $1;
			  next if $spec eq "%";
			  if (index("dic", $spec) > -1) {
			      push @arg_types, "i";
			      $width += 20;
			  } elsif (index("ouxXp", $spec) > -1) {
			      push @arg_types, "I";
			      $width += 20;
			  } elsif (index("eEfgG", $spec) > -1) {
			      push @arg_types, "d";
			      $width += 30;
			  } elsif ("s" eq $spec) {
			      push @arg_types, "p";
			      $width += length($args[$#arg_types]);
			  } else {
			      die "Unknown printf specifier: $spec\n";
			  }
	       }
		      my $buffer = "\0" x $width;
		      &{$libc->DeclareSub("sprintf", "void", @arg_types)}
			($buffer, $fmt, @args);
		      $buffer =~ s/\0.*//;
		      return $buffer;
		  }

{};  # poor old Emacs :(

$fmt = "%x %10sfoo %d %10.7g %f %d %d %d";
@args = (253, "bar", -789, 2.32578, 3.14, 5, 6, 7);

$expected = sprintf($fmt, @args);
$got = my_sprintf($fmt, @args);

assert(1, $got, $expected);

# Try passing a pointer to DeclareSub.
$fopen_ptr = DynaLoader::dl_find_symbol($libc->LibRef(), "fopen")
    or die DynaLoader::dl_error();
$fopen = DeclareSub ({ "ptr" => $fopen_ptr,
		       "return" => "ptr",
		       "args" => ["p", "p"] });

open TEST, ">tmp.tmp"
    or die "Can't write file tmp.tmp: $!\n";
print TEST "a string";
close TEST;

# Can't do &$fopen("tmp.tmp", "r") in perls before 5.00402.
$fp = &$fopen($tmp1 = "tmp.tmp", $tmp2 = "r");
if (! $fp) {
    assert(0);
} else {
    # Hope "I" will work for types size_t and (FILE *)!
    $fread = $libc->DeclareSub("fread", "int",
				"P", "I", "I", "I");
    $buffer = "\0" x 4;
    $result = &$fread($buffer, 1, length($buffer), $fp);
    assert($result == 4, $buffer, "a st");
    unlink "tmp.tmp";
}

if (@$ExtUtils::DynaLib::Callback::Config) {
    $ptr_len = length(pack("p", $tmp = "foo"));
    sub compare_lengths {
	# Not a model of efficiency, only a test of functionality!!
	my ($ppa, $ppb) = @_;
	my $pa = unpack("P$ptr_len", pack("i", $ppa));
	my $pb = unpack("P$ptr_len", pack("i", $ppb));
	my $A = unpack("p", $pa);
	my $B = unpack("p", $pb);
	length($A) <=> length($B);
    }
    @list = qw(A bunch of elements with unique lengths);
    $array = pack("p*", @list);

    #
    # This appears to work with either \&compare_lengths or
    # "::compare_lengths", but not "compare_lengths".
    #
    $callback = new ExtUtils::DynaLib::Callback(\&compare_lengths, "i",
						"i", "i");

    $qsort = $libc->DeclareSub("qsort", "void", "P", "I", "I", "I");
    &$qsort($array, scalar(@list), length($array) / @list, $callback->Ptr());

    @expected = sort { length($a) <=> length($b) } @list;
    @got = unpack("p*", $array);
    assert(1, "[@got]", "[@expected]");

    # Hey!  We've got callbacks.  We've got a way to call them.
    # Who needs libraries?
    $callback = new ExtUtils::DynaLib::Callback(sub {
	$_[0] + 10*$_[1] + 100*$_[2];
    }, "i", "i", "p", "i");
    $foo = DeclareSub($callback->Ptr(), "i", "i", "p", "i");

    $got = &$foo(1, $tmp = 7, 3.14);
    $expected = 371;
    assert(1, $got, $expected);
} else {
    warn("Skipping callback tests on this platform\n");
    assert(1);
    assert(1);
}

$buf = "willo";
ExtUtils::DynaLib::Poke(unpack("i", pack("p", $buf)), "he");
assert(1, $buf, "hello");

# Can't unload libraries (portably, yet) because DynaLoader does not
# support this.
