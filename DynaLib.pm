# As the saying goes:
#
#   "Better to do it in Perl than C.
#    Better to do it in C than Assembler.
#    Better to do it in Assembler than V****l B***c."
#
package ExtUtils::DynaLib;

require 5.003;  # maybe it'll work with 5.002, haven't tried.

=head1 NAME

ExtUtils::DynaLib - Perl extension for executing dynamically loaded C functions

=head1 SYNOPSIS

  use ExtUtils::DynaLib;
  $lib = new ExtUtils::DynaLib( $linker_arg );

  $func = $lib->declare_sub( $symbol_name
			     [, $return_type [, @arg_types] ] );
  $func = $lib->declare_sub( { "name"    => $symbol_name,
				["return" => $return_type,]
				["decl"   => $decl,]
				["args"   => \@arg_types,]
			      } );
  $func = ExtUtils::DynaLib::declare_sub( { "ptr" => $symbol_pointer,
				["return" => $return_type,]
				["decl"   => $decl,]
				["args"   => \@arg_types,]
			      } );

  $result = $func->( @args );

=head1 DESCRIPTION

This module allows perl programs to link with dynamic libraries and
execute functions in them on the fly.

The mechanics of passing arguments and returning values are,
unfortunately, highly machine-and-OS-dependent.  Therefore,
Makefile.PL checks the perl configuration to verify that your
architecture is supported.

Currently, this module has been tested only on i586 Linux, FreeBSD,
Sun4 Solaris and SunOS.  It is expected to work on most Intel and many
other platforms (at least with GNU CC), but the author won't change
Makefile.PL to accept them until he has confirmation.

=head2 Public constructor

The argument to C<new> may be the file name of a shared library.
Alternatively, a linker command-line argument (e.g., "-lc" for the C
library) may be specified.  See DynaLoader(3) for details on how such
arguments are mapped to file names.

=head2 Declaring a library routine

Before you can call a function in a shared library, you must specify
its name, the return type, and the number and types of arguments it
expects.  This is handled by C<declare_sub>.

C<ExtUtils::DynaLib::declare_sub> has three forms.  The first form
takes its arguments in a list; the others take them in a hash.  Most
of the time, you will use the first form.  The first form is quickest
to write.  The second and third are more general.  The first and
second are object methods.  The third form is used as an ordinary sub.

The arguments to C<ExtUtils::DynaLib::declare_sub> are as follows:

=over 4

=item C<name>

The name of a function exported by C<$lib>.  This argument is required
in the first (list) form of C<ExtUtils::DynaLib::declare_sub>.  It is
ignored in the third (non-method) form.

=item C<return>

The return type of the function.  Currently supported values are
"void", "int", "double", "string" (a NUL-terminated character string),
and "ptr" (any pointer type, usually equivalent to "int").  The
default is "int".

=item C<args>

A list of the types of arguments expected by the function.  Unlike the
return type, these are specified using the notation of Perl's C<pack>
operator.  For example, "i" means an integer, "d" means a double, "p"
means a NUL-terminated string pointer.

Note: you probably don't want to use "c" or "s" here, since C normally
converts the corresponding types (C<char> and C<short>) to C<int> when
passing them to a function.  This module does not perform such
conversions.  Use "i" instead.  Likewise, use "I" in place of "C" or
"S".

=item C<ptr>

The address of the C function.  This argument can only be specified
using a long form of C<ExtUtils::DynaLib::declare_sub>, i.e. the
second or third form.  This argument is required in the third form,
and either it or the C<func> must be specified in the second form.

=item C<decl>

Allows you to specify a function's calling convention.  This is
possible only with a long form of C<declare_sub>.  See below for
information about the supported calling conventions.

=back

=head2 Return Value

The return value of C<declare_sub> is a code reference.  The C
function can be invoked with arguments by using either the old
(C<&{$func}(@args)>) or the new (C<$func-E<gt>(@args)>) syntax.

=head1 EXAMPLES

