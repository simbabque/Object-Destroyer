package Object::Destroyer;

# See POD at end for details

use 5.005;
use strict;
use UNIVERSAL    ();
use Carp         ();
use Scalar::Util ();

use vars qw{$VERSION};
BEGIN {
	$VERSION = '1.02';
}

sub new {
	if ( ref $_[0] ) {
		# This is a method called on an existing
		# Destroyer, and should actually be passed through
		# to the encased object via the AUTOLOAD
		$Object::Destroyer::AUTOLOAD = ref(${$_[0]}) . '::new';
		goto &AUTOLOAD;
	}

	# *ahem*... where were we...
	my $destroyer = shift;
	my $class = Scalar::Util::blessed($_[0])
		or Carp::croak "Did not pass Object::Destroyer->new an object";

	# The encased object must have a DESTROY method we can call.
	# Otherwise there's no point in doing this.
	unless ( UNIVERSAL::can( $class, 'DESTROY' ) ) {
		Carp::croak "Object::Destroyer requires that $class has a DESTROY method";
	}

	# Create the object
	my $Object = shift;
	bless \$Object, $destroyer;
}

# Hand off general method calls to the encased object.
# Rather than just doing a $$self->$method(@_), which
# would leave us in the call stack, find the actual subroutine
# that will be executed, and goto that directly.
sub AUTOLOAD {
	# Extract the encased object, but leave in params
	unshift @_, ${shift()};

	# Determine the function that would have been called
	my ($method) = $Object::Destroyer::AUTOLOAD =~ /^.*::(.*)$/;
	my $function = UNIVERSAL::can( $_[0], $method );
	goto &$function if $function;

	# Bad method call... since this is probably going to die
	# anyway, we don't care about appearing in the call stack.
	Carp::croak "Can't locate object method \"$method\" via package \"" . ref($_[0]) . '"';
}

# Use our automatically triggered DESTROY to call the
# non-automatically triggered DESTROY of the encased object
sub DESTROY {
	if ( ${$_[0]} ) {
		${$_[0]}->DESTROY;
		undef ${$_[0]};
	}
}

# Catch a couple of specific cases that would be handled by UNIVERSAL
# before our AUTOLOAD got a chance to dispatch it.
sub isa { ${shift()}->isa(@_) }
sub can { ${shift()}->can(@_) }

1;

__END__

=pod

=head1 NAME

Object::Destroyer - Make objects with circular references DESTROY normally

=head1 SYNOPSIS

  use Object::Destroyer;
  
  {
      # Use a standalone destroyer to destroy something when it falls out of scope
      my $Tree = Big::Crustry::Tree->parse('somefile.txt');
      my $Cleaner = Object::Destroyer->new( $Tree );
  }
  
  {
      # Or we can use the destroyer as a near transparent wrapper
      # that will pass on method calls normally.
      my $Mess = Big::Custy::Mess->new;
      print $Mess->hello;
  }
  
  package Big::Crusty::Mess;
  
  sub new {
      my $self = bless {}, shift;
  
      $self->populate_with_stuff;
  
      return Object::Destroyer->new( $self );
  }
  
  sub hello { "Hello World!" }
  
  sub DESTROY {
      foreach my $child ( values %$self ) {
          $child->DESTROY;
      }
  
      %$self = ();
  }

=head1 DESCRIPTION

One of the biggest problem with working with large, nested object trees is
implementing a way for a child node to see its parent. The easiest way to
do this is to add a reference to the child back to its parent.

This results in a "circular" reference, where A refers to B refers to A.
Unfortunately, the garbage collector perl uses during runtime is not capable
of knowing whether or not something ELSE is refering to these circular
references.

In practical terms, this means that object trees in lexically scoped 
variable ( e.g. C<my $Object = Tree-E<gt>new> ) will not be cleaned up when
they fall out of scope, like normal variables. This results in a memory leak
for the life of the process, which is a bad thing when using mod_perl or 
other processes that live for a long time.

Object::Destroyer allows for the creation of "Destroy" handles. The handle is
"attached" to the circular relationship, but is not a part of it. When the
destroy handle falls out of scope, it will be cleaned up correctly, and while
being cleaned up, it will also force the object it is attached to to be 
destroyed as well.

=head2 Use as a Standalone Handle

