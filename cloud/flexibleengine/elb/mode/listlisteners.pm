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

package cloud::flexibleengine::elb::mode::listlisteners;

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
    $self->{listeners} = $options{custom}->api_list_elb_listeners();

}


sub run {
    my ($self, %options) = @_;

    $self->manage_selection(%options);
    foreach  (@{$self->{listeners}->{listeners}}) {
        $self->{output}->output_add(
            long_msg => sprintf("[id = %s][name= %s][protocol= %s][port=%s][status = %s]",
             $_->{id},$_->{name},$_->{protocol},$_->{protocol_port},$_->{admin_state_up} eq '1'?'UP':'DOWN',));
    }
    $self->{output}->output_add(severity => 'OK',
                                short_msg => 'List listeners:');
    $self->{output}->display(nolabel => 1, force_ignore_perfdata => 1, force_long_output => 1);
    $self->{output}->exit();
}

sub disco_format {
    my ($self, %options) = @_;

    $self->{output}->add_disco_format(elements => ['id', 'name', 'protocol','port','status']);
}

sub disco_show {
    my ($self, %options) = @_;

    $self->manage_selection(%options);
    foreach  (@{$self->{loadbalancers}->{loadbalancers}}) {
        $self->{output}->add_disco_entry(
            id => $_->{id},
            name => $_->{name},
            protocol => $_->{protocol},
            port => $_->{protocol_port},
            status => $_->{admin_state_up} eq '1'?'UP':'DOWN',
        );
    }
}

1;

__END__

=head1 MODE

List Elastic Load Balancer Listeners.

=over 8

=back

=cut