This code loads and calls the math library function "sinh".  It
assumes that you have a dynamic version of the math library which will
be found by C<DynaLoader::dl_findfile("-lm")>.  If this is not the case,
replace "-lm" with the name of your math library.

  use ExtUtils::DynaLib;
  $libm = new ExtUtils::DynaLib("-lm");
  $sinh = $libm->declare_sub("sinh", "double", "d");
  print "The hyperbolic sine of 3 is ", &{$sinh}(3), "\n";
  # The hyperbolic sine of 3 is 10.0178749274099

The following example uses the C library's "strncmp" to compare the
first C<n> characters of two strings:

  use ExtUtils::DynaLib;
  $libc = new ExtUtils::DynaLib("-lc");
  $strncmp = $libc->declare_sub("strncmp", "int", "p", "p", "i");
  $string1 = "foobar";
  $string2 = "foolish";
  $result = &{$strncmp}($string1, $string2, 3);  # $result is 0
  $result = &{$strncmp}($string1, $string2, 4);  # $result is -1

=head1 CALLING CONVENTIONS

ExtUtils::DynaLib currently supports the argument-passing conventions
shown below.  The module can be compiled with support for one or more
of them by specifying (for example) `DECL=cdecl' on Makefile.PL's
command-line.  If none are given, Makefile.PL will try to choose based
on your perl configuration, and give up if it can't guess.

At runtime, a calling convention may be specified using a "long form"
of C<ExtUtils::DynaLib::declare_sub> (described above), or a default
may be used.  The first `DECL=...' will provide the default.

Note that the convention must match that of the function in the
dynamic library, otherwise crashes are likely to occur.

=over 4

=item cdecl

All arguments are placed on the stack in reverse order from how the
function is invoked.  This seems to be the default for Intel-based
machines and possibly others.

=item sparc

The first 24 bytes of arguments are cast to an array of six C<int>s.
The remaining args (and possibly piece of an arg) are placed on the
stack.  Then the C function is called as if it expected six integer
arguments.  On a Sparc, the six "pseudo-arguments" are passed in
special registers.

=item hack30

This is not really a calling convention, it's just some C code that
will successfully call a function most of the time on all systems
tested so far.  It is not especially efficient or elegant.  There is a
limit of 30 int-size arguments per function call (whence the name).
Passing non-int arguments (especially doubles) may be risky.  Use it
as a last resort.

=back

=head1 BUGS

Several unresolved issues surround this module.

=head2 Portability

The "glue" code that allows Perl values to be passed as arguments to C
functions is architecture-dependent.  This is because the author knows
of no standard means of determining a system's parameter-passing
conventions or passing arguments to a C function whose signature is
not known at compile time.

Because of this problem, we've tried to separate out the code
associated with a particular calling format.  We hope that support for
more formats will be added in this way.  However, we expect this to
remain a tricky problem.

=head2 Robustness

Usually, Perl programs run under the control of the Perl interpreter.
Perl is extremely stable and can almost guarantee an environment free
of the problems of C, such as bad pointers causing memory access
violations.  Some Perl modules use a Perl feature called "XSubs" to
call C code directly from a Perl program.  In such cases, a crash may
occur if the C or XS code is faulty.  However, once the XS module has
been sufficiently debugged, one can be reasonably sure that it will
work right.

C code called through this module is devoid of such protection.  Since
the association between Perl and C is made at runtime, errors due to
incompatible library interfaces or incorrect assumptions have a much
greater chance of causing a crash than with either static or XS code.

=head2 Security

This section is incomplete.  I don't know what the security
implications of this module may be.  Use at your own risk.

=head2 Deallocation of Resources

To maximize portability, this module uses the DynaLoader(3) interface
to shared library linking.  DynaLoader's main purpose is to support XS
modules, which are loaded once by a program and not (to the author's
knowledge) unloaded.  It would be nice to be able to free the
libraries loaded by this module when they are no longer needed.  This
is currently impossible, since DynaLoader currently provides no means
to do so.

=head2 Literal strings

Under Perl 5.004, it is impossible to pass a string literal as a
pointer-to-nul-terminated-string argument of a C function.  For
example, the following statement (incorrectly) produces the error
"Modification of a read-only value attempted":

  $strncmp->("foo", $string, 3);

