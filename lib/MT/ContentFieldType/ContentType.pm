# Movable Type (r) (C) 2001-2017 Six Apart, Ltd. All Rights Reserved.
# This code cannot be redistributed without permission from www.sixapart.com.
# For more information, consult your Movable Type license.
#
# $Id$
package MT::ContentFieldType::ContentType;
use strict;
use warnings;

use MT::ContentData;
use MT::ContentField;
use MT::ContentFieldType::Common qw( get_cd_ids_by_left_join );
use MT::ContentType;

sub field_html_params {
    my ( $app, $field_data ) = @_;
    my $value = $field_data->{value} || [];
    $value = [$value] unless ref $value eq 'ARRAY';

    my %tmp_cd;
    my $iter = MT::ContentData->load_iter( { id => $value },
        { fetchonly => { id => 1, blog_id => 1, content_type_id => 1 } } );
    while ( my $cd = $iter->() ) {
        $tmp_cd{ $cd->id } = $cd;
    }
    my @content_data = grep {$_} map { $tmp_cd{$_} } @{$value};
    my @content_data_loop = map {
        {   cd_id              => $_->id,
            cd_blog_id         => $_->blog_id,
            cd_content_type_id => $_->content_type_id,
        }
    } @content_data;

    my $content_field_id = $field_data->{content_field_id} || 0;
    my $content_field = MT::ContentField->load($content_field_id);
    my $related_content_type
        = $content_field ? $content_field->related_content_type : undef;
    my $content_type_name
        = $related_content_type ? $related_content_type->name : undef;

    my $options = $field_data->{options} || {};

    my $multiple = '';
    if ( $options->{multiple} ) {
        $multiple = $options->{multiple} ? 'data-mt-multiple="1"' : '';
        my $max = $options->{max};
        my $min = $options->{min};
        $multiple .= qq{ data-mt-max-select="${max}"} if $max;
        $multiple .= qq{ data-mt-min-select="${min}"} if $min;
    }

    my $required = $options->{required} ? 'data-mt-required="1"' : '';

    {   content_data_loop => \@content_data_loop,
        content_type_name => $content_type_name,
        multiple          => $multiple,
        required          => $required,
    };
}

sub html {
    my $prop = shift;
    my ( $content_data, $app, $opts ) = @_;

    my $child_cd_ids = $content_data->data->{ $prop->content_field_id } || [];

    my %child_cd;
    my $iter = MT::ContentData->load_iter(
        { id => $child_cd_ids },
        {   fetchonly => {
                id              => 1,
                blog_id         => 1,
                content_type_id => 1,
            }
        },
    );
    while ( my $cd = $iter->() ) {
        $child_cd{ $cd->id } = $cd;
    }
    my @child_cd = map { $child_cd{$_} } @$child_cd_ids;

    my @cd_links;
    for my $cd (@child_cd) {
        my $id        = $cd->id;
        my $edit_link = $cd->edit_link($app);
        push @cd_links, qq{<a href="${edit_link}">(ID:${id})</a>};
    }

    join ', ', @cd_links;
}

sub terms_id {
    my $prop = shift;
    my ( $args, $db_terms, $db_args ) = @_;

    my $option = $args->{option} || '';
    if ( $option eq 'not_equal' ) {
        my $col        = $prop->col;
        my $value      = $args->{value} || 0;
        my $join_terms = { $col => [ \'IS NULL', $value ] };
        my $cd_ids = get_cd_ids_by_left_join( $prop, $join_terms, undef, @_ );
        $cd_ids ? { id => { not => $cd_ids } } : ();
    }
    else {
        my $join_terms = $prop->super(@_);
        my $cd_ids = get_cd_ids_by_left_join( $prop, $join_terms, undef, @_ );
        { id => $cd_ids };
    }
}

sub ss_validator {
    my ( $app, $field_data, $data ) = @_;

    my $options         = $field_data->{options} || {};
    my $content_type_id = $options->{source}     || 0;
    my $field_label     = $options->{label};

    my $iter = MT::ContentData->load_iter(
        {   id              => $data,
            blog_id         => $app->blog->id,
            content_type_id => $content_type_id,
        },
        { fetchonly => { id => 1 } },
    );
    my %valid_cds;
    while ( my $cd = $iter->() ) {
        $valid_cds{ $cd->id } = 1;
    }
    if ( my @invalid_cd_ids = grep { !$valid_cds{$_} } @{$data} ) {
        my $invalid_cd_ids = join ', ', @invalid_cd_ids;
        return $app->translate(
            'Invalid Content Data Ids: [_1] in "[_2]" field.',
            $invalid_cd_ids, $field_label );
    }

    my $content_type_name;
    if ( my $content_type = MT::ContentType->load($content_type_id) ) {
        $content_type_name = $content_type->name;
    }
    unless ( defined $content_type_name && $content_type_name ne '' ) {
        $content_type_name = 'content data';
    }

    my $type_label        = $content_type_name;
    my $type_label_plural = $type_label;
    MT::ContentFieldType::Common::ss_validator_multiple( @_, $type_label,
        $type_label_plural );
}

sub theme_import_handler {
    my ( $theme, $blog, $ct, $cf_value, $field ) = @_;
    my $name_or_unique_id = $field->{options}{source};
    if ( defined $name_or_unique_id && $name_or_unique_id ne '' ) {
        my $ct = MT::ContentType->load(
            {   blog_id   => $blog->id,
                unique_id => $name_or_unique_id,
            }
        );
        $ct ||= MT::ContentType->load(
            {   blog_id => $blog->id,
                name    => $name_or_unique_id,
            }
        );
        if ($ct) {
            $field->{options}{source} = $ct->id;
        }
        else {
            delete $field->{options}{source};
        }
    }
}

sub options_html_params {
    my ( $app, $param ) = @_;
    my $content_type_loop
        = MT->model('content_type')
        ->get_related_content_type_loop( $app->blog->id );

    return { content_types => $content_type_loop, };
}

sub options_validation_handler {
    my ( $app, $type, $label, $field_label, $options ) = @_;

    my $source = $options->{source};
    return $app->translate("You must select a source content type.")
        unless $source;

    my $class = MT->model('content_type');
    return $app->translate(
        "The source Content Type is not found in this site.",
        $label, $field_label )
        if !$class->exist( { id => $source, blog_id => $app->blog->id } );

    my $multiple = $options->{multiple};
    if ($multiple) {
        my $min = $options->{min};
        return $app->translate(
            "A number of minimum selection of '[_1]' ([_2]) must be a positive integer greater than or equal to 0.",
            $label, $field_label
        ) if '' ne $min and $min !~ /^\d+$/;

        my $max = $options->{max};
        return $app->translate(
            "A number of maximum selection of '[_1]' ([_2]) must be a positive integer greater than or equal to 1.",
            $label,
            $field_label
        ) if '' ne $max and ( $max !~ /^\d+$/ or $max < 1 );

        return $app->translate(
            "A number of maximum selection of '[_1]' ([_2]) must be a positive integer greater than or equal to a number of minimum selection.",
            $label,
            $field_label
            )
            if '' ne $min
            and '' ne $max
            and $max < $min;
    }

    return;
}

sub options_pre_save_handler {
    my ( $app, $type, $obj, $options ) = @_;

    $obj->related_content_type_id( $options->{source} );

    return;
}

1;