The simplest way to use the class is to create a standalone destroyer,
preferably in the same lexical content. ( i.e. Immediately after creating
the parent object )

  sub plagiarise {
    # Parse in a large nested document
    my $filename = shift;
    my $Document = My::XML::Tree->open( $filename );
  
    # Create the Object::Destroyer to clean it up as needed
    my $Cleaner = Object::Destroyer->new( $Document );
  
    # Continue with the Document as normal
    if ( $Document->author == $me ) {
    	# Normally this would have leaked the document
    	return new Error("You already own the Document");
    }
    
    $Document->change_author( $me );
    $Document->save;

    # We don't have to $Document->DESTROY here
    return 1;
  }

When the Cleaner falls out of scope at the end of the sub, it will force
the cirularly linked C<$Document> to be cleaned up at the same time, rather
than being forced to manually call C<$Document->DESTROY> at each and every
location that the sub could possible return.

Using the Object::Destroy object to force garbage collection to work
properly allows you to neatly sidestep the inadequecies of the perl garbage
collector and work the way you normally would, even with big objects.

=head2 Use as a Transparent Wrapper

For situations where a class is always going to produce circular references,
you may wish to build this improved clean up directly into the class itself,
and with a few exceptions everything will just work the same.

Take the following example class

  package My::Tree;
  
  use strict;
  use Object::Destroyer;
  
  sub new {
      my $self = bless {}, shift;
      
      ###
      ### Initialise with big nasty circular references
      ###
      
      # Return the Object::Destroyer, with ourself inside it
      my $Wrapper = Object::Destroyer->new( $self );
      return $Wrapper;
  }
  
  sub param {
  	my $self = shift;
  	return $self->{CGI}->param(@_);
  }
  
  ... code ...
  
  sub DESTROY {
  	my $self = shift;
  	foreach ( values %$self ) {
  		$_->DESTROY if ref $_ eq 'My::Tree::Node';
  	}
  	%$self = ();
  }

We might use the class in something like this

  sub process_file {
      # Create a new tree
      my $Tree = My::Tree->new( source => shift );
  
      # Process the Tree
      if ( $Tree->comments ) {
          $Tree->remove_comments or return;
      } else {
          return 1; # Nothing to do
      }
  
      my $filename = $Tree->param('target') or return;
      $Tree->write( $filename ) or return;
  
      return 1;
  }

We were able to work with the data, and at no point did we know that we were
working with a Object::Destroyer object, rather than the My::Tree object itself.

=head2 Encased Objects Must Have a DESTROY Method

At this time, the DESTROY method of the underlying object is the B<ONLY> way
that the it can be destroyed. In order to use Object::Destroyer, the object
to be destroyed must have a DESTROY method. This is checked each time a
destroyer is created and an error will be thrown if it does not have one.

=head2 Resource Usage

To implement the transparency, there is a slight CPU penalty when a method is
called on the wrapper to allow it to pass the method through to the encased
object correctly, and without appearing in the caller() information. Once the
method is called on the underlying object, you can make further method calls
with no penalty and access the internals of the object normally.

=head2 Problems with Wrappers and ref or UNIVERSAL::isa

Although it may ACT exactly like what's inside it, is isn't really it. Calling
C<ref $Wrapper> or C<blessed $Wrapper> will return C<'Object::Destroyer'>, and
not the class of the object inside it.

Likewise, calling C<UNIVERSAL::isa( $Wrapper, 'My::Tree' )> or
C<UNIVERSAL::can( $Wrapper, 'param' )> directly as functions will also not work.
The two alternatives to this are to either use C<$Wrapper-E<gt>isa> or
C<$Wrapper-E<gt>can>, which will be caught and treated normally, or simple
don't use a wrapper and just use the standalone cleaners.

=head1 METHODS

=head2 new $Object

The C<new> constructor takes as argument a single blessed object, and returns
a new Object::Destroyer object, linked to it. The method will die if passed 
nothing or anything other than an object. The method will also die if the
object passed to it does not have a DESTROY function.

=head2 DESTROY

If you wish, you may explicitly DESTROY the Destroyer at any time you wish.
This will also DESTROY the encased object at the same. This can allow for
legacy cases relating to Wrappers, where a user expects to have to manually
DESTROY an object even though it is not needed. The DESTROY call will be 
accepted and dealt with as it he called it on the encased object.

=head1 TO DO

Remove the requirement for a DESTROY by adding the option of a struct
crawling manual dereferencer. There's probably one somewhere in CPAN we
could just run-time load as needed. Any suggestions?

=head1 SUPPORT

Bugs should be reported via the CPAN bug tracker at

L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Object-Destroyer>

For other issues, or commercial enhancement or support, contact the author.

=head1 AUTHOR

Adam Kennedy E<lt>adamk@cpan.orgE<gt>

=head1 COPYRIGHT

Copyright 2004 - 2006 Adam Kennedy.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
