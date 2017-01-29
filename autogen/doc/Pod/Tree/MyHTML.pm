package Pod::Tree::MyHTML;

require 5.004;

use strict;
use vars qw(&isa);
use HTML::Stream;
use IO::File;
use Pod::Tree;

$Pod::Tree::MyHTML::VERSION = '1.08';


my $LinkFormat = [ sub { my($b,$p,$f)=@_; ""              },
		   sub { my($b,$p,$f)=@_;           "#$f" },
                   sub { my($b,$p,$f)=@_;    "$p.html"    },
                   sub { my($b,$p,$f)=@_;    "$p.html#$f" },
                   sub { my($b,$p,$f)=@_; "$b/"           },
                   sub { my($b,$p,$f)=@_;           "#$f" },
                   sub { my($b,$p,$f)=@_; "$b/$p.html"    },
                   sub { my($b,$p,$f)=@_; "$b/$p.html#$f" } ];

sub new
{
    my($class, $source, $dest, %options) = @_;
    defined $dest or die "Pod::Tree::MyHTML::new: not enough arguments\n";

    my $tree   = _resolve_source($source);
    my $stream = _resolve_dest  ($dest  ); 

    my $options = { bgcolor     => '#FFFFFF',
		    depth       => 0,
		    hr          => 0,
		    link_map    => Pod::Tree::MyHTML::LinkMap->new(),
		    text        => '#000000',
		    toc         => 1,
		    };

    my $HTML = { tree        => $tree,
		 root        => $tree->get_root,
		 stream      => $stream,
		 text_method => 'text',
	         link_format => $LinkFormat,
		 options     => $options,
                 # chap        => 0,
                 # sect        => 0,
		 };

    bless $HTML, $class;

    $HTML->set_options(%options);
    $HTML
}


sub _resolve_source
{
    my $source = shift;
    my $ref    = ref $source;
    local *isa = \&UNIVERSAL::isa;

    isa $source, 'Pod::Tree' and return $source;

    my $tree = Pod::Tree->new;
    not $ref		    and $tree->load_file      ( $source);
    isa $source, 'IO::File' and $tree->load_fh	      ( $source);
    $ref eq 'SCALAR'        and $tree->load_string    ($$source);
    $ref eq 'ARRAY'         and $tree->load_paragraphs( $source);

    $tree->loaded or 
	die "Pod::Tree::MyHTML::_resolve_source: Can't load POD from $source\n";

    $tree    
}


sub _resolve_dest
{
    my $dest   = shift;
    local *isa = \&UNIVERSAL::isa;

    isa $dest, 'HTML::Stream' and return 		  $dest;
    ref $dest 		      and return HTML::Stream->new($dest);

    my $fh = IO::File->new;
    $fh->open(">$dest") or die "Pod::Tree::MyHTML::new: Can't open $dest: $!\n";
    HTML::Stream->new($fh)
}


sub set_options
{
    my($html, %options) = @_;

    my($key, $value);
    while (($key, $value) = each %options)
    {
	$html->{options}{$key} = $value;
    }
}


sub get_options
{
    my($html, @options) = @_;

    map { $html->{options}{$_} } @options
}


sub get_stream { shift->{stream} } 


sub translate
{
    my $html    = shift;
    my $stream 	= $html->{stream};
    my $bgcolor = $html->{options}{bgcolor};
    my $text 	= $html->{options}{text};
    my $title   = $html->_make_title;
    my $base    = $html->{options}{base};

    $stream->HTML->HEAD;
    
    defined $title and $stream->TITLE->text($title)->_TITLE;
    defined $base  and $stream->BASE(href => $base);

    $stream->LINK(rel => 'stylesheet', type => 'text/css', href => 'style.css');

    $stream->_HEAD
	   ->BODY(BGCOLOR => $bgcolor, TEXT => $text);

    $html->{stream}->DIV( CLASS => 'pod' );
    $stream->H1->text($title)->_H1;
    $html->{stream}->DIV( CLASS => 'toc' );
    $html->_emit_toc;
    $html->{stream}->_DIV;
    $html->_emit_body;
    $html->{stream}->_DIV;

    $stream->nl
	   ->_BODY
	   ->_HTML
}


sub _make_title
{
    my $html   = shift;

    my $title = $html->{options}{title};
    defined $title and return $title;

    my $children = $html->{root}->get_children;
    my $node1;
    my $i = 0;
    for my $child (@$children)
    {
	is_pod $child or next;
	$i++ and $node1 = $child;
	$node1 and last;
    }

    $node1 or return undef;

    my $text = $node1->get_deep_text;
    ($title) = split m(-), $text;

    $title  or return undef;      # to quiet -w
    $title =~ s(\s+$)();

    $title
}


sub _emit_toc
{
    my $html = shift;
    $html->{options}{toc} or return;

    my $root  = $html->{root};
    my $nodes = $root->get_children;
    my @nodes = @$nodes;

    $html->_emit_toc_1(\@nodes);

    $html->{options}{hr} > 0 and $html->{stream}->HR;
}


