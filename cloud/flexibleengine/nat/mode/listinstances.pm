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

package cloud::flexibleengine::nat::mode::listinstances;

use base qw(centreon::plugins::mode);


use strict;
use warnings;

my %nat_size = (
    '1' => {
        'label' => 'Small',
    },
    '2' => {
        'label' => 'Medium',
    },
    '3' => {
        'label' => 'Large',
    },
    '4' => {
        'label' => 'Extra-Large',
    },




);

 
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
    $self->{nat_gateways} = $options{custom}->api_list_nat();

}


sub run {
    my ($self, %options) = @_;

    $self->manage_selection(%options);
    foreach  (@{$self->{nat_gateways}->{nat_gateways}}) {
        my $nat_size;
        foreach my $size (keys %nat_size) {
        next if ($size ne $_->{spec});
        $nat_size = $nat_size{$size}->{label};
    }
        $self->{output}->output_add(
            long_msg => sprintf("[id = %s][name= %s][type = %s][status = %s]",
             $_->{id},$_->{name}, $nat_size, $_->{status}));
    }
    $self->{output}->output_add(severity => 'OK',
                                short_msg => 'List Nat Gateways :');
    $self->{output}->display(nolabel => 1, force_ignore_perfdata => 1, force_long_output => 1);
    $self->{output}->exit();
}

sub disco_format {
    my ($self, %options) = @_;

    $self->{output}->add_disco_format(elements => ['id', 'name', 'type','status']);
}

sub disco_show {
    my ($self, %options) = @_;

    $self->manage_selection(%options);
    foreach  (@{$self->{nat_gateways}->{nat_gateways}}) {
        my $nat_size;
        foreach my $size (keys %nat_size) {
        next if ($size ne $_->{spec});
        $nat_size = $nat_size{$size}->{label};
        }
        $self->{output}->add_disco_entry(
            instance_id => $_->{id},
            name => $_->{name},
            type => $_->$nat_size,
            status => $_->{status}
        );
    }
}

1;

__END__

=head1 MODE

List NAT Gateway.

=over 8

=back

=cut