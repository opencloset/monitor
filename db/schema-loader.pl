use strict;
use warnings;
{
    schema_class   => "OpenCloset::Monitor::Schema",
    connect_info   => { dsn => "dbi:SQLite:dbname=db/monitor.db" },
    loader_options => {
        dump_directory            => 'lib',
        naming                    => { ALL => 'v8' },
        skip_load_external        => 1,
        relationships             => 1,
        col_collision_map         => 'column_%s',
        result_base_class         => 'OpenCloset::Monitor::Schema::Base',
        overwrite_modifications   => 1,
        datetime_undef_if_invalid => 1,
        custom_column_info        => sub {
            my ( $table, $col_name, $col_info ) = @_;
            if ( $col_name eq 'created_at' ) {
                return {
                    %$col_info,
                    set_on_create    => 1,
                    inflate_datetime => 1
                };
            }
        },
    },
}
