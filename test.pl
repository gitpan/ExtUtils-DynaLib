# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..6\n"; }
END {print "not ok 1\n" unless $loaded;}
use ExtUtils::DynaLib;
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

eval {
    # The original name of this module was "DumpCore"...
    # ...and it was very good at it...
    # the moral being that segmentation faults should be expected
    # when using this code.
    $SIG{SEGV} = sub { die "Illegal memory operation" };
};

$libm_arg = DynaLoader::dl_findfile("-lm");
if (! $libm_arg || $libm_arg =~ /libm\.a$/) {
    warn "$0: Can't find dynamic -lm!  Skipping the math lib tests.\n";
    print "ok 2\n";
} else {
    $libm = new ExtUtils::DynaLib("-lm");
    $pow = $libm->declare_sub ({ "name" => "pow",
				 "return" => "double",
				 "args" => ["d", "d"],
			     });
    $sqrt2 = &{$pow}(2, 0.5);
    print (abs($sqrt2 - 1.414) < 0.001 ? "ok 2\n" : "not ok 2\n");
}

use Config;
$libc_arg = $Config{libc} || "-lc";
eval { $libc = new ExtUtils::DynaLib($libc_arg); };

if ($@) {
    print "not ok 3\n";
    die "Can't load -lc!  Giving up.\n";
    exit;
}

$strlen = $libc->declare_sub ({ "name" => "strlen",
				"return" => "int",
				"args" => ["p"],
			    });

# Can't do this because it results in a pack("p", constant):
# $len = &{$strlen}("oof rab zab");
#
#...unless you patch the perl5.004_01 source as shown below.
#
# NOTE: THIS PATCH OF THE PERL SOURCE CODE IS UNTESTED, MAY INTRODUCE
# BUGS, WILL ALLOW YOU TO WRITE PROGRAMS THAT ARE INCOMPATIBLE WITH
# STANDARD PERL, AND IS GENERALLY NOT A GOOD IDEA TO USE IN PRODUCTION.
# You have been warned.
#
<<'PATCH';
*** pp.c	Thu Jun 12 21:11:14 1997
--- pp.c	Sat Jun 28 15:18:39 1997
***************
*** 3834,3840 ****
  	case 'p':
  	    while (len-- > 0) {
  		fromstr = NEXTFROM;
! 		aptr = SvPV_force(fromstr, na);	/* XXX Error if TEMP? */
  		sv_catpvn(cat, (char*)&aptr, sizeof(char*));
  	    }
  	    break;
--- 3834,3849 ----
  	case 'p':
  	    while (len-- > 0) {
  		fromstr = NEXTFROM;
! 		if (fromstr == &sv_undef)
! 		    aptr = NULL;
! 		else {
! 		    if (SvTEMP(fromstr) || SvPADTMP(fromstr))
! 			fromstr = sv_mortalcopy(fromstr);
! 		    if (SvPOK(fromstr) || SvNIOK(fromstr))
! 			aptr = SvPV(fromstr,na);
! 		    else
! 			aptr = SvPV_force(fromstr, na);
! 		}
  		sv_catpvn(cat, (char*)&aptr, sizeof(char*));
  	    }
  	    break;
PATCH


$len = &{$strlen}($tmp = "oof rab zab");
print ($len == 11 ? "ok 3\n" : "not ok 3\n");

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
		      &{$libc->declare_sub("sprintf", "void", @arg_types)}
			($buffer, $fmt, @args);
		      $buffer =~ s/\0.*//;
		      return $buffer;
		  }

{};  # poor old Emacs :(

$fmt = "%x %10sfoo %d %10.7g %f %d %d %d\n";
@args = (253, "bar", -789, 2.32578, 3.14, 5, 6, 7);

$expected = sprintf($fmt, @args);
$got = my_sprintf($fmt, @args);

print ($got eq $expected ? "ok 4\n" : "not ok 4\n");

# Try passing a pointer to declare_sub.
# Note: the libref method is "undocumented"
# so don't count on it existing in the future.
$fopen_ptr = DynaLoader::dl_find_symbol($libc->libref(), "fopen")
    or die DynaLoader::dl_error();
$fopen = ExtUtils::DynaLib::declare_sub ({ "ptr" => $fopen_ptr,
			      "return" => "ptr",
			      "args" => ["p", "p"] });

open TEST, ">tmp.tmp"
    or die "Can't write file tmp.tmp: $!\n";
print TEST "a string";
close TEST;

# Can't do &{$fopen}("tmp.tmp", "r") without the above patch.
$fp = &{$fopen}($tmp1 = "tmp.tmp", $tmp2 = "r");
print ($fp ? "ok 5\n" : "not ok 5\n");

# Hope "I" will work for types size_t and (FILE *)!
$fread = $libc->declare_sub("fread", "int",
				  "P", "I", "I", "I");
$buffer = "\0" x 4;
$result = &{$fread}($buffer, 1, length($buffer), $fp);
print ($result == 4 && $buffer eq "a st" ? "ok 6\n" : "not ok 6\n");

unlink "tmp.tmp";

# Can't unload libraries (portably, yet) because DynaLoader does not
# support this.