sub _emit_toc_1
{
    my($html, $nodes) = @_;
    my $stream = $html->{stream};

    $stream->UL;

    while (@$nodes)
    {
	my $node = $nodes->[0];
	is_c_head2 $node and $html->_emit_toc_2   ($nodes), next;
	is_c_head1 $node and $html->_emit_toc_item($node );
	shift @$nodes;
    }

    $stream->_UL;
}


sub _emit_toc_2
{
    my($html, $nodes) = @_;
    my $stream = $html->{stream};

    $stream->UL;

    while (@$nodes)
    {
	my $node = $nodes->[0];
	is_c_head1 $node and last;
	is_c_head2 $node and $html->_emit_toc_item($node);
	shift @$nodes;
    }

    $stream->_UL;
}


sub _emit_toc_item
{
    my($html, $node) = @_;
    my $stream = $html->{stream};
    my $target = $html->_make_anchor($node);

    $stream->LI->A(HREF => "#$target");
    $html->_emit_children($node);
    $stream->_A->_LI;
}


sub _emit_body
{
    my $html = shift;
    my $root = $html->{root};
    $html->_emit_children($root);
}


sub _emit_children
{
    my($html, $node) = @_;

    my $children = $node->get_children;

    for my $child (@$children)
    {
	$html->_emit_node($child);
    }
}


sub _emit_siblings
{
    my($html, $node) = @_;

    my $siblings = $node->get_siblings;

    for my $sibling (@$siblings)
    {
        $html->_emit_node($sibling);
    }
    
}


sub _emit_node
{
    my($html, $node) = @_;
    my $type = $node->{type};

    for ($type)
    {
	/command/  and $html->_emit_command ($node);
	/for/      and $html->_emit_for     ($node);
	/item/     and $html->_emit_item    ($node);
	/list/     and $html->_emit_list    ($node);
	/ordinary/ and $html->_emit_ordinary($node);
	/sequence/ and $html->_emit_sequence($node);
	/text/     and $html->_emit_text    ($node);
	/verbatim/ and $html->_emit_verbatim($node);
    }
}


my %HeadTag = ( head1 => { 'open' => 'H1', 'close' => '_H1', level => 1 },
	        head2 => { 'open' => 'H2', 'close' => '_H2', level => 2 } );

sub _emit_command
{
    my($html, $node) = @_;
    my $stream   = $html->{stream};
    my $command  = $node->get_command;
    my $head_tag = $HeadTag{$command};
    $head_tag or return;
    my $anchor   = $html->_make_anchor($node);

    $html->_emit_hr($head_tag->{level});

    my $tag;
    $tag = $head_tag->{'open'};
    $stream->$tag()->A(NAME => $anchor);

    # if( $command eq 'head1' ) {
    #   $html->{chap}++;
    #   $html->{sect} = 0;
    #   $stream->text( "$html->{chap} " );
    # }
    # else {
    #   $html->{sect}++;
    #   $stream->text( "$html->{chap}.$html->{sect} " );
    # }

    $html->_emit_children($node);

    $tag = $head_tag->{'close'};
    $stream->_A->$tag();
}


sub _emit_hr
{
    my($html, $level) = @_;
    $html->{options}{hr} > $level or return;
    $html->{skip_first}++ or return;
    $html->{stream}->HR;
}    


sub _emit_for
{
    my($html, $node) = @_;
    
    my $interpreter = lc $node->get_arg;
    my $emit        = "_emit_for_$interpreter";

    $html->$emit($node) if $html->can($emit);
}

sub _emit_for_html
{
    my($html, $node) = @_;

    my $stream = $html->{stream};
    $stream->P;
    my $text = $node->get_text;
    $text =~ s/\s+$//;
    $stream->io->print($text);
    $stream->_P;
}

sub _emit_for_image
{
    my($html, $node) = @_;

    my $stream = $html->{stream};
    my $link   = $node->get_text;
       $link =~ s(\s+$)();

    $stream->IMG(src => $link);
}


sub _emit_item
{
    my($html, $node) = @_;

    my $stream = $html->{stream};
    my $item_type = $node->get_item_type;
    for ($item_type)
    {
	/bullet/ and do
	{
	    $stream->LI();
	    $html->_emit_siblings($node);
	    $stream->_LI();
	};

	/number/ and do
	{
	    $stream->LI();
	    $html->_emit_siblings($node);
	    $stream->_LI();
	};

	/text/   and do
	{
	    my $anchor = $html->_make_anchor($node);
	    $stream->DT->A(NAME => "$anchor");
	    $html->_emit_children($node);
	    $stream->_A->_DT->DD;
	    $html->_emit_siblings($node);
	    $stream->_DD;
	};
    }

}


my %ListTag  = (bullet => { 'open' => 'UL', 'close' => '_UL' },
		number => { 'open' => 'OL', 'close' => '_OL' },
		text   => { 'open' => 'DL', 'close' => '_DL' } );

