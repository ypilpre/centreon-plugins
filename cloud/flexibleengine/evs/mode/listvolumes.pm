#
# Copyright 2020 Centreon (http://www.centreon.com/)
#
# Centreon is a full-fledged industry-strength solution that meets
# the needs in IT infrastructure and application monitoring for
# service performance.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

package cloud::flexibleengine::evs::mode::listvolumes;

use base qw(centreon::plugins::mode);


use strict;
use warnings;

 
sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;
    
    $options{options}->add_options(arguments => {});

    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::init(%options);
}

sub manage_selection {
    my ($self, %options) = @_;
    $self->{volumes} = $options{custom}->api_list_evs();

}


sub run {
    my ($self, %options) = @_;

    $self->manage_selection(%options);
    foreach  (@{$self->{volumes}->{volumes}}) {
        $self->{output}->output_add(
            long_msg => sprintf("[id = %s][name= %s][size= %s][volumetype= %s][encrypted= %s][availabilityzone = %s][replication_status = %s][status = %s]",
         $_->{id},
         $_->{name},
         $_->{size},
         $_->{volume_type},
         $_->{encrypted},
         $_->{availability_zone},
        $_->{replication_status},
         $_->{status},));
    }
    $self->{output}->output_add(severity => 'OK',
                                short_msg => 'List volume:');
    $self->{output}->display(nolabel => 1, force_ignore_perfdata => 1, force_long_output => 1);
    $self->{output}->exit();
}

sub disco_format {
    my ($self, %options) = @_;

    $self->{output}->add_disco_format(elements => ['id', 'name', 'size','volumetype','encrypted','availabilityzone','replication_status','status']);
}

sub disco_show {
    my ($self, %options) = @_;

    $self->manage_selection(%options);
    foreach  (@{$self->{volumes}->{volumes}}) {
        $self->{output}->add_disco_entry(
        id => $_->{id},
        name => $_->{name},
        status => $_->{status},
        size => $_->{size},
        volume_type => $_->{volume_type},
        encrypted => $_->{encrypted},
        availability_zone => $_->{availability_zone},
        replication_status => $_->{replication_status},
        );
    }
}

1;

__END__

=head1 MODE

List ECS servers.

=over 8

=back

=cut