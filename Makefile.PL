use ExtUtils::MakeMaker;

use strict;
require 5.003;  # maybe it'll work with 5.002, haven't tried.
use Config;

use vars qw($archname @convention $convention $num_callbacks $cflags);
use subs qw(write_xs);

$Config{usedl} eq 'define'
    or die <<TOOBAD;
Static perl!

For this module to work, Perl must be capable of loading dynamic
libraries using the DynaLoader module.  If I understand your Config.pm
correctly, your perl doesn't do this.  You will have to build a new
perl to use this module.

TOOBAD


@convention = ();
$cflags = "";
map {
    /^DECL=(.*)$/ and push @convention, split(",", $1);
    /^CALLBACKS=(\d+)$/ and $num_callbacks = $1;
    /^HAVE_(.+)$/ and $cflags .= " -DHAVE_$1";
} @ARGV;

# Appease MakeMaker:
@ARGV = grep { !/^(DECL|CALLBACKS)=/ && !/^HAVE_/ } @ARGV;

$archname = $Config{archname};
unless (@convention) {
    for (
	 [ '^i[3-9]86.*linux$', ['cdecl'] ],
	 [ '^i[3-9]86.*bsd$', ['cdecl'] ],
	 [ '^sun4-', ['sparc'] ],
	 [ '', [] ],
	 ) {
	@convention = @{$_->[1]}, last if $archname =~ /$_->[0]/;
    }
}

@convention or die <<SORRY;
Wrong architecture!

According to Config.pm, your system architecture is "$archname".
This module uses architecture-dependent code which may not work on
your system.

The code in question relates to argument-passing conventions for
native-compiled functions.  Currently, three conventions are supported:
`cdecl', `sparc', and `hack30'.

If you're not too worried about programs crashing, you may try these
out by running, for example, `perl Makefile.PL DECL=cdecl'.  One of
them may work for your system.

But BE WARNED!!!  THERE IS NO GUARANTEE THAT IT WILL WORK!  Even if
`make test' reports success, the convention you choose may not exactly
match your machine.  The result may be corrupted data and program
crashes due to memory access violations.

On the other hand, if you know your system's calling conventions, you
may want to look at the files cdecl.c and hack30.c to see if you can
do better.  If you find that this module works, or you know how to
make it work, please let me (jtobey\@user1.channel1.com) know.

SORRY


$Config{gccversion} || "@convention" eq "hack30"
	|| $cflags =~ /-DHAVE_ALLOCA_H\b/
    or die <<NOT_GCC;
According to Config.pm, your compiler is "$Config{cc}" and there is no
gcc version number.  By default, this module uses the alloca()
function, which is a gcc builtin.

If your compiler supports the alloca() function, please accept my
apologies and type `perl Makefile.PL HAVE_ALLOCA_H' to continue.

If you do not have alloca() and would like to try a hack that avoids
it (at the expense of some generality and maybe efficiency), you may
use `perl Makefile.PL DECL=hack30'.  However, I recommend you get gcc
and build perl with it. ;-)

