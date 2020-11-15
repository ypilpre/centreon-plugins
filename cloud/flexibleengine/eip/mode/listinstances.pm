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

package cloud::flexibleengine::eip::mode::listinstances;

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
    $self->{publicips} = $options{custom}->api_list_eip();

}


sub run {
    my ($self, %options) = @_;

    $self->manage_selection(%options);
    foreach  (@{$self->{publicips}->{publicips}}) {
        $self->{output}->output_add(
            long_msg => sprintf("[id = %s][public_ip= %s][private_ip= %s][bandwidth = %s][status = %s]",
             $_->{id},$_->{public_ip_address},$_->{private_ip_address}, $_->{bandwidth_size}, $_->{status}));
    }
    $self->{output}->output_add(severity => 'OK',
                                short_msg => 'List eip:');
    $self->{output}->display(nolabel => 1, force_ignore_perfdata => 1, force_long_output => 1);
    $self->{output}->exit();
}

sub disco_format {
    my ($self, %options) = @_;

    $self->{output}->add_disco_format(elements => ['id', 'public_ip', 'private_ip','bandwidth','status']);
}

sub disco_show {
    my ($self, %options) = @_;

    $self->manage_selection(%options);
    foreach  (@{$self->{publicips}->{publicips}}) {
        $self->{output}->add_disco_entry(
            id => $_->{id},
            public_ip_address => $_->{public_ip_address},
            private_ip_address => $_->{private_ip_address},
            bandwidth => $_->{bandwidth_size},
            status => $_->{status}
        );
    }
}

1;

__END__

=head1 MODE

List Elastic IP.

=over 8

=back

=cut