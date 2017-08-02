#!/usr/bin/perl

use strict;
use warnings;

use lib qw(lib t/lib);

use IPC::Open2;

use Test::Base;

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
MT::Test::Permission->make_content_data(
    blog_id         => $blog_id,
    content_type_id => $ct->id,
) for ( 1 .. 5 );

run {
    my $block = shift;

SKIP:
    {
        skip $block->skip, 1 if $block->skip;

        my $tmpl = $app->model('template')->new;
        $tmpl->text( $block->template );
        my $ctx = $tmpl->context;

        my $blog = MT::Blog->load($blog_id);
        $ctx->stash( 'blog',          $blog );
        $ctx->stash( 'blog_id',       $blog->id );
        $ctx->stash( 'local_blog_id', $blog->id );
        $ctx->stash( 'builder',       MT::Builder->new );

        my $result = eval { $tmpl->build };
        if ( defined $result ) {
            $result =~ s/^(\r\n|\r|\n|\s)+|(\r\n|\r|\n|\s)+\z//g;
            is( $result, $block->expected, $block->name );
        }
        else {
            $result = $ctx->errstr;
            $result =~ s/^(\r\n|\r|\n|\s)+|(\r\n|\r|\n|\s)+\z//g;
            is( $result, $block->error, $block->name . ' (error)' );
        }
    }
};

# sub php_test_script {
#     my ( $template, $text ) = @_;
#     $text ||= '';
#
#     my $test_script = <<PHP;
# <?php
# \$MT_HOME   = '@{[ $ENV{MT_HOME} ? $ENV{MT_HOME} : '.' ]}';
# \$MT_CONFIG = '@{[ $app->find_config ]}';
# \$blog_id   = '$blog_id';
# \$tmpl = <<<__TMPL__
# $template
# __TMPL__
# ;
# \$text = <<<__TMPL__
# $text
# __TMPL__
# ;
# PHP
#     $test_script .= <<'PHP';
# include_once($MT_HOME . '/php/mt.php');
# include_once($MT_HOME . '/php/lib/MTUtil.php');
#
# $mt = MT::get_instance(1, $MT_CONFIG);
# $mt->init_plugins();
#
# $db = $mt->db();
# $ctx =& $mt->context();
#
# $ctx->stash('blog_id', $blog_id);
# $ctx->stash('local_blog_id', $blog_id);
# $blog = $db->fetch_blog($blog_id);
# $ctx->stash('blog', $blog);
#
# if ($ctx->_compile_source('evaluated template', $tmpl, $_var_compiled)) {
#     $ctx->_eval('?>' . $_var_compiled);
# } else {
#     print('Error compiling template module.');
# }
#
# ?>
# PHP
# }
#
# SKIP:
# {
#     unless ( join( '', `php --version 2>&1` ) =~ m/^php/i ) {
#         skip "Can't find executable file: php",
#             1 * blocks;
#     }
#
#     run {
#         my $block = shift;
#
#     SKIP:
#         {
#             skip $block->skip, 1 if $block->skip;
#
#             open2( my $php_in, my $php_out, 'php -q' );
#             print $php_out &php_test_script( $block->template, $block->text );
#             close $php_out;
#             my $php_result = do { local $/; <$php_in> };
#             $php_result =~ s/^(\r\n|\r|\n|\s)+|(\r\n|\r|\n|\s)+\z//g;
#
#             my $name = $block->name . ' - dynamic';
#             is( $php_result, $block->expected, $name );
#         }
#     };
# }

__END__

=== MT::ContentsFooter
--- template
<mt:Contents blog_id="1" name="test content data"><mt:ContentsFooter><mt:ContentID></mt:ContentsFooter></mt:Contents>
--- expected
5
