# As the saying goes:
#
#   "Better to do it in Perl than C.
#    Better to do it in C than Assembler.
#    Better to do it in Assembler than V****l B***c."
#
package ExtUtils::DynaLib;

require 5.002;

=head1 NAME

ExtUtils::DynaLib - Perl extension for calling dynamically loaded C
functions

=head1 SYNOPSIS

  use ExtUtils::DynaLib;
  $lib = new ExtUtils::DynaLib( $linker_arg );

  $func = $lib->DeclareSub( $symbol_name
			[, $return_type [, @arg_types] ] );
  # or
  $func = $lib->DeclareSub( { "name"    => $symbol_name,
			["return" => $return_type,]
			["args"   => \@arg_types,]
			["decl"   => $decl,]
			} );
  $result = $func->( @args );

  use ExtUtils::DynaLib qw(DeclareSub);
  $func = DeclareSub( $function_pointer,
			[, $return_type [, @arg_types] ] );
  # or
  $func = DeclareSub( { "ptr" => $function_pointer,
			["return" => $return_type,]
			["args"   => \@arg_types,]
			["decl"   => $decl,]
			["libref" => $libref,]
			} );
  $result = $func->( @args );

  use ExtUtils::DynaLib qw(PTR_TYPE);
  $type = PTR_TYPE;  # see below

  $callback = new ExtUtils::DynaLib::Callback( \&my_sub,
			$return_type, @arg_types );
  $callback_pointer = $callback->Ptr();

=head1 DESCRIPTION

This module allows Perl programs to call C functions in dynamic
libraries.  Usually, the same effect may be achieved with greater
stability, portability, and robustness by a specialized XS module.
See L<perlxs(1)>.  This module is most useful for testing library
functions and writing simple programs without the bother of XS.

The mechanics of passing arguments and returning values,
unfortunately, depend on your machine, operating system, and compiler.
Therefore, Makefile.PL checks the Perl configuration and may even run
a test program before the module is built.

=head2 ExtUtils::DynaLib public constructor

The argument to C<new> may be the file name of a shared library.
Alternatively, a linker command-line argument (e.g., "-lc") may be
specified.  See L<DynaLoader(3)> for details on how such arguments are
mapped to file names.

=head2 Declaring a library routine

Before you can call a function in a shared library, you must specify
its name, the return type, and the number and types of arguments it
expects.  This is handled by C<DeclareSub>.

