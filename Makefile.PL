use ExtUtils::MakeMaker;

use strict;
require 5.002;
use Config;

use vars qw($archname @convention $convention
	    $num_callbacks %cflags $object
	    $conv_xs $cbfunc_c $cdecl_h $postamble
	    $is_gcc);

$conv_xs = "conv.xsi";
$cbfunc_c = "cbfunc.c";
$cdecl_h = "cdecl.h";
$object = '$(BASEEXT)$(OBJ_EXT)';

$is_gcc = $Config{cc} =~ /gcc/i && $Config{gccversion} >= 2;

use subs qw(write_conv write_cbfunc write_cdecl_h);

$postamble = "
clean::
	\$(RM_F) $conv_xs $cbfunc_c

$conv_xs: $0 \$(CONFIGDEP)

$cbfunc_c: $0 \$(CONFIGDEP)

DynaLib.c: $conv_xs
";


$Config{usedl} eq 'define'
    or die <<TOOBAD;
Static perl!

For this module to work, Perl must be capable of loading dynamic
libraries using the DynaLoader module.  If I understand your Config.pm
correctly, your perl cannot do this.  You will have to get a new
perl to use this module.

TOOBAD


@convention = ();
%cflags = ();
for (@ARGV) {
    /^DECL=(.*)$/ and push @convention, split(",", $1);
    /^CALLBACKS=(\d+)$/ and $num_callbacks = $1;
    /^(-D.*)(?:\=(.*))?$/ and $cflags{$1} = $2;
}

# Appease MakeMaker:
@ARGV = grep { !/^(DECL=|CALLBACKS=(\d+)$|-D.)/ } @ARGV;

$archname = $Config{archname};
unless (@convention) {
    for (
	 [ '^i[3-9]86.*linux', sub {'cdecl'} ],
	 [ '^i[3-9]86.*bsd', sub {'cdecl'} ],
	 [ '^sun4-', sub {'sparc'} ],
	 [ 'sparc', sub {'sparc'} ],
	 [ '^cygwin32', sub {
			$num_callbacks = 0 unless defined ($num_callbacks);
			'cdecl';
		    } ],
	 [ 'MSWin32', sub {'cdecl'} ],
	 [ 'alpha', sub {
			unless ($is_gcc) {
			  $postamble .= "\nalpha-cc\$(OBJ_EXT): alpha-cc.s\n"
			    . "\tcc -c alpha-cc.s -o \$\@\n"
			    . "\n#alpha-cc.s: alpha-cc.c\n"
			    . "#\tgcc -O2 -S alpha-cc.c -o \$\@\n";
			  $object .= " alpha-cc.o";
			}
			'alpha'} ],
	 [ '', sub { () } ],
	 )
    { @convention = &{$_->[1]}, last if $archname =~ /$_->[0]/ }
}

WriteMakefile(
    'NAME'	=> 'ExtUtils::DynaLib',
    'VERSION_FROM' => 'DynaLib.pm',
    'DEFINE'	=> '',
    'OBJECT'	=> $object,

    # Don't let MakeMaker set up a dependency loop.
    # cdecl.h depends on testcall.o, not the other way around!
    'H'         => [],
    'C'         => ['DynaLib.c'],
    'INC'	=> '-I.',
);