To work around this problem, one must assign the value to a variable
and pass the variable in its place, as in

  $strncmp->($dummy = "foo", $string, 3);

This is due to the fact that Perl can not handle C<pack("p", "foo")>.
See the file "test.pl" for a patch to correct this behavior.

=head2 Miscellaneous

Using the C<pack> codes for arguments and a different syntax for
return types may be confusing.  Only finitely many types can be
returned.

=head1 TO DO

Port, test, refine.

Write a Callback class that takes a code reference and returns a C
function pointer to be passed to library code that uses callbacks.

=head1 COPYING

This package is distributed under the same license as Perl itself.
There is ABSOLUTELY NO WARRANTY.  See the file "README" in the top
level Perl source directory for details.

=head1 AUTHOR

John Tobey, jtobey@user1.channel1.com

=head1 SEE ALSO

perlfunc(1) (for C<pack>), perlref(1), DynaLoader(3), perlxs(1).

=cut


use strict 'vars';
use Carp;
use vars qw($VERSION @ISA);
use subs qw(new libref declare_sub);

require DynaLoader;

@ISA = qw(DynaLoader);
$VERSION = '0.14';

bootstrap ExtUtils::DynaLib $VERSION;

# Cache of loaded libs.  Maybe best left to DynaLoader?
my %loaded_libs = ();

# Preloaded methods go here.

sub new {
    my $class = shift;
    scalar(@_) == 1
	or croak "Usage: \$lib = new ExtUtils::DynaLib \"-lc\" (for example)\n";
    my ($libname) = @_;
    return $loaded_libs{$libname} if exists($loaded_libs{$libname});
    my $so = $libname;
    -e $so or $so = DynaLoader::dl_findfile($libname);
    my $lib = DynaLoader::dl_load_file($so)
	or croak DynaLoader::dl_error();
    return $loaded_libs{$libname} = bless \$lib, $class;
}

sub libref {
    ${$_[0]};
}

sub declare_sub {
    my $self = shift;
    my $is_method = eval { $self->isa("ExtUtils::DynaLib") };
    $@ and $is_method = (ref($self) eq 'ExtUtils::DynaLib');
    my $first = ($is_method ? shift : $self);
    my ($func, $ptr, $convention, $ret_type, @arg_types);
    if (ref($first) eq 'HASH') {
	$ptr = $first->{ptr} or
	    defined($func = $first->{name})
	or croak 'Usage: $lib->declare_sub({ "name" => $func_name [, "return" => "void"|"int"|"double"|"string"|"ptr"] [, "args" => \@arg_types] [, "decl" => $decl] })', "\n";
	$convention = $first->{decl} || '';
	$ret_type = $first->{return} || 'int';
	@arg_types = ($first->{args} ? @{$first->{args}} : ());
    } else {
	$func = $first
	    or croak 'Usage: $lib->declare_sub( $func_name [, $return_type [, \@arg_types]] )', "\n";
	$convention = '';
	$ret_type = shift || 'int';
	@arg_types = @_;
    }
    unless ($ptr) {
	$is_method
	    or croak "ExtUtils::DynaLib::declare_sub: Method invoked on non-ExtUtils::DynaLib object";
	$ptr = DynaLoader::dl_find_symbol($self->libref(), $func)
	    or croak "Can't find \"$func\": ", DynaLoader::dl_error();
    }

    my $glue_func = {
	"void"		=> \&{"${convention}_void_call_packed"},
	"int"		=> \&{"${convention}_int_call_packed"},
	"double"	=> \&{"${convention}_double_call_packed"},
	"string"	=> \&{"${convention}_string_call_packed"},
	"ptr"		=> \&{"${convention}_ptr_call_packed"},
    }->{$ret_type}
	or confess "Unsupported function return type: \"$ret_type\"";

    my @packed_args = ();
    my $i;
    for $i (0 .. $#arg_types) {
	push @packed_args, sub { pack($arg_types[$i], $_[$i]) };
    }

    return sub {
	&{$glue_func}($ptr, map { &$_ } @packed_args);
    };
}

# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__
