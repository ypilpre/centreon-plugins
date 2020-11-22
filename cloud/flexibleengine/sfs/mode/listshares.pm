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

package cloud::flexibleengine::sfs::mode::listshares;

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
    $self->{shares} = $options{custom}->api_list_sfs();
   

}


sub run {
    my ($self, %options) = @_;

    $self->manage_selection(%options);
    foreach  (@{$self->{shares}->{shares}}) {
        
        $self->{output}->output_add(
            long_msg => sprintf("[id = %s][name= %s][availability_zone = %s][protocol=%s][status = %s]",
             $_->{id},$_->{name}, $_->{availability_zone}, $_->{share_proto},$_->{status}));
    }
    $self->{output}->output_add(severity => 'OK',
                                short_msg => 'List Shares:');
    $self->{output}->display(nolabel => 1, force_ignore_perfdata => 1, force_long_output => 1);
    $self->{output}->exit();
}

sub disco_format {
    my ($self, %options) = @_;

    $self->{output}->add_disco_format(elements => ['id', 'name', 'availability_zone' ,'protocol','status']);
}

sub disco_show {
    my ($self, %options) = @_;

    $self->manage_selection(%options);
    foreach  (@{$self->{shares}->{shares}}) {
        $self->{output}->add_disco_entry(
            instance_id => $_->{id},
            name => $_->{name},
            availabilityzone => $_->{availability_zone},
            protocol => $_->{share_proto},

            status => $_->{status}
        );
    }
}

1;

__END__

=head1 MODE

List SFS shares.

=over 8

=back

=cut