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
  $func = DeclareSub( $function_pointer,
			[, $return_type [, @arg_types] ] );
  $func = $lib->DeclareSub( { "name"    => $symbol_name,
			["return" => $return_type,]
			["args"   => \@arg_types,]
			["decl"   => $decl,]
			} );
  $func = DeclareSub( { "ptr" => $function_pointer,
			["return" => $return_type,]
			["args"   => \@arg_types,]
			["decl"   => $decl,]
			["libref" => $libref,]
			} );
  $result = $func->( @args );

  $callback = new ExtUtils::DynaLib::Callback( \&my_sub,
			$return_type, @arg_types );
  $callback_pointer = $callback->Ptr();

=head1 DESCRIPTION

This module allows Perl programs to link with dynamic libraries and
call their functions on the fly.

The mechanics of passing arguments and returning values,
unfortunately, depend on your machine, operating system, and compiler.
Therefore, Makefile.PL checks the Perl configuration to verify that
your architecture is supported.

=head2 ExtUtils::DynaLib public constructor

The argument to C<new> may be the file name of a shared library.
Alternatively, a linker command-line argument (e.g., "-lc") may be
specified.  See DynaLoader(3) for details on how such arguments are
mapped to file names.

=head2 Declaring a library routine

Before you can call a function in a shared library, you must specify
its name, the return type, and the number and types of arguments it
expects.  This is handled by C<DeclareSub>.

