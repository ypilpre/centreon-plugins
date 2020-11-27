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

package cloud::flexibleengine::dcs::mode::status;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;

use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold);

sub custom_status_output {
    my ($self, %options) = @_;
    
    my $msg = sprintf('status: %s', $self->{result_values}->{state});
    return $msg;
}

sub custom_status_calc {
    my ($self, %options) = @_;
    
    $self->{result_values}->{state} = $options{new_datas}->{$self->{instance} . '_status'};
    $self->{result_values}->{display} = $options{new_datas}->{$self->{instance} . '_display'};
    return 0;
}


sub prefix_global_output {
    my ($self, %options) = @_;

    return "Total dcs clusters ";
}

sub prefix_dcservice_output {
    my ($self, %options) = @_;
    
    return "Cluster '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;
    
    $self->{maps_counters_type} = [
        { name => 'global', type => 0, cb_prefix_output => 'prefix_global_output' },
        { name => 'dcs_instances', type => 1, cb_prefix_output => 'prefix_dcservice_output',
          message_multiple => 'All servers are ok' },
    ];
        
    $self->{maps_counters}->{global} = [

        { label => 'total-error',nlabel => 'dcs.cluster.status.error.count',set => {
                key_values => [ { name => 'ERROR' }  ],
                output_template => "Error : %s",
                perfdatas => [
                    {  value => 'ERROR', template => '%d'},
                ],
            }
        },
        { label => 'total-running', nlabel => 'dcs.instance.status.running.count',set => {
                key_values => [ { name => 'RUNNING' }  ],
                output_template => "Running : %s",
                perfdatas => [
                    { value => 'RUNNING', template => '%d' },
                ],
            }
        }
    ];
    
    $self->{maps_counters}->{dcs_instances} = [
        { label => 'status', threshold => 0, set => {
                key_values => [ { name => 'status' }, { name => 'display' } ],
                closure_custom_calc => $self->can('custom_status_calc'),
                closure_custom_output => $self->can('custom_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold,
            }
        },
    ];
}


sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;
    
    $options{options}->add_options(arguments => {
        "filter-instance-id:s" => { name => 'filter_instance_id' },
        "filter-instance-name:s" => { name => 'filter_instance_name' },
        "warning-status:s"    => { name => 'warning_status', default => '' },
        "critical-status:s"   => { name => 'critical_status', default => '' }
    });

    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::check_options(%options);

    $self->change_macros(macros => ['warning_status', 'critical_status']);

}

sub manage_selection {
    my ($self, %options) = @_;

    $self->{global} = {
        RUNNING => 0, ERROR => 0
    };
    $self->{dcs_instances} = {};
    my $result = $options{custom}->api_list_dcs();
    foreach  (@{$result->{instances}}) {
        if (defined($self->{option_results}->{filter_instance_id}) && $self->{option_results}->{filter_instance_id} ne '' &&
            $_->{id} !~ /$self->{option_results}->{filter_instance_id}/) {
            $self->{output}->output_add(long_msg => "skipping '" . $_->{id} . "': no matching filter.", debug => 1);
            next;
        };
        if (defined($self->{option_results}->{filter_instance_name}) && $self->{option_results}->{filter_instance_name} ne '' &&
            $_->{name} !~ /$self->{option_results}->{filter_instance_name}/) {
            $self->{output}->output_add(long_msg => "skipping '" . $_->{name} . "': no matching filter.", debug => 1);
            next;
        };
       
        $self->{dcs_instances}->{$_->{instance_id}} = { 
            display => $_->{name},
            status => $_->{status},
        };
        
        $self->{global}->{$_->{status}}++;
    }
    if (scalar(%{$self->{dcs_instances}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No dcs cluster found.");
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check DCS instances Status.

Example: 
perl centreon_plugins.pl --plugin=cloud::flexibleengine::dcs::plugin  --mode=status --region='eu-west-0'
 --instance-id='28616721-d001-480b-99d0-deccacf414e7'
--critical-unavailable='1' --verbose

See 'https://docs.otc.t-systems.com/api/dcs/dcs_03_0018.html' for more informations.


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
Can be:  'total-error'

=back

=cut
