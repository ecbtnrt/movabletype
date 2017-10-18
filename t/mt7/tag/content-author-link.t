#!/usr/bin/perl

use strict;
use warnings;
use utf8;

use lib qw(lib t/lib);

use MT::Test::Tag;

# plan tests => 2 * blocks;
plan tests => 1 * blocks;

use MT;
use MT::Test qw(:db);
use MT::Test::Permission;
my $app = MT->instance;

my $blog_id = 1;

filters {
    template => [qw( chomp )],
    expected => [qw( chomp )],
    error    => [qw( chomp )],
};

my $mt = MT->instance;

my $ct = MT::Test::Permission->make_content_type(
    name    => 'test content data',
    blog_id => $blog_id,
);
my $cd = MT::Test::Permission->make_content_data(
    blog_id         => $blog_id,
    content_type_id => $ct->id,
);
my $author = $cd->author;
$author->set_values(
    {   nickname => 'Abby',
        url      => 'https://example.com/~abby',
    }
);
$author->save or die $author->errstr;

MT::Test::Tag->run_perl_tests($blog_id);
# MT::Test::Tag->run_php_tests($blog_id);

__END__

=== MT::ContentAuthorLink
--- template
<mt:Contents blog_id="1" name="test content data"><mt:ContentAuthorLink></mt:Contents>
--- expected
<a href="https://example.com/~abby">Abby</a>

=== MT::ContentAuthorLink with new_window="1"
--- template
<mt:Contents blog_id="1" name="test content data"><mt:ContentAuthorLink new_window="1"></mt:Contents>
--- expected
<a href="https://example.com/~abby" target="_blank">Abby</a>
