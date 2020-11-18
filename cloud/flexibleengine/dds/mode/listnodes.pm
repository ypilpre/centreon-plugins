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

package cloud::flexibleengine::dds::mode::listnodes;

use base qw(centreon::plugins::mode);

use strict;
use warnings;

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;
    
    $options{options}->add_options(arguments =>
                                {
                                });

    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::init(%options);
}

sub manage_selection {
    my ($self, %options) = @_;

    $self->{instance} = $options{custom}->api_list_dds_nodes();
}

sub run {
    my ($self, %options) = @_;

    $self->manage_selection(%options);
    foreach (sort @{$self->{instance}}) {
        $self->{output}->output_add(long_msg => sprintf("[id = %s][name = %s][status = %s][role = %s][spec = %s][type = %s][private_ip=%s][availability_zone = %s][instance = %s][instance_id = %s]",
        $_->{id},$_->{name},$_->{status},$_->{role},$_->{spec},$_->{type},$_->{private_ip},$_->{availability_zone},$_->{instance},$_->{instance_id},));
    }
    
    $self->{output}->output_add(severity => 'OK',
                                short_msg => 'List DDS nodes:');
    $self->{output}->display(nolabel => 1, force_ignore_perfdata => 1, force_long_output => 1);
    $self->{output}->exit();
}

sub disco_format {
    my ($self, %options) = @_;
    
    $self->{output}->add_disco_format(elements => ['id','name','status','role','spec','private_ip','type' ,'instance','instance_id', 'availability_zone']);
}

sub disco_show {
    my ($self, %options) = @_;

    $self->manage_selection(%options);
    foreach  (sort @{$self->{instance}}) {
        $self->{output}->add_disco_entry(
        id => $_->{id},
        name => $_->{name},
        status => $_->{status},
        type => $_->{type},
        role => $_->{role} eq 'Hidden'?'Secondary':$_->{role},
        spec => $_->{spec},
        private_ip => $_->{private_ip},
        instance => $_->{instance},
        instance_id => $_->{instance_id},
        availability_zone => $_->{availability_zone},
        );
    }
}

1;

__END__

=head1 MODE

List DDS Nodes.

=over 8

=back

=cut
    