sub _emit_list
{
    my($html, $node) = @_;
    my($list_tag, $tag);    # to quiet -w, see beloew

    my $stream    = $html->{stream};
    my $list_type = $node->get_list_type;

    $list_type and $list_tag = $ListTag{$list_type};
    $list_tag  and $tag      = $list_tag->{'open'};
    $tag and $stream->$tag();

    $html->_emit_children($node);
    
    $list_tag and $tag = $list_tag->{'close'};
    $tag and $stream->$tag();
}


sub _emit_ordinary
{
    my($html, $node) = @_;
    my $stream = $html->{stream};

    $stream->P;
    $html->_emit_children($node);
    $stream->_P;
}


sub _emit_sequence
{
    my($html, $node) = @_;

    for ($node->get_letter)
    {
	/I|B|C|F/ and $html->_emit_element($node), last;
	/S/       and $html->_emit_nbsp   ($node), last;
	/L/       and $html->_emit_link   ($node), last;
	/X/       and $html->_emit_index  ($node), last;
	/E/       and $html->_emit_entity ($node), last;
    }
}


my %ElementTag = (I => { 'open' => 'I'   , 'close' => '_I'    },
		  B => { 'open' => 'B'   , 'close' => '_B'    },
		  C => { 'open' => 'CODE', 'close' => '_CODE' },
		  F => { 'open' => 'I'   , 'close' => '_I'    } );

sub _emit_element
{
    my($html, $node) = @_;

    my $letter = $node->get_letter;
    my $stream = $html->{stream};

    my $tag;
    $tag = $ElementTag{$letter}{'open'};
    $stream->$tag();
    $html->_emit_children($node);
    $tag = $ElementTag{$letter}{'close'};
    $stream->$tag();
}


sub _emit_nbsp
{
    my($html, $node) = @_;

    my $old_method = $html->{text_method};
    $html->{text_method} = 'text_nbsp';
    $html->_emit_children($node);
    $html->{text_method} = $old_method;
}


sub _emit_link
{
    my($html, $node) = @_;

    my $stream   = $html->{stream};
    my $target   = $node->get_target;
    my $domain   = $target->get_domain;
    my $method   = "make_${domain}_URL";
    my $url      = $html->$method($target);

    $stream->A(HREF=>$url);
    $html->_emit_children($node);
    $stream->_A;
}

sub bin { oct '0b' . join '', @_ }

sub make_POD_URL
{
    my($html, $target) = @_;

    my $base     = $html->{options}{base} || '';
    my $page     = $target->get_page;
    my $section  = $target->get_section;
    my $depth    = $html->{options}{depth};

    my $link_map = $html->{options}{link_map};
    ($base, $page, $section) = $link_map->map($base, $page, $section, $depth);

    $base =~ s(/$)();
    my $fragment = $html->_escape_text($section);
    my $i        = bin map { length($_) ? 1 : 0 } ($base, $page, $fragment);
    my $url      = $html->{link_format}[$i]($base, $page, $fragment);

    $url
}

sub make_HTTP_URL
{
    my($html, $target) = @_;

    $target->get_page
}


sub _emit_index
{
    my($html, $node) = @_;

    my $stream = $html->{stream};
    my $anchor = $html->_make_anchor($node);
    $stream->A(NAME=>$anchor);
    $html->_emit_children($node);
    $stream->_A;
}


sub _emit_entity
{
    my($html, $node) = @_;

    my $stream = $html->{stream};
    my $entity = $node->get_deep_text;
    $stream->ent($entity);
}


sub _emit_text
{
    my($html, $node) = @_;
    my $stream 	     = $html->{stream};
    my $text         = $node->get_text;
    my $text_method  = $html->{text_method};

    my @text = split $/, $text;
    pop @text while @text && $text[-1] =~ /^\s*$/;
    $text = join $/, @text;

    $stream->$text_method($text);
}


sub _emit_verbatim
{
    my($html, $node) = @_;
    my $stream = $html->{stream};
    my $text   = $node->get_text;

    $stream->PRE->text($text)->_PRE;
}


sub _make_anchor
{
    my($html, $node) = @_;
    my $text = $node->get_deep_text;
       $text =~ s(   \s*\n\s*/  )( )xg;  # close line breaks
       $text =~ s( ^\s+ | \s+$  )()xg;   # clip leading and trailing WS
       $html->_escape_text($text)
}

 
sub _escape_text
{
    my($html, $text) = @_;
    $text =~ s(([^\w\-.!~*'()]))(sprintf("%%%02x", ord($1)))eg;
    $text
}

1;

package Pod::Tree::MyHTML::LinkMap;

sub new
{
    my $class = shift;
    bless {}, $class
}

sub map
{
    my($link_map, $base, $page, $section, $depth) = @_;

    $page =~ s(::)(/)g;

    ('../' x $depth, $page, $section)
}

1;