sub pretest {
    my $self = shift;
    my @candidate;
    my $cleanup = sub {
	unlink ("testtest.c", "testtest.txt", "testtest$self->{EXE_EXT}",
		"testtest$self->{OBJ_EXT}");
    };
    my $cant = sub {
	&$cleanup;
	print ("I don't know how run the test program,\n",
	       "so I'll try to find a default configuration.\n")
	    if $Verbose;
	return undef;
    };
    my $try = sub {
	open HELLO, "testtest.txt" or return undef;
	my $hello = <HELLO>;
	close HELLO;
	if ($hello =~ /hello, world/) {
	    &$cleanup;
	    return 1;
	}
	return 0;
    };

    &$cleanup;
    unless (open PROG, ">testtest.c") {
	print ("Can't write testtest.c\n");
	return &$cant;
    }
    print PROG <<'PROG';
#include <EXTERN.h>
#include <perl.h>
#undef fprintf
#undef fopen
#undef fclose
#include <stdio.h>
int main(argc, argv, env)
  int argc;
  char **argv;
  char **env;
{
    FILE *fp = fopen("testtest.txt", "w");
    if (fp == NULL) {
	return 1;
    }
    fprintf(fp, "hello, world!\n");
    fclose(fp);
    return 0;
}
PROG
    close PROG;

    @candidate = ();
    push @candidate, "$Config{cc} $Config{ccflags} -DNARF -I$self->{PERL_INC} testtest.c -o testtest$self->{EXE_EXT} >/dev/null 2>&1"
	unless $Verbose;
    push @candidate, "$Config{cc} $Config{ccflags} -DNARF -I$self->{PERL_INC} testtest.c -otesttest$self->{EXE_EXT} >/dev/null 2>&1"
	unless $Verbose;
    push @candidate, "$Config{cc} $Config{ccflags} -DNARF -I$self->{PERL_INC} testtest.c -o testtest$self->{EXE_EXT}";
    push @candidate, "$Config{cc} $Config{ccflags} -DNARF -I$self->{PERL_INC} testtest.c -otesttest$self->{EXE_EXT}";
    $self->{how_to_compile} = "$Config{cc} $Config{ccflags} -DNARF -I$self->{PERL_INC} testtest.c -o testtest$self->{EXE_EXT}";

    while ($self->{how_to_compile} = shift (@candidate)) {
	unlink "testtest$self->{EXE_EXT}";
	print "$self->{how_to_compile}\n" if $Verbose;
	system ($self->{how_to_compile});
	last if $? == 0 && -x "testtest$self->{EXE_EXT}";
    }
    return &$cant unless $self->{how_to_compile};

    @candidate = ();
    push @candidate, "testtest$self->{EXE_EXT} >/dev/null 2>&1"
	unless $Verbose;
    push @candidate, "./testtest$self->{EXE_EXT} >/dev/null 2>&1"
	unless $Verbose;
    push @candidate, "testtest$self->{EXE_EXT}";
    push @candidate, "./testtest$self->{EXE_EXT}";
    push @candidate, "run testtest$self->{EXE_EXT}";

    unlink ("testtest.txt");
    while ($self->{how_to_run} = shift (@candidate)) {
	print "$self->{how_to_run}\n" if $Verbose;
	system ($self->{how_to_run});
	$? == 0 && &$try and return 1;
    }
    return &$cant;
}

sub guess_cdecl_h {
    my $self = shift;
    open CONFIG, ">$cdecl_h" or die "can't write $cdecl_h";

    my $define_if_not = sub {
	my ($macro, $def) = @_;
	return "#ifndef $macro\n#define $macro $def\n#endif\n\n";
    };
    print CONFIG <<CONFIG;
/*
 * $cdecl_h generated by $0.  Do not edit this file, edit $0.
 */
CONFIG
    print CONFIG "#include <alloca.h>\n"
	if $self->{CC} =~ /\bcc$/;
    print CONFIG "#include <malloc.h>\n"
	if $archname =~ /win32/i;
    print CONFIG (&$define_if_not("CDECL_ONE_BY_ONE",
		  (($archname =~ /win32/i && $self->{CC} !~ /\bbcc/i)
		   || $is_gcc) ? 1 : 0));
    print CONFIG (&$define_if_not("CDECL_ADJUST",
		  ($self->{CC} =~ /\bbcc/i ? -12 : 0)));
    print CONFIG (&$define_if_not("CDECL_REVERSE", 0));

    close CONFIG;
}