C<ExtUtils::DynaLib::DeclareSub> can be used as either an object
method or an ordinary sub.  You can pass its arguments either in a
list (what we call "positional parameters") or in a hash ("named
parameters").

The simplest way to use C<DeclareSub> is as a method with positional
parameters.  This form is illustrated in the first example above and
both examples below.  When used in this way, the first argument is a
library function name, the second is the function return type, and the
rest are function argument types.

C data types are specified using the codes used by Perl's C<pack> and
C<unpack> operators.  See L<perlfunc(1)>.  As a convenience (and to
hide system dependencies), C<PTR_TYPE> is defined as a code suitable
for pointer types (typically "i").

The arguments to C<DeclareSub> are as follows:

=over 4

=item C<name>

The name of a function exported by C<$lib>.  This argument is ignored
in the non-method forms of C<DeclareSub>.

=item C<ptr>

The address of the C function.  This argument is required in the
non-method forms of C<DeclareSub>.  Either it or the C<name> must be
specified in the method forms.

=item C<return>

The return type of the function, encoded for use with the C<pack>
operator.  Currently supported values are "" (void), "i" (int), "d"
(double), "p" (a NUL-terminated character string), and C<PTR_TYPE> (a
generic pointer type, different from "p" in that the pointer is not
dereferenced during unpacking).

=item C<args>

A list of the types of arguments expected by the function, specified
using the notation of Perl's C<pack> operator (see L<perlfunc(1)>).
For example, "i" means an integer, "d" means a double, "p" means a
NUL-terminated string pointer.  If you need to handle pointers to
things other than Perl scalars, use type C<PTR_TYPE>.

Note: you probably don't want to use "c" or "s" here, since C normally
converts the corresponding types (C<char> and C<short>) to C<int> when
passing them to a function.  The ExtUtils::DynaLib package may or may
not perform such conversions.  Use "i" instead.  Likewise, use "I" in
place of "C" or "S", and "d" in place of "f".  Stick with "i", "d",
"p", "P", and C<PTR_TYPE> unless you are sure of what you are doing.

=item C<decl>

Allows you to specify a function's calling convention.  This is
possible only with a named-parameter form of C<DeclareSub>.  See below
for information about the supported calling conventions.

=item C<libref>

A library reference obtained from either C<DynaLoader::dl_load_file>
or the C<ExtUtils::DynaLib::LibRef> method.  You must use a
named-parameter form of C<DeclareSub> in order to specify this
argument.

=back

=head2 Calling a declared function

The returned value of C<DeclareSub> is a code reference.  Calling
through it results in a call to the C function.  See L<perlref(1)> for
how to call subs using code references.

=head2 Using callback routines

Some C functions expect a pointer to another C function as an
argument.  The library code that receives the pointer may use it to
call an application function at a later time.  Such functions are
called callbacks.

This module allows you to use a Perl sub as a C callback, subject to
certain restrictions.  There is a hard-coded maximum number of
callbacks that can be active at any given time.  The default (4) may
be changed by specifying C<CALLBACKS=number> on the Makefile.PL
command line.

A callback's argument and return types are specified using C<pack>
codes, as described above for library functions.  Currently, the
return value must be interpretable as type C<int> or C<void>, so the
only valid codes are "i" and "".  The first argument must be of type
"i", "p", or C<PTR_TYPE>.  For argument positions beyond the first,
type "d" is allowed as well.  These limitations are considered bugs to
be fixed someday.

To enable a Perl sub to be used as a callback, you must construct an
object of class C<ExtUtils::DynaLib::Callback>.  The syntax is

  $cb_ref = new ExtUtils::DynaLib::Callback( \&some_sub,
                    $ret_type, @arg_types );

where C<$ret_type> and C<@arg_types> are the C<pack>-style types of
the function return value and arguments, respectively.  Calling
C<$cb_ref-E<gt>Ptr()> then returns a scalar whose integer value is the
function address.  C code that calls it will end up calling
C<&some_sub>.

=head1 EXAMPLES

This code loads and calls the math library function "sinh".  It
assumes that you have a dynamic version of the math library which will
be found by C<DynaLoader::dl_findfile("-lm")>.  If this doesn't work,
replace "-lm" with the name of your dynamic math library.

  use ExtUtils::DynaLib;
  $libm = new ExtUtils::DynaLib("-lm");
  $sinh = $libm->DeclareSub("sinh", "d", "d");
  print "The hyperbolic sine of 3 is ", &{$sinh}(3), "\n";
  # The hyperbolic sine of 3 is 10.0178749274099

The following example uses the C library's "strncmp" to compare the
first C<n> characters of two strings:

  use ExtUtils::DynaLib;
  $libc = new ExtUtils::DynaLib("-lc");
  $strncmp = $libc->DeclareSub("strncmp", "i", "p", "p", "i");
  $string1 = "foobar";
  $string2 = "foolish";
  $result = &{$strncmp}($string1, $string2, 3);  # $result is 0
  $result = &{$strncmp}($string1, $string2, 4);  # $result is -1

The files test.pl and README.win32 contain examples using callbacks.

=head1 CALLING CONVENTIONS

=head2 The problem

The hardest thing about writing this module is to accommodate the
different calling conventions used by different compilers, operating
systems, and CPU types.

"What's a calling convention?" you may be wondering.  It is how
compiler-generated C functions receive their arguments from and make
their return values known to the code that calls them, at the level of
machine instructions and registers.  Each machine has a set of rules
for this.  Compilers and operating systems may use variations even on
the same machine type.  In some cases, it is necessary to support more
than one calling convention on the same system.

"But that's all handled by the compiler!" you might object.  True
enough, if the calling code knows the signature of the called function
at compile time.  For example, consider this C code:

  int foo(double bar, const char *baz);
  ...
  int res;
  res = foo(sqrt(2.0), "hi");

A compiler will generate specific instruction sequences to load the
return value from C<sqrt()> and a pointer to the string C<"hi"> into
whatever registers or memory locations C<foo()> expects to receive
them in, based on its calling convention and the types C<double> and
C<char *>.  Another specific instruction sequence stores the return
value in the variable C<res>.

But when you compile the C code in this module, it must be general
enough to handle all sorts of function argument and return types.

"Why not use varargs/stdarg?"  Most C compilers support a special set
of macros that allow a function to receive a variable number of
arguments of variable type.  When the function receiving the arguments
is compiled, it does not know with what argument types it will be
called.

But the code that I<calls> such a function I<does> know at compile
time how many and what type of arguments it is passing to the varargs
function.  There is no "reverse stdarg" standard for passing types to
be determined at run time.  You can't simply pass a C<va_list> to a
function unless that function is defined to receive a C<va_list>.
This module uses varargs/stdarg where appropriate, but the only
appropriate place is in the callback support.

=head2 The solution (well sort of)

Having failed to find a magic bullet to spare us from the whims of
system designers and compiler writers, we are forced to examine the
calling conventions in common use and try to put together some "glue"
code that stands a chance of being portable.  Honestly, this work has
just barely begun.

In writing glue code (that which allows code written in one language
to call code in another), an important issue is reliability.  If we
don't get the convention just right, chances are we will get a core
dump (protection fault or illegal instruction).  To write really solid
Perl-to-C glue, we would have to use assembly language and have
detailed knowledge of each calling convention.  Compiler source code
can be helpful in this regard, and if your compiler can output
assembly code, that helps, too.

However, this is Perl, Perl is meant to be ported, and assembly
language is often not portable.  This module generally uses C
constructs that happen to work most of the time, as opposed to
assembly code that follows the conventions faithfully.  I expect the
use of assembly language to increase, however.

By minimizing the use of assembly, we lose some reliability and
flexibility.  By loss of reliability, I mean we can expect crashes,
especially on untested platforms.  Lost flexibility means having
restrictions on what parameter types and return types are allowed.

The code for all conventions other than C<hack30> (described below)
relies on the C C<alloca()> function.  Unfortunately, C<alloca()>
itself is not standard, so its use introduces new portability
concerns.  For C<cdecl>, the most general convention, Makefile.PL
creates and runs a test program to try to ferret out any compiler
peculiarities regarding C<alloca()>.  If the test program fails, the
default choice becomes C<hack30>.

=head2 Supported conventions

ExtUtils::DynaLib currently supports the parameter-passing conventions
listed below.  The module can be compiled with support for one or more
of them by specifying (for example) C<DECL=cdecl> on Makefile.PL's
command-line.  If none are given, Makefile.PL will try to choose based
on your Perl configuration and/or the results of running a test
program.

At run time, a calling convention may be specified using a
named-parameter form of C<DeclareSub> (described above), or a default
may be used.  The first C<DECL=...> supplied to Makefile.PL will be
the default convention.

Note that the convention must match that of the function in the
dynamic library, otherwise crashes are likely to occur.

=over 4

=item C<cdecl>

All arguments are placed on the stack in reverse order from how the
function is invoked.  This seems to be the default for Intel-based
machines and possibly others.

=item C<sparc>

The first 6 machine words of arguments are cast to an array of six
C<int>s.  The remaining args (and possibly piece of an arg) are placed
on the stack.  Then the C function is called as if it expected six
integer arguments.  On a Sparc, the six "pseudo-arguments" are passed
in special registers.

=item C<alpha>

This is similar to the C<sparc> convention, but the pseudo-arguments
have type C<long> instead of C<int>, and all arguments are extended to
8 bytes before being placed in the array.  On the Alpha, a special
sequence of inline assembly instructions is used to ensure that any
function parameters of type C<double> are passed correctly.
Currently, this code works only with the GNU C Compiler, so passing
doubles with other compilers is unsupported.

=item C<hack30>

This is not really a calling convention, it's just some C code that
will successfully call a function most of the time on a variety of
systems.  All arguments are copied into an array of 6 long integers
(or 30 if 6 is not enough).  The function is called as if it expected
6 (or 30) long arguments.

You will run into problems if the C function either (1) takes more
arguments than can fit in the array, (2) takes some non-long arguments
on a system that passes them differently from longs (but C<cdecl>
currently has the same flaw), or (3) cares if it is passed extra
arguments (this is apparently what crashes certain Win32 functions
including C<RegisterClassA()>, which is used in the demo program in
the README.win32 file).

Because of these problems, the use of C<hack30> is recommended only as
a quick fix until your system's calling convention is supported.

=back

=head1 BUGS

Several unresolved issues surround this module.

=head2 Portability

The "glue" code that allows Perl values to be passed as arguments to C
functions is architecture-dependent.  This is because the author knows
of no standard means of determining a system's parameter-passing
conventions or passing arguments to a C function whose signature is
not known at compile time.

Although some effort is made in Makefile.PL to find out how parameters
are passed in C, this applies only to the integer type (Perl's C<I32>,
to be precise; see L<perlguts(1)>).  Functions that recieve or return
type C<double>, for example, may not work on systems that use
floating-point registers for this purpose.

=head2 Robustness

Usually, Perl programs run under the control of the Perl interpreter.
Perl is extremely stable and can almost guarantee an environment free
of the problems of C, such as bad pointers causing memory access
violations.  Some Perl modules use a Perl feature called "XSubs" to
call C code directly from a Perl program.  In such cases, a crash may
occur if the C or XS code is faulty.  However, once the XS module has
been sufficiently debugged, one can be reasonably sure that it will
work right.

C code called through this module lacks this protection.  Since the
association between Perl and C is made at run time, errors due to
incompatible library interfaces or incorrect assumptions have a much
greater chance of causing a crash than with either core or XS code.

=head2 Security

This section is incomplete.  I don't know what the security
implications of this module may be.  Use at your own risk.

=head2 Deallocation of Resources

To maximize portability, this module uses the DynaLoader interface to
shared library linking.  DynaLoader's main purpose is to support XS
modules, which are loaded once by a program and not (to my knowledge)
unloaded.  It would be nice to be able to free the libraries loaded by
this module when they are no longer needed.  This is impossible, since
DynaLoader currently provides no means to do so.

=head2 Literal and temporary strings

Before Perl 5.00402, it was impossible to pass a string literal as a
pointer-to-nul-terminated-string argument of a C function.  For
example, the following statement (incorrectly) produced the error
"Modification of a read-only value attempted":

  &$strncmp("foo", "bar", 3);

To work around this problem, one must assign the value to a variable
and pass the variable in its place, as in

  &$strncmp($dummy1 = "foo", $dummy2 = "bar", 3);

=head2 Callbacks

The Callback code uses global static data.  Callbacks can mess up the
message produced by C<die> in the presence of nested C<eval>s.

=head2 Miscellaneous

There are far too many restrictions on what C data types may be used.
Using argument types with size not a multiple of the machine stack
width may have nasty results.  The techniques used to pass values to
and from C functions are all rather hackish and nonstandard.  Assembly
code would be more complete.

=head1 TODO

Fix the bugs (see above).  Fiddle with autoloading so we don't have to
call DeclareSub all the time.  Mangle C++ symbol names.  Get Perl to
understand C header files (macros and function declarations).

=head1 LICENSE

Copyright (c) 1997 by John Tobey.  This package is distributed under
the same license as Perl itself.  There is no expressed or implied
warranty, since it is free software.  See the file README in the top
level Perl source directory for details.  The Perl source may be found
at

  http://www.perl.com/CPAN/src/

=head1 AUTHOR

John Tobey, jtobey@user1.channel1.com

=head1 SEE ALSO

perl(1), perlfunc(1) (for C<pack>), perlref(1), DynaLoader(3),
perlxs(1), perlcall(1).

=cut


#'

use strict;
no strict 'refs';
use Carp;
use vars qw($VERSION @ISA $AUTOLOAD @EXPORT @EXPORT_OK $DefConv);
use subs qw(AUTOLOAD new LibRef DeclareSub DYNALIB_DEFAULT_CONV PTR_TYPE);

@EXPORT = ();
@EXPORT_OK = qw(Poke DeclareSub PTR_TYPE);

require DynaLoader;
require Exporter;

@ISA = qw(DynaLoader Exporter);
$VERSION = '0.31';
bootstrap ExtUtils::DynaLib $VERSION, \$ExtUtils::DynaLib::Callback::Config;


sub AUTOLOAD {
  my $constname;
  ($constname = $AUTOLOAD) =~ s/.*:://;
  my $val = constant($constname);
  $! and croak "Undefined subroutine &$AUTOLOAD called";
  eval "sub $AUTOLOAD { '$val' }";
  goto &$AUTOLOAD;
}

$DefConv = DYNALIB_DEFAULT_CONV;

# Cache of loaded lib refs.  Maybe best left to DynaLoader?
my %loaded_libs = ();

my %suffix_map = (
	''		=> '_void_call_packed',
	'void'		=> '_void_call_packed',
	'i'		=> '_int_call_packed',
	'int'		=> '_int_call_packed',
	'd'		=> '_double_call_packed',
	'double'	=> '_double_call_packed',
	'p'		=> '_string_call_packed',
	'string'	=> '_string_call_packed',
);
if (defined (&{DYNALIB_DEFAULT_CONV . '_quad_call_packed'})) {
  $suffix_map{'q'} = '_quad_call_packed';
}
# the use of 'ptr' is deprecated.
$suffix_map{'ptr'} = $suffix_map{PTR_TYPE()};

sub new {
    my $class = shift;
    scalar(@_) == 1
	or croak 'Usage: $lib = new ExtUtils::DynaLib "-lc" (for example)';
    my ($libname) = @_;
    return $loaded_libs{$libname} if exists($loaded_libs{$libname});
    my $so = $libname;
    -e $so or $so = DynaLoader::dl_findfile($libname) || $libname;
    my $lib = DynaLoader::dl_load_file($so)
	or croak DynaLoader::dl_error();
    return $loaded_libs{$libname} = bless \$lib, $class;
}

sub LibRef {
    ${$_[0]};
}

sub DeclareSub {
    local ($@);  # We eval $obj->isa and $obj->can for 5.003 compatibility.
    my $self = shift;

    # Calling as a method is equivalent to supplying the "libref"
    # named arg.
    my $is_method;
    $is_method = ref($self) && eval { $self->isa("ExtUtils::DynaLib") };
    $@ and $is_method = (ref($self) eq 'ExtUtils::DynaLib');
    my $first = ($is_method ? shift : $self);

    my ($libref, $name, $ptr, $convention, $ret_type, @arg_type);
    if (ref($first) eq 'HASH') {
	# Using named parameters.
	! @_ && (($ptr = $first->{ptr}) || defined($name = $first->{name}))
	    or croak 'Usage: $lib->DeclareSub({ "name" => $func_name [, "return" => $ret_type] [, "args" => \@arg_types] [, "decl" => $decl] })';
	$convention = $first->{decl} || $DefConv;
	$ret_type = $first->{'return'} || 'i';
	@arg_type = @{ $first->{args} || [] };
	$libref = $first->{'libref'};
    } else {
	# Using positional parameters.
	($is_method ? $name : $ptr) = $first
	    or croak 'Usage: $lib->DeclareSub( $func_name [, $return_type [, \@arg_types]] )';
	$convention = $DefConv;
	$ret_type = shift || 'i';
	@arg_type = @_;
    }
    unless ($ptr) {
	$libref ||= $is_method && $self->LibRef()
	    or croak 'ExtUtils::DynaLib::DeclareSub: non-method form requires a "ptr" or "libref"';
	$ptr = DynaLoader::dl_find_symbol($libref, $name)
	    or croak "Can't find symbol \"$name\": ", DynaLoader::dl_error();
    }

    my $glue_sub_suffix = $suffix_map{$ret_type}
	or confess "Unsupported function return type: \"$ret_type\"";
    my $glue_sub_name = $convention . $glue_sub_suffix;

    my $glue_sub = ($is_method && eval { $self->can($glue_sub_name) })
	|| (defined(&{"$glue_sub_name"}) && \&{"$glue_sub_name"})
      or croak "Unsupported calling convention: \"$convention\"";

    return sub {
	&{$glue_sub}($ptr, \@arg_type, map { pack($_, shift) } @arg_type);
    };
}

package ExtUtils::DynaLib::Callback;

use strict;
use Carp;
use vars qw($Config $CONFIG_TEMPLATE $empty);
use subs qw(new Ptr DESTROY);

$CONFIG_TEMPLATE =
  ExtUtils::DynaLib::PTR_TYPE . "pp" . ExtUtils::DynaLib::PTR_TYPE;
$empty = "";

sub new {
    my $class = shift;
    my $self = [];
    my ($index, $coderef);
    my ($codeptr, $ret_type, $arg_type, @arg_type, $func);
    for ($index = 0; $index <= $#{$Config}; $index++) {
	($codeptr, $ret_type, $arg_type, $func)
	    = unpack($CONFIG_TEMPLATE, $Config->[$index]);
	last unless $codeptr;
    }
    if ($index > $#{$Config}) {
	croak "Limit of ", scalar(@$Config), " callbacks exceeded";
    }
    ($coderef, $ret_type, @arg_type) = @_;
    unshift @$self, $coderef;
    if (ref($coderef) eq 'CODE') {
	"$coderef" =~ /\(0x([\da-f]+)\)/;
	$codeptr = hex($1);
    } else {
	\$self->[0] =~ /\(0x([\da-f]+)\)/;
	$codeptr = hex($1);
    }
    $arg_type = join('', @arg_type);
    unshift @$self, $codeptr, $ret_type, $arg_type, $func, $index;
    $Config->[$index] = pack($CONFIG_TEMPLATE, @$self);
    return bless $self, $class;
}

sub Ptr {
    $_[0]->[3];
}

sub DESTROY {
    my $self = shift;
    my ($codeptr, $ret_type, $arg_type, $func, $index)
	= @$self;
    $Config->[$index] = pack($CONFIG_TEMPLATE, 0, $empty, $empty, $func);
}

package ExtUtils::DynaLib;
1;
__END__
