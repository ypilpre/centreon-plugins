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

package cloud::flexibleengine::ecs::mode::status;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold);


sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;
    
    $options{options}->add_options(arguments => {
        "filter-instance-id:s" => { name => 'filter_instance_id' },
        "filter-instance-name:s" => { name => 'filter_instance_name' },
        "warning-status:s"    => { name => 'warning_status', default => '' },
        "critical-status:s"   => { name => 'critical_status', default => '' }
    });
    
    return $self;
}

sub custom_status_output {
    my ($self, %options) = @_;
    
    my $msg = sprintf('state: %s', $self->{result_values}->{state});
    return $msg;
}

sub custom_status_calc {
    my ($self, %options) = @_;
    
    $self->{result_values}->{state} = $options{new_datas}->{$self->{instance} . '_state'};
    $self->{result_values}->{display} = $options{new_datas}->{$self->{instance} . '_display'};
    return 0;
}

sub prefix_global_output {
    my ($self, %options) = @_;

    return "Total ECS Server ";
}

sub prefix_ecs_output {
    my ($self, %options) = @_;
    
    return "ECS Server '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;
    
    $self->{maps_counters_type} = [
        { name => 'global', type => 0, cb_prefix_output => 'prefix_global_output' },
        { name => 'ecs_servers', type => 1, cb_prefix_output => 'prefix_ecs_output',
          message_multiple => 'All servers are ok' },
    ];

    $self->{maps_counters}->{global} = [
        { label => 'building', nlabel => 'ecs.servers.status.building.count', set => {
                key_values => [ { name => 'building' }  ],
                output_template => "Building : %s",
                perfdatas => [
                    { value => 'building', template => '%d', min => 0 },
                ],
            }
        },
        { label => 'active', nlabel => 'ecs.servers.status.active.count', set => {
                key_values => [ { name => 'active' }  ],
                output_template => "Active : %s",
                perfdatas => [
                    { value => 'active', template => '%d', min => 0 },
                ],
            }
        },
        { label => 'stopped', nlabel => 'ecs.servers.status.stopped.count', set => {
                key_values => [ { name => 'stopped' }  ],
                output_template => "Stopped : %s",
                perfdatas => [
                    { value => 'stopped', template => '%d', min => 0 },
                ],
            }
        },
        { label => 'resized', nlabel => 'ecs.servers.status.resized.count', set => {
                key_values => [ { name => 'resized' }  ],
                output_template => "Resized : %s",
                perfdatas => [
                    { value => 'resized', template => '%d', min => 0 },
                ],
            }
        },
        { label => 'error', nlabel => 'ecs.servers.status.error.count', set => {
                key_values => [ { name => 'error' }  ],
                output_template => "Error : %s",
                perfdatas => [
                    { value => 'error', template => '%d', min => 0 },
                ],
            }
        },
        { label => 'deleted', nlabel => 'ecs.servers.status.deleted.count', set => {
                key_values => [ { name => 'deleted' }  ],
                output_template => "Deleted : %s",
                perfdatas => [
                    { value => 'deleted', template => '%d', min => 0 },
                ],
            }
        },
    ];
    
    $self->{maps_counters}->{ecs_servers} = [
        { label => 'status', threshold => 0, set => {
                key_values => [ { name => 'state' }, { name => 'display' } ],
                closure_custom_calc => $self->can('custom_status_calc'),
                closure_custom_output => $self->can('custom_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold,
            }
        },
    ];
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::check_options(%options);

    $self->change_macros(macros => ['warning_status', 'critical_status']);
}


sub manage_selection {
    my ($self, %options) = @_;

    $self->{global} = {
        building => 0, active => 0, stopped => 0, resized => 0, error => 0, deleted => 0,
    };
    $self->{ecs_servers} = {};
    my $result = $options{custom}->api_list_ecs();

    foreach my $ecs (@{$result->{servers}}) {
        if (defined($self->{option_results}->{filter_instance_id}) && $self->{option_results}->{filter_instance_id} ne '' &&
            $ecs->{id} !~ /$self->{option_results}->{filter_instance_id}/) {
            $self->{output}->output_add(long_msg => "skipping '" . $ecs->{id} . "': no matching filter.", debug => 1);
            next;
        }
        if (defined($self->{option_results}->{filter_instance_name}) && $self->{option_results}->{filter_instance_name} ne '' &&
            $ecs->{name} !~ /$self->{option_results}->{filter_instance_name}/) {
            $self->{output}->output_add(long_msg => "skipping '" . $ecs->{name} . "': no matching filter.", debug => 1);
            next;
        }
        ;
        $self->{ecs_servers}->{$ecs->{id}} = { 
            display => $ecs->{name},
            state => $ecs->{'OS-EXT-STS:vm_state'},
            };
        $self->{global}->{$ecs->{'OS-EXT-STS:vm_state'}}++;
    }
    if (scalar(%{$self->{ecs_servers}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No ECS server found.");
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check ECS servers status.

Example: 
perl centreon_plugins.pl --plugin=cloud::flexibleengine::ecs::plugin --mode=status --region='eu-west-0'
--filter-instance-id='.*' --filter-counters='^active$' --critical-running='10' --verbose

See 'https://docs.prod-cloud-ocb.orange-business.com/en-us/api/ecs/en-us_topic_0178420672.html' for more informations.

=over 8

=item B<--filter-counters>

Only display some counters (regexp can be used).
Example: --filter-counters='^active$'

=item B<--filter-instance-name>

Filter by instance name (can be a regexp).

=item B<--filter-instance-id>

Filter by instance id (can be a regexp).

=item B<--warning-status>

Set warning threshold for status (Default: '').
Can used special variables like: %{state}, %{display}

=item B<--critical-status>

Set critical threshold for status (Default: '').
Can used special variables like: %{state}, %{display}

=item B<--warning-*> B<--critical-*>

Threshold warning.
Can be: 'building', 'stopped', 'resized', 'error' or
'deleted'

=back

=cut