In any case, be sure to run `make test' before you think about
installing this module.

NOT_GCC


print "Using calling convention(s): @convention\n";
print "Default calling convention: $convention[0]\n";
$num_callbacks = 4 unless defined($num_callbacks);
print "Maximum number of callbacks: $num_callbacks\n";

write_xs();

WriteMakefile(
    'NAME'	=> 'ExtUtils::DynaLib',
    'VERSION_FROM' => 'DynaLib.pm', # finds $VERSION
    'DEFINE'	=> $cflags,     # e.g., '-DHAVE_SOMETHING' 
    'INC'	=> '-I.',     # e.g., '-I/usr/include/other' 
);


sub MY::postamble {
    my $self = shift;
    return "
clean::
	$self->{RM_F} DynaLib.xs

DynaLib.xs: Makefile.PL

DynaLib.o: callback.c callback.h @{[ map { \"$_.c\" } @convention ]}
"
}

sub write_xs {
  my ($i);

# Write DynaLib.xs

open XS, ">DynaLib.xs"
    or die "Can't write file \"DynaLib.xs\": $!\n";
print "Writing DynaLib.xs\n";

#
# Top section is typical h2xs default stuff.
#
print XS <<XS;
#line ${\ (__LINE__ + 2)} "$0"
#ifdef __cplusplus
extern "C" {
#endif
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#ifdef __cplusplus
}
#endif

#define NUM_CALLBACKS $num_callbacks
#include "callback.h"
XS

#
# Each calling convention adds its own chunk of code.
# The file ${convention}.c must define a macro
# ${convention}_CALL(func, type) for calling the function pointed to by func
# returning type type.
# The arguments to this function will be found on the perl stack.
# Each arg will be packed as the appropriate type.
#
for $convention (@convention) {
    print XS "#include \"${convention}.c\"\n";
}

#
# The callback functions.
#
for $i (0 .. $num_callbacks - 1) {
    print XS <<XS;

#line ${\ (__LINE__ + 3)} "$0"
static int
#ifdef I_STDARG
_cb_func$i(int first, ...)
#else
_cb_func$i(int first, va_alist)
va_dcl
#endif
{
  va_list ap;
  int result;

#ifdef I_STDARG
  va_start(ap,first);
#else
  va_start(ap);
#endif
  result = cb_call_sub($i, first, ap);
  va_end(ap);
  return result;
}
XS
}

#
# Array of pointers to callback entry points.
#
print XS "\nstatic const cb_callback cb_arr[] = {\n";
for $i (0 .. $num_callbacks - 1) {
    print XS "\t_cb_func$i,\n";
}
print XS <<XS;
};

#include "callback.c"
XS

#
# Switch from C to XS mode.
#
print XS "\n\nMODULE = ExtUtils::DynaLib  PACKAGE = ExtUtils::DynaLib\n";

#
# XS definitions for the "glue" functions that call C via the macro
# described above.  We write one function per return type per
# calling convention.
#
for $convention (@convention) {
    print XS <<XS;

void
${convention}_void_call_packed(symref, ...)
	void *		symref
	PROTOTYPE: \$\@
	CODE:
	{
	  (void) ${convention}_CALL(symref, int);
	}

int
${convention}_int_call_packed(symref, ...)
	void *		symref
	PROTOTYPE: \$\@
	CODE:
	{
	  RETVAL = ${convention}_CALL(symref, int);
	}
	OUTPUT: RETVAL

double
${convention}_double_call_packed(symref, ...)
	void *		symref
	PROTOTYPE: \$\@
	CODE:
	{
	  RETVAL = ${convention}_CALL(symref, double);
	}
	OUTPUT: RETVAL

char *
${convention}_string_call_packed(symref, ...)
	void *		symref
	PROTOTYPE: \$\@
	CODE:
	{
	  RETVAL = ${convention}_CALL(symref, char *);
	}
	OUTPUT: RETVAL

void *
${convention}_ptr_call_packed(symref, ...)
	void *		symref
	PROTOTYPE: \$\@
	CODE:
	{
	  RETVAL = ${convention}_CALL(symref, void *);
	}
	OUTPUT: RETVAL
XS
}

#
# Provide a default calling convention.  It is the first one in @convention.
#
print XS <<XS;

BOOT:
#line ${\ (__LINE__ + 4)} "$0"
        newXSproto("ExtUtils::DynaLib::_void_call_packed", XS_ExtUtils__DynaLib_$convention[0]_void_call_packed, file, "\$\@");
        newXSproto("ExtUtils::DynaLib::_int_call_packed", XS_ExtUtils__DynaLib_$convention[0]_int_call_packed, file, "\$\@");
        newXSproto("ExtUtils::DynaLib::_double_call_packed", XS_ExtUtils__DynaLib_$convention[0]_double_call_packed, file, "\$\@");
        newXSproto("ExtUtils::DynaLib::_string_call_packed", XS_ExtUtils__DynaLib_$convention[0]_string_call_packed, file, "\$\@");
        newXSproto("ExtUtils::DynaLib::_ptr_call_packed", XS_ExtUtils__DynaLib_$convention[0]_ptr_call_packed, file, "\$\@");
	/* Setup the callback config array. */
#if PATCHLEVEL >= 4
	sv_setsv(SvRV(ST(2)), newRV_noinc((SV*) cb_init(ST(2))));
#else
	sv_setsv(SvRV(ST(2)), newRV((SV*) cb_init(ST(2))));
#endif
XS
close XS;
}
