## -*- mode: perl; coding: utf-8 -*-

use strict;
use warnings;

use Test::More;

use lib qw( t/lib lib extlib );
use MT::Test qw( :db );
use MT::Test::Permission;
use MT::Test::Upgrade;

my $blog_id = 1;

my $category_set
    = MT::Test::Permission->make_category_set( blog_id => $blog_id );
my @categories;
for ( 1 .. 3 ) {
    my $cat = MT::Test::Permission->make_category(
        blog_id         => $blog_id,
        category_set_id => $category_set->id,
    );
    push @categories, $cat;
}

my $content_type
    = MT::Test::Permission->make_content_type( blog_id => $blog_id );
my $categories_field = MT::Test::Permission->make_content_field(
    blog_id         => $blog_id,
    content_type_id => $content_type->id,
    type            => 'categories',
);
$content_type->fields(
    [   {   id      => $categories_field->id,
            order   => 1,
            type    => $categories_field->type,
            options => {
                label    => $categories_field->name,
                multiple => 1,
            },
            uniuque_id => $categories_field->unique_id,
        }
    ]
);
$content_type->save or die $content_type->errstr;

my $content_data = MT::Test::Permission->make_content_data(
    blog_id         => $blog_id,
    content_type_id => $content_type->id,
    data => { $categories_field->id => [ map { $_->id } @categories ] },
);

my @object_categories = MT->model('objectcategory')->load(
    {   blog_id   => $blog_id,
        object_ds => 'content_data',
        object_id => $content_data->id,
        cf_id     => $categories_field->id,
    }
);
is( scalar @object_categories, 3, '3 new MT::ObjectCategory' );

for my $oc (@object_categories) {
    $oc->object_ds('content_field');
    $oc->object_id( $categories_field->id );
    $oc->cf_id(0);
    $oc->save or die $oc->errstr;
}

is( MT->model('objectcategory')->count( { object_ds => 'content_field' } ),
    3, '3 old MT::ObjectCategory' );
is( MT->model('objectcategory')->count( { object_ds => 'content_data' } ),
    0, 'no new MT::ObjectCategory' );

MT::Test::Upgrade->upgrade( from => 7.0018 );

is( MT->model('objectcategory')->count( { object_ds => 'content_field' } ),
    0, 'No old MT::ObjectCategory' );
is( MT->model('objectcategory')->count( { object_ds => 'content_data' } ),
    3, '3 new MT::ObjectCategory' );

my $terms = {
    blog_id   => $blog_id,
    object_ds => 'content_data',
    object_id => $content_data->id,
    cf_id     => $categories_field->id,
};
is( MT->model('objectcategory')->count(
        {   %$terms,
            category_id => $categories[0]->id,
            is_primary  => 1,
        }
    ),
    1,
    'MT::ObjectCategory of $category[0]',
);
is( MT->model('objectcategory')->count(
        {   %$terms,
            category_id => $categories[1]->id,
            is_primary  => 0,
        }
    ),
    1,
    'MT::ObjectCategory of $category[1]',
);
is( MT->model('objectcategory')->count(
        {   %$terms,
            category_id => $categories[2]->id,
            is_primary  => 0,
        }
    ),
    1,
    'MT::ObjectCategory of $category[2]',
);

done_testing;