sub make_postamble {
    my $self = shift;

    $postamble .= "\nDynaLib\$(OBJ_EXT): DynaLib.c $cbfunc_c"
      . " @{[ map { \"$_.c\" } @convention ]}\n";

    ! @convention || grep { $_ eq "cdecl" } @convention
	or return $postamble;

    print "Writing $cdecl_h\n";
    if (write_cdecl_h($self)) {
	@convention = ('cdecl')
	    unless @convention;
    } elsif (@convention) {
	print "Can't figure out this system.  I'll have to guess.\n"
	    if $Verbose;
	guess_cdecl_h($self);
    } else {
	print <<WARN;
***
*** WARNING
***
*** I can't figure out the correct way to pass arguments to a C function
*** on this system.  This may be due to porting issues, a perl installation
*** problem, or any number of things.  Maybe `perl Makefile.PL verbose'
*** will shed some light.
***
*** I'll use the `hack30' calling convention, which may work some or most
*** of the time.  Or it may crash your programs.  A better solution would
*** be to add support for your system's calling convention.
***
*** Be warned, this module is not likely to be of production quality.
***
WARN
	@convention = ('hack30');
	return $postamble;
    }

    $postamble .= "
clean::
	\$(RM_F) testcall\$(EXE_EXT) testcall\$(OBJ_EXT) $cdecl_h

DynaLib\$(OBJ_EXT): $cdecl_h

$cdecl_h: $0 \$(CONFIGDEP) testcall\$(EXE_EXT)
	$self->{how_to_run}

testcall\$(EXE_EXT) : testcall.c
";
}

sub MY::postamble {
    my $self = shift;
    my $postamble = make_postamble($self);

    print "Using calling convention(s): @convention\n"
	if $Verbose;
    for (@convention) { $cflags{"-DDYNALIB_USE_$_"} = undef }

    print "Default calling convention: $convention[0]\n"
	if $Verbose;
    $cflags{"-DDYNALIB_DEFAULT_CONV"} = "\\\"$convention[0]\\\"";

    $num_callbacks = 4 unless defined($num_callbacks);
    print "Maximum number of callbacks: $num_callbacks\n"
	if $Verbose;
    $cflags{"-DDYNALIB_NUM_CALLBACKS"} = $num_callbacks;

    $postamble .= "\nDEFINE =";
    for (sort keys %cflags) {
	$postamble .= " $_";
	$postamble .= "=$cflags{$_}" if defined $cflags{$_};
    }
    write_conv();
    write_cbfunc();

    if (0)
    {
	print "\n> ";
	no strict;
	while (<STDIN>) {
	    eval;
	    print "$@\n" if $@;
	    print "\n> ";
	}
	print "\n";
    }

    return $postamble;
}

sub write_cdecl_h {
    my $self = shift;

    print "Testing how to compile and run a program...\n"
	if $Verbose;
    pretest($self) or return undef;

    print "Testing how to pass args to a function...\n"
	if $Verbose;
    $self->{how_to_compile} =~ s/testtest/testcall/g;
    $self->{how_to_run} =~ s/testtest/testcall/g;
    my $defines;
    for $defines ("-DINCLUDE_ALLOCA", "", "-DINCLUDE_MALLOC") {
	my $cmd = $self->{how_to_compile};
	$cmd =~ s/-DNARF/$defines/g;
	unlink ("testcall$self->{EXE_EXT}", $cdecl_h);
	print "$cmd\n" if $Verbose;
	system ($cmd);
	if ($? == 0 && -x "testcall$self->{EXE_EXT}") {
	    $cmd = $self->{how_to_run};
	    print "$cmd\n" if $Verbose;
	    system ($cmd);
	    if ($? == 0 && -e $cdecl_h) {
		print "Succeeded.\n" if $Verbose;
		return 1;
	    }
	}
    }
    return undef;
}

