## -*- mode: perl; coding: utf-8 -*-

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";    # t/lib
use Test::More;
use MT::Test::Env;
our $test_env;

BEGIN {
    $test_env = MT::Test::Env->new;
    $ENV{MT_CONFIG} = $test_env->config_file;
}

use MT::Test;
use MT::Test::Permission;

use MT::Author;
use MT::ContentData;
use MT::ContentFieldIndex;
use MT::ContentStatus;

MT::Test->init_app;

$test_env->prepare_fixture(
    sub {
        MT::Test->init_db;

        my $admin = MT::Author->load(1);
        my $user = MT::Test::Permission->make_author( name => 'test user', );
        $user->save or die $user->errstr;

        my $content_type = MT::Test::Permission->make_content_type(
            blog_id => 1,
            name    => 'test content type',
        );

        my $content_field = MT::Test::Permission->make_content_field(
            blog_id         => $content_type->blog_id,
            content_type_id => $content_type->id,
            name            => 'single text',
            type            => 'single_line_text',
        );

        my $fields = [
            {   id        => $content_field->id,
                label     => 1,
                name      => $content_field->name,
                order     => 1,
                type      => $content_field->type,
                unique_id => $content_field->unique_id,
            }
        ];
        $content_type->fields($fields);
        $content_type->save or die $content_type->errstr;

        my $create_content_data_role = MT::Test::Permission->make_role(
            name        => 'create_content_data',
            permissions => "'create_content_data:"
                . $content_type->unique_id . "'"
        );
        $user->add_role($create_content_data_role);
        my $website = MT::Website->load(1);
        require MT::Association;
        MT::Association->link(
            $user => $create_content_data_role => $website );

    }
);

my $admin = MT::Author->load(1);
my $user = MT::Author->load( { name => 'test user' } );

my $content_type = MT::ContentType->load( { name => 'test content type' } );
my $content_field = MT::ContentField->load( { name => 'single text' } );

my ( $admin_content_data, $admin_cf_idx, $user_content_data, $user_cf_idx );

my ( $app, $out );
subtest 'mode=save_content_data (create)' => sub {
    $app = _run_app(
        'MT::App::CMS',
        {   __test_user      => $admin,
            __request_method => 'POST',
            __mode           => 'save',
            blog_id          => $content_type->blog_id,
            content_type_id  => $content_type->id,
            status           => MT::ContentStatus::HOLD(),
            'content-field-' . $content_field->id => 'admin input',
            _type                                 => 'content_data',
            type => 'content_data_' . $content_type->id,
        },
    );
    $out = delete $app->{__test_output};
    ok( $out =~ /saved_added=1/, 'content data has been saved' );
    ok( $out =~ /302 Found/,     'redirect to list_content_data screen' );

    # check content data
    $admin_content_data = MT::ContentData->load(
        {   blog_id         => $content_type->blog_id,
            author_id       => $admin->id,
            content_type_id => $content_type->id,
            data            => { like => "%admin input%" }
        }
    );
    ok( $admin_content_data, 'got content data' );
    is( $admin_content_data->column('data'),
        '{"' . $content_field->id . '":"admin input"}',
        'content data has content field data'
    );

    is( $admin_content_data->author_id, $admin->id, 'author_id is admin ID' );
    is( $admin_content_data->created_by,
        $admin->id, 'created_by is admin ID' );
    is( $admin_content_data->modified_by, undef, 'modified_by is undef' );

    # check content field
    $admin_cf_idx = MT::ContentFieldIndex->load(
        {   content_type_id  => $content_type->id,
            content_field_id => $content_field->id,
            content_data_id  => $admin_content_data->id,
        }
    );
    ok( $admin_cf_idx, 'got content field index' );
    is( $admin_cf_idx->value_varchar,
        'admin input', 'content field data is set in content field index' );
};

