use utf8;
package OpenCloset::Monitor::Schema::Result::History;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

OpenCloset::Monitor::Schema::Result::History

=cut

use strict;
use warnings;

=head1 BASE CLASS: L<OpenCloset::Monitor::Schema::Base>

=cut

use base 'OpenCloset::Monitor::Schema::Base';

=head1 TABLE: C<history>

=cut

__PACKAGE__->table("history");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 room_no

  data_type: 'integer'
  is_nullable: 1

=head2 order_id

  data_type: 'integer'
  is_nullable: 1

=head2 created_at

  data_type: 'text'
  inflate_datetime: 1
  is_nullable: 1
  set_on_create: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "room_no",
  { data_type => "integer", is_nullable => 1 },
  "order_id",
  { data_type => "integer", is_nullable => 1 },
  "created_at",
  {
    data_type        => "text",
    inflate_datetime => 1,
    is_nullable      => 1,
    set_on_create    => 1,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");


# Created by DBIx::Class::Schema::Loader v0.07042 @ 2015-03-16 11:12:22
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:neeCAlKQK0z/7ZknUVzTtg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