sub write_conv {
    my ($i, $has_quad);
    $has_quad = eval { pack ("q", 1) };

    # Write conv.xsi, to be included in DynaLib.xs

    open XS, ">$conv_xs"
	or die "Can't write file \"$conv_xs\": $!\n";
    print "Writing $conv_xs\n";

    print XS <<XS;
#
# $conv_xs generated by $0.  Don't edit this file, edit $0.
#
XS

#
# XS definition for the "glue" function that calls C.
#
for $convention (@convention) {
    print XS <<XS;

void
${convention}_call_packed(symref, ret_type, ...)
	void *		symref
	char *		ret_type
	PROTOTYPE: \$\$\@
	PPCODE:
	{
	  SV *sv;
#ifdef HAS_QUAD
	  Quad_t aquad;
	  unsigned Quad_t auquad;
#endif

	  if (*ret_type != '\0') {
	    sv = sv_newmortal();
	  }
	  switch (*ret_type) {
	  case '\0' :
	    (void) ${convention}_CALL(symref, int);
	    XSRETURN_EMPTY;
	  case 'i' :
	    sv_setiv(sv, (IV) ${convention}_CALL(symref, int));
	    break;
	  case 'l' :
	    sv_setiv(sv, (IV) ${convention}_CALL(symref, I32));
	    break;
	  case 's' :
	    sv_setiv(sv, (IV) ${convention}_CALL(symref, I16));
	    break;
	  case 'c' :
	    sv_setiv(sv, (IV) ${convention}_CALL(symref, char));
	    break;
	  case 'I' :
	    sv_setuv(sv, (UV) ${convention}_CALL(symref, unsigned int));
	    break;
	  case 'L' :
	    sv_setuv(sv, (UV) ${convention}_CALL(symref, U32));
	    break;
	  case 'S' :
	    sv_setuv(sv, (UV) ${convention}_CALL(symref, U16));
	    break;
	  case 'C' :
	    sv_setuv(sv, (UV) ${convention}_CALL(symref, unsigned char));
	    break;
#ifdef HAS_QUAD
	  case 'q' :
	    aquad = ${convention}_CALL(symref, Quad_t);
	    if (aquad >= IV_MIN && aquad <= IV_MAX)
	      sv_setiv(sv, (IV)aquad);
	    else
	      sv_setnv(sv, (double)aquad);
	    break;
	  case 'Q' :
	    aquad = ${convention}_CALL(symref, unsigned Quad_t);
	    if (aquad <= UV_MAX)
	      sv_setuv(sv, (UV)auquad);
	    else
	      sv_setnv(sv, (double)auquad);
	    break;
#endif
	  case 'f' :
	    sv_setnv(sv, (double) ${convention}_CALL(symref, float));
	    break;
	  case 'd' :
	    sv_setnv(sv, ${convention}_CALL(symref, double));
	    break;
	  case 'p' :
	    sv_setpv(sv, ${convention}_CALL(symref, char *));
	    break;
	  case 'P' :
	    sv_setpvn(sv, ${convention}_CALL(symref, char *),
		      atoi(&ret_type[1]));
	    break;
	  default :
	    croak("unsupported function return type: '%c'", *ret_type);
	  }
	  ST(0) = sv;
	  XSRETURN(1);
	}
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

    print FUNCS <<FUNCS;
/*
 * $cbfunc_c generated by $0.  Don't edit this file, edit $0.
 */
FUNCS
    #
    # The callback functions.
    #
    for $i (0 .. $num_callbacks - 1) {
	print FUNCS <<FUNCS;

static long
#ifdef I_STDARG
_cb_func$i(void * first, ...)
#else
_cb_func$i(first, va_alist)
void * first;
va_dcl
#endif
{
  va_list ap;
  long result;

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
    # Array of callback entry pointers.
    #
    print FUNCS "\nstatic const cb_callback cb_arr[DYNALIB_NUM_CALLBACKS] = {\n";
    for $i (0 .. $num_callbacks - 1) {
	print FUNCS "\t_cb_func$i,\n";
    }
    print FUNCS "};\n";
}
