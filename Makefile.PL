use ExtUtils::MakeMaker;

use strict;
require 5.002;
use Config;

use vars qw($archname @convention $convention
	    $num_callbacks %cflags
	    $conv_xs $cbfunc_c);
use subs qw(write_conv write_cbfunc);

$Config{usedl} eq 'define'
    or die <<TOOBAD;
Static perl!

For this module to work, Perl must be capable of loading dynamic
libraries using the DynaLoader module.  If I understand your Config.pm
correctly, your perl doesn't do this.  You will have to build a new
perl to use this module.

TOOBAD


@convention = ();
%cflags = ();
map {
    /^DECL=(.*)$/ and push @convention, split(",", $1);
    /^CALLBACKS=(\d+)$/ and $num_callbacks = $1;
    /^-D./ and $cflags{$_} = 1;
    /^(-D.*)=0$/ and $cflags{$1} = 0;
} @ARGV;

# Appease MakeMaker:
@ARGV = grep { !/^(DECL=|CALLBACKS=(\d+)$|-D.)/ } @ARGV;

$archname = $Config{archname};
unless (@convention) {
    for (
	 [ '^i[3-9]86.*linux$', sub {'cdecl'} ],
	 [ '^i[3-9]86.*bsd$', sub {'cdecl'} ],
	 [ '^sun4-', sub {'sparc'} ],
	 [ '^cygwin32', sub {
			$num_callbacks = 0 unless defined ($num_callbacks);
			$^O =~ /95/ ? 'cdecl' : ()
		    } ],
	 [ 'MSWin32', sub {'cdecl'} ],
	 [ '', sub { () } ],
	 ) {
	@convention = &{$_->[1]}, last if $archname =~ /$_->[0]/;
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


# Decide whether we need various things defined.
# This should really be determined by compiling and running a test file.

$cflags{-DHAVE_ALLOCA_H} = 1
    if $Config{cc} =~ /\bcc/ && ! exists($cflags{-DHAVE_ALLOCA_H});
$cflags{-DCDECL_ONE_BY_ONE} = 1
    if $Config{gccversion} && ! exists($cflags{-DCDECL_ONE_BY_ONE});
$cflags{-DCDECL_SUBTRACT_CURRENT} = 1
    if $Config{archname} =~ /win32/i
	&& ! exists($cflags{-DCDECL_SUBTRACT_CURRENT});

print "Using calling convention(s): @convention\n";
map { $cflags{"-DDYNALIB_USE_$_"} = 1 } @convention;
print "Default calling convention: $convention[0]\n";
$cflags{"-DDYNALIB_DEFAULT_CONV=\\\"$convention[0]\\\""} = 1;
$num_callbacks = 4 unless defined($num_callbacks);
print "Maximum number of callbacks: $num_callbacks\n";
$cflags{"-DDYNALIB_NUM_CALLBACKS=$num_callbacks"} = 1;

$conv_xs = "conv.xsi";
write_conv();
$cbfunc_c = "cbfunc.c";
write_cbfunc();

WriteMakefile(
    'NAME'	=> 'ExtUtils::DynaLib',
    'VERSION_FROM' => 'DynaLib.pm',
    'DEFINE'	=> join(" ", grep { $cflags{$_} } sort keys %cflags),
    'INC'	=> '-I.',
);


sub MY::postamble {
    my $self = shift;
    my $postamble = "
clean::
	\$(RM_F) $conv_xs $cbfunc_c

$conv_xs: $0 \$(CONFIGDEP)

$cbfunc_c: $0 \$(CONFIGDEP)

DynaLib.c: $conv_xs

DynaLib\$(OBJ_EXT): DynaLib.c $cbfunc_c @{[ map { \"$_.c\" } @convention ]}
";
#    "@convention" =~ /\bcdecl\b/ and $postamble .= "
#clean::
#	\$(RM_F) testcall\$(EXE_EXT) testcall\$(OBJ_EXT) config.h
#
#testcall\$(EXE_EXT): testcall\$(OBJ_EXT)
#
#config.h: testcall\$(EXE_EXT)
#	./testcall\$(EXE_EXT) > \$\@
#
#DynaLib\$(OBJ_EXT): config.h
#";
    return $postamble;
}

sub write_conv {
  my ($i);

# Write conv.xsi, to be included in DynaLib.xs

open XS, ">$conv_xs"
    or die "Can't write file \"$conv_xs\": $!\n";
print "Writing $conv_xs\n";

#
# XS definitions for the "glue" functions that call C via the macro
# described above.  We write one XSUB per return type per
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
close XS;
}

sub write_cbfunc {
  my ($i);

# Write cbfunc.c, to be included in DynaLib.xs

open FUNCS, ">$cbfunc_c"
    or die "Can't write file \"$cbfunc_c\": $!\n";
print "Writing $cbfunc_c\n";
#
# The callback functions.
#
for $i (0 .. $num_callbacks - 1) {
    print FUNCS <<FUNCS;

static int
#ifdef I_STDARG
_cb_func$i(int first, ...)
#else
_cb_func$i(first, va_alist)
int first;
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
FUNCS
}

#
# Array of pointers to callback entry points.
#
print FUNCS "\nstatic const cb_callback cb_arr[DYNALIB_NUM_CALLBACKS] = {\n";
for $i (0 .. $num_callbacks - 1) {
    print FUNCS "\t_cb_func$i,\n";
}
print FUNCS "};\n";
}