subtest 'mode=save_content_data (create)not superuser' => sub {
    $app = _run_app(
        'MT::App::CMS',
        {   __test_user      => $user,
            __request_method => 'POST',
            __mode           => 'save',
            blog_id          => $content_type->blog_id,
            content_type_id  => $content_type->id,
            status           => MT::ContentStatus::HOLD(),
            'content-field-' . $content_field->id => 'user input',
            _type                                 => 'content_data',
            type => 'content_data_' . $content_type->id,
        },
    );
    $out = delete $app->{__test_output};
    ok( $out =~ /saved_added=1/, 'content data has been saved' );
    ok( $out =~ /302 Found/,     'redirect to list_content_data screen' );

    # check content data
    $user_content_data = MT::ContentData->load(
        {   blog_id         => $content_type->blog_id,
            author_id       => $user->id,
            content_type_id => $content_type->id,
            data            => { like => "%user input%" }
        }

    );
    ok( $user_content_data, 'got content data' );
    is( $user_content_data->column('data'),
        '{"' . $content_field->id . '":"user input"}',
        'content data has content field data'
    );

    is( $user_content_data->author_id,   $user->id, 'author_id is user ID' );
    is( $user_content_data->created_by,  $user->id, 'created_by is user ID' );
    is( $user_content_data->modified_by, undef,     'modified_by is undef' );

    # check content field
    $user_cf_idx = MT::ContentFieldIndex->load(
        {   content_type_id  => $content_type->id,
            content_field_id => $content_field->id,
            content_data_id  => $user_content_data->id,
        }
    );
    ok( $user_cf_idx, 'got content field index' );
    is( $user_cf_idx->value_varchar,
        'user input', 'content field data is set in content field index' );
};

subtest 'mode=save_content_data (update)' => sub {
    my $app = _run_app(
        'MT::App::CMS',
        {   __test_user      => $admin,
            __request_method => 'POST',
            __mode           => 'save',
            id               => $admin_content_data->id,
            blog_id          => $content_type->blog_id,
            content_type_id  => $content_type->id,
            status           => MT::ContentStatus::HOLD(),
            'content-field-' . $content_field->id => 'admin input update',
            _type                                 => 'content_data',
            type => 'content_data_' . $content_type->id,
        },
    );
    my $out = delete $app->{__test_output};
    ok( $out =~ /saved_changes=1/, 'content data has been saved' );
    ok( $out =~ /302 Found/,       'redirect to list_content_data screen' );

    # check content data
    is( MT::ContentData->count, 2, 'content data count is 2' );
    is( MT::ContentData->load(
            { data => { like => "%admin input update%" } }
            )->id,
        $admin_content_data->id,
        'content data ID is not changed'
    );

    $admin_content_data = MT::ContentData->load( $admin_content_data->id );
    is( $admin_content_data->column('data'),
        '{"' . $content_field->id . '":"admin input update"}',
        'content field data has been updated'
    );

    is( $admin_content_data->author_id, $admin->id, 'author_id is admin ID' );
    is( $admin_content_data->created_by,
        $admin->id, 'created_by is admin ID' );
    is( $admin_content_data->modified_by,
        $admin->id, 'modified_by is admin ID' );

    # check content field
    is( MT::ContentFieldIndex->count, 2, 'content field count is 1' );
    is( MT::ContentFieldIndex->load(
            { content_data_id => $admin_content_data->id }
            )->id,
        $admin_cf_idx->id,
        'content field ID is not changed'
    );

    $admin_cf_idx = MT::ContentFieldIndex->load( $admin_cf_idx->id );
    is( $admin_cf_idx->value_varchar,
        'admin input update',
        'content field data has been updated in content field index'
    );
};

subtest 'mode=save_content_data (update)not superuser' => sub {
    $app = _run_app(
        'MT::App::CMS',
        {   __test_user      => $user,
            __request_method => 'POST',
            __mode           => 'save',
            id               => $user_content_data->id,
            blog_id          => $content_type->blog_id,
            content_type_id  => $content_type->id,
            status           => MT::ContentStatus::HOLD(),
            'content-field-' . $content_field->id => 'user input update2',
            _type                                 => 'content_data',
            type => 'content_data_' . $content_type->id,
        },
    );
    $out = delete $app->{__test_output};
    ok( $out =~ /permission=1/, 'content data has been saved' );

};

done_testing;