C<ExtUtils::DynaLib::DeclareSub> can be used as either an object
method or an ordinary sub.  You can pass its arguments either in a
list (what we call "positional arguments") or in a hash ("named
arguments").

The simplest way to use C<DeclareSub> is as a method with positional
arguments.  This form is illustrated in the first example above and
both examples below.  When used in this way, the first argument is a
library function name, the second is the function return type, and the
rest are function argument types.

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
(double), "p" (a NUL-terminated character string), and "ptr" (any
pointer type, usually equivalent to "i"; this is not a C<pack> code
because there isn't one for generic pointers that aren't
dereferenced).

=item C<args>

A list of the types of arguments expected by the function, specified
using the notation of Perl's C<pack> operator (see perlfunc(1)).  For
example, "i" means an integer, "d" means a double, "p" means a
NUL-terminated string pointer.

Note: you probably don't want to use "c" or "s" here, since C normally
converts the corresponding types (C<char> and C<short>) to C<int> when
passing them to a function.  The ExtUtils::DynaLib package does not
perform such conversions.  Use "i" instead.  Likewise, use "I" in
place of "C" or "S".

=item C<decl>

Allows you to specify a function's calling convention.  This is
possible only with a named-argument form of C<DeclareSub>.  See below
for information about the supported calling conventions.

=item C<libref>

A library reference obtained from either C<DynaLoader::dl_load_file>
or the C<ExtUtils::DynaLib::LibRef> method.  You must use a
named-argument form of C<DeclareSub> in order to specify this
argument.

=back

=head2 Calling a declared function

The return value of C<DeclareSub> is a code reference.  Calling
through it results in a call to the C function.  See perlref(1) for
how to call subs using code references.

=head2 Using callback routines

Some C functions expect a pointer to another C function as an
argument.  The library code that receives the pointer may use it to
call an application function at a later time.  Such functions are
called callbacks.

This module allows you to use a perl sub as a C callback, subject to
certain restrictions.  There is a hard-coded maximum number of
callbacks that can be active at any given time.  The default (4) may
be changed by specifying `CALLBACKS=number' as an argument to
Makefile.PL.

A callback's argument and return types are specified using C<pack>
codes, as described above for library functions.  Currently, the
return value and first argument must be interpretable as type C<int>
or C<void>, so the only valid codes are "i" and "".  (On machines for
which integers are the same size as pointers, "p" is allowed as a
first argument type.)  For argument positions beyond the first, the
permissible types are "i", "p", and "d".

To enable a Perl sub to be used as a callback, you must construct an
object of class ExtUtils::DynaLib::Callback.  The syntax is

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
replace "-lm" with the name of your math library.

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

The file test.pl contains examples of using a callback.

=head1 CALLING CONVENTIONS

ExtUtils::DynaLib currently supports the argument-passing conventions
shown below.  The module can be compiled with support for one or more
of them by specifying (for example) `DECL=cdecl' on Makefile.PL's
command-line.  If none are given, Makefile.PL will try to choose based
on your Perl configuration and give up if it can't guess.

At run time, a calling convention may be specified using a
named-argument form of C<DeclareSub> (described above), or a default
may be used.  The first `DECL=...' will be the default.

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
will successfully call a function most of the time on most systems
tested so far.  It is not especially efficient or elegant.  There is a
limit of 30 int-size arguments per function call (whence the name).
Passing non-int-size arguments may be risky.  Use it as a last resort.

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
the association between Perl and C is made at run time, errors due to
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
is impossible, since DynaLoader currently provides no means to do so.

=head2 Literal and temporary strings

Under Perl 5.004, it is impossible to pass a string literal as a
pointer-to-nul-terminated-string argument of a C function.  For
example, the following statement (incorrectly) produces the error
"Modification of a read-only value attempted":

  $strncmp->("foo", "bar", 3);

To work around this problem, one must assign the value to a variable
and pass the variable in its place, as in

  $strncmp->($dummy1 = "foo", $dummy2 = "bar", 3);

This is related to the fact that Perl can not handle
C<pack("p", "foo")>.  See the file test.pl for a patch to correct this
behavior in the Perl source; I'm too lazy to work around it in this
package.

=head2 Callbacks

The Callback code is non-reentrant (not thread-safe).  And it assumes
that pointers are C<pack>able as "I".  Callbacks can mess up the
message printed by C<die> in the presence of nested C<eval>s.

=head2 Miscellaneous

There are too many restrictions on what C data types may be used.  The
techniques used to pass values to and from C functions are all very
hackish and not officially sanctioned.

=head1 TODO

Fiddle with autoloading so we don't have to call DeclareSub all the
time.  Mangle C++ function names.  Get Perl to understand C header
files.

=head1 COPYING

Copyright 1997 by John Tobey.  This package is distributed under the
same license as Perl itself.  There is no expressed or implied
warranty, since it is free software.  See the file README in the top
level Perl source directory for details.

=head1 AUTHOR

John Tobey, jtobey@user1.channel1.com

=head1 SEE ALSO

perlfunc(1) (for C<pack>), perlref(1), DynaLoader(3), perlxs(1),
perlcall(1).

=cut


use strict;
use Carp;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK $DefConv);
use subs qw(new LibRef DeclareSub);

require DynaLoader;
require Exporter;

@ISA = qw(DynaLoader Exporter);
$VERSION = '0.22';

@EXPORT = ();
@EXPORT_OK = qw(Poke DeclareSub);
bootstrap ExtUtils::DynaLib $VERSION, \$ExtUtils::DynaLib::Callback::config;
$DefConv = default_convention();

# Cache of loaded lib refs.  Maybe best left to DynaLoader?
my %loaded_libs = ();

sub new {
    my $class = shift;
    scalar(@_) == 1
	or croak "Usage: \$lib = new ExtUtils::DynaLib \"-lc\" (for example)";
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
	# Using named arguments.
	! @_ && (($ptr = $first->{ptr}) || ($name = $first->{name}))
	    or croak 'Usage: $lib->DeclareSub({ "name" => $func_name [, "return" => $ret_type] [, "args" => \@arg_types] [, "decl" => $decl] })';
	$convention = $first->{decl} || $DefConv;
	$ret_type = $first->{'return'} || 'i';
	@arg_type = ($first->{args} ? @{$first->{args}} : ());
	$libref = $first->{'libref'};
    } else {
	# Using positional arguments.
	($is_method ? $name : $ptr) = $first
	    or croak 'Usage: $lib->DeclareSub( $func_name [, $return_type [, \@arg_types]] )';
	$convention = $DefConv;
	$ret_type = shift || 'i';
	@arg_type = @_;
    }
    unless ($ptr) {
	$libref ||= $self->LibRef()
	    if $is_method;
	$libref
	    or croak 'ExtUtils::DynaLib::DeclareSub: non-method form requires a "ptr" or "libref"';
	$ptr = DynaLoader::dl_find_symbol($libref, $name)
	    or croak "Can't find symbol \"$name\": ", DynaLoader::dl_error();
    }

    my $glue_sub_suffix = {
	""		=> "_void_call_packed",
	"void"		=> "_void_call_packed",
	"i"		=> "_int_call_packed",
	"int"		=> "_int_call_packed",
	"d"		=> "_double_call_packed",
	"double"	=> "_double_call_packed",
	"p"		=> "_string_call_packed",
	"string"	=> "_string_call_packed",
	"ptr"		=> "_ptr_call_packed",
    }->{$ret_type}
	or confess "Unsupported function return type: \"$ret_type\"";
    my $glue_sub_name = $convention . $glue_sub_suffix;

    my $glue_sub = $is_method && eval { $self->can($glue_sub_name) }
	|| (defined(&{"$glue_sub_name"}) ? \&{"$glue_sub_name"} : undef)
      or croak "Unsupported calling convention: \"$convention\"";

    return sub {
	&{$glue_sub}($ptr, map { pack($_, shift) } @arg_type);
    };
}

package ExtUtils::DynaLib::Callback;

use strict;
use Carp;
use vars qw($config $empty);
use subs qw(new Ptr DESTROY);

$empty = "";

sub new {
    my $class = shift;
    my $self = [];
    my ($index, $coderef);
    my ($codeptr, $ret_type, $arg_type, @arg_type, $func);
    for ($index = 0; $index <= $#{$config}; $index++) {
	($codeptr, $ret_type, $arg_type, $func)
	    = unpack("IppI", $config->[$index]);
	last unless $codeptr;
    }
    if ($index > $#{$config}) {
	croak "Limit of ", scalar(@$config), " callbacks exceeded";
    }
    ($coderef, $ret_type, @arg_type) = @_;
    if (ref($coderef) eq 'CODE') {
	"$coderef" =~ /\(0x([\da-f]+)\)/;
	$codeptr = hex($1);
    } else {
	unshift @$self, $coderef;
	\$self->[0] =~ /\(0x([\da-f]+)\)/;
	$codeptr = hex($1);
    }
    $arg_type = join('', @arg_type);
    unshift @$self, $codeptr, $ret_type, $arg_type, $func, $index;
    $config->[$index] = pack("IppI", @$self);
    return bless $self, $class;
}

sub Ptr {
    $_[0]->[3];
}

sub DESTROY {
    my $self = shift;
    my ($codeptr, $ret_type, $arg_type, $func, $index)
	= @$self;
    $codeptr = 0;
    $config->[$index] = pack("IppI", $codeptr, $empty, $empty, $func);
}

1;
