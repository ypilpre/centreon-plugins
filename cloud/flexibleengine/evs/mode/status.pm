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

package cloud::flexibleengine::evs::mode::status;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold);



sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;
    
    $options{options}->add_options(arguments => {
        "filter-volume-id:s" => { name => 'filter_volume_id' },
        "filter-volume-name:s" => { name => 'filter_volume_name' },
        "filter-volume-type:s" => { name => 'filter_volume_type' },
        "warning-status:s"    => { name => 'warning_status', default => '' },
        "critical-status:s"   => { name => 'critical_status', default => '' }
    });
    
    return $self;
}

sub custom_status_output {
    my ($self, %options) = @_;
    
    my $msg = sprintf('status: %s', $self->{result_values}->{status});
    return $msg;
}

sub custom_status_calc {
    my ($self, %options) = @_;
    
    $self->{result_values}->{status} = $options{new_datas}->{$self->{instance} . '_status'};
    $self->{result_values}->{display} = $options{new_datas}->{$self->{instance} . '_display'};
    return 0;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::check_options(%options);

    $self->change_macros(macros => ['warning_status', 'critical_status']);
}

sub prefix_global_output {
    my ($self, %options) = @_;

    return "Total EVS volumes ";
}

sub prefix_evsservice_output {
    my ($self, %options) = @_;
    
    return "Volume '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;
    
    $self->{maps_counters_type} = [
        { name => 'global', type => 0, cb_prefix_output => 'prefix_global_output' },
        { name => 'evs_volumes', type => 1, cb_prefix_output => 'prefix_evsservice_output',
          message_multiple => 'All volumes are ok' },
    ];

    $self->{maps_counters}->{global} = [
        { label => 'creating', nlabel => 'evs.volumes.status.creating.count', set => {
                key_values => [ { name => 'creating' }  ],
                output_template => "Creating : %s",
                perfdatas => [
                    { value => 'creating', template => '%d', min => 0 },
                ],
            }
        },
        { label => 'available', nlabel => 'evs.volumes.status.available.count', set => {
                key_values => [ { name => 'available' }  ],
                output_template => "Available : %s",
                perfdatas => [
                    { value => 'available', template => '%d', min => 0 },
                ],
            }
        },
        { label => 'in-use', nlabel => 'evs.volumes.status.in-use.count', set => {
                key_values => [ { name => 'in-use' }  ],
                output_template => "In-Use : %s",
                perfdatas => [
                    { value => 'in-use', template => '%d', min => 0 },
                ],
            }
        },
        { label => 'attaching', nlabel => 'evs.volumes.status.attaching.count', set => {
                key_values => [ { name => 'attaching' }  ],
                output_template => "Attaching : %s",
                perfdatas => [
                    { value => 'attaching', template => '%d', min => 0 },
                ],
            }
        },
        { label => 'detaching', nlabel => 'evs.volumes.status.detaching.count', set => {
                key_values => [ { name => 'detaching' }  ],
                output_template => "Detaching : %s",
                perfdatas => [
                    { value => 'detaching', template => '%d', min => 0 },
                ],
            }
        },
        { label => 'restoring-backup', nlabel => 'evs.volumes.status.restoring-backup.count', set => {
                key_values => [ { name => 'restoring-backup' }  ],
                output_template => "Restoring Backup : %s",
                perfdatas => [
                    { value => 'restoring-backup', template => '%d', min => 0 },
                ],
            }
        },
        { label => 'error_restoring', nlabel => 'evs.volumes.status.error_restoring.count', set => {
                key_values => [ { name => 'error_restoring' }  ],
                output_template => "Error Restoring : %s",
                perfdatas => [
                    { value => 'error_restoring', template => '%d', min => 0 },
                ],
            }
        },
        { label => 'uploading', nlabel => 'evs.volumes.status.uploading.count', set => {
                key_values => [ { name => 'uploading' }  ],
                output_template => "Uploading : %s",
                perfdatas => [
                    { value => 'uploading', template => '%d', min => 0 },
                ],
            }
        },
        { label => 'downloading', nlabel => 'evs.volumes.status.downloading.count', set => {
                key_values => [ { name => 'downloading' }  ],
                output_template => "Downloading : %s",
                perfdatas => [
                    { value => 'downloading', template => '%d', min => 0 },
                ],
            }
        },
        { label => 'extending', nlabel => 'evs.volumes.status.extending.count', set => {
                key_values => [ { name => 'extending' }  ],
                output_template => "Extending : %s",
                perfdatas => [
                    { value => 'extending', template => '%d', min => 0 },
                ],
            }
        },
        { label => 'error_extending', nlabel => 'evs.volumes.status.error_extending.count', set => {
                key_values => [ { name => 'error_extending' }  ],
                output_template => "Error Extending : %s",
                perfdatas => [
                    { value => 'error_extending', template => '%d', min => 0 },
                ],
            }
        },
        { label => 'error', nlabel => 'evs.volumes.status.error.count', set => {
                key_values => [ { name => 'error' }  ],
                output_template => "Error : %s",
                perfdatas => [
                    { value => 'error', template => '%d', min => 0 },
                ],
            }
        },
        { label => 'error_deleting', nlabel => 'evs.volumes.status.error_deleting.count', set => {
                key_values => [ { name => 'error_deleting' }  ],
                output_template => "Error Deleting : %s",
                perfdatas => [
                    { value => 'error_deleting', template => '%d', min => 0 },
                ],
            }
        },
        { label => 'deleting', nlabel => 'evs.volumes.status.deleting.count', set => {
                key_values => [ { name => 'deleting' }  ],
                output_template => "Deleting : %s",
                perfdatas => [
                    { value => 'deleting', template => '%d', min => 0 },
                ],
            }
        },
        { label => 'rollbacking', nlabel => 'evs.volumes.status.rollbacking.count', set => {
                key_values => [ { name => 'rollbacking' }  ],
                output_template => "Roll Backing : %s",
                perfdatas => [
                    { value => 'rollbacking', template => '%d', min => 0 },
                ],
            }
        },
        { label => 'error_rollbacking', nlabel => 'evs.volumes.status.error_rollbacking.count', set => {
                key_values => [ { name => 'error_rollbacking' }  ],
                output_template => "Error Rollbacking : %s",
                perfdatas => [
                    { value => 'error_rollbacking', template => '%d', min => 0 },
                ],
            }
        },
    ];
    
    $self->{maps_counters}->{evs_volume} = [
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

sub manage_selection {
    my ($self, %options) = @_;

    $self->{global} = {
        creating => 0, available => 0, 
        'in-use' => 0, attaching => 0,
        detaching => 0, error => 0,
        'restoring-backup' => 0,'backing-up' => 0,
        error_restoring => 0,uploading => 0,
        downloading => 0,extending => 0,
        'error_extending' => 0,deleting => 0,
        'error_deleting' => 0, rollbacking =>0,
        'error_rollbacking'=>0
    };
    $self->{evs_volumes} = {};
    my $result = $options{custom}->api_list_evs();
    foreach  (@{$result->{volumes}}) {
        if (defined($self->{option_results}->{filter_volume_id}) && $self->{option_results}->{filter_volume_id} ne '' &&
            $_->{id} !~ /$self->{option_results}->{filter_volume_id}/) {
            $self->{output}->output_add(long_msg => "skipping '" . $_->{id} . "': no matching filter.", debug => 1);
            next;
        };
        if (defined($self->{option_results}->{filter_volume_name}) && $self->{option_results}->{filter_volume_name} ne '' &&
            $_->{name} !~ /$self->{option_results}->{filter_volume_name}/) {
            $self->{output}->output_add(long_msg => "skipping '" . $_->{name} . "': no matching filter.", debug => 1);
            next;
        };
        if (defined($self->{option_results}->{filter_volume_type}) && $self->{option_results}->{filter_volume_type} ne '' &&
            $_->{volume_type} !~ /$self->{option_results}->{filter_volume_type}/) {
            $self->{output}->output_add(long_msg => "skipping '" . $_->{name} . "': no matching filter.", debug => 1);
            next;
        };
        $self->{evs_volumes}->{$_->{id}} = { 
            display => $_->{name},
            status => $_->{status},
        };
       
        $self->{global}->{$_->{status}}++;
    }
    if (scalar(%{$self->{evs_volumes}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No EVS volume found.");
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check EVS Volumes status.

Example: 
perl centreon_plugins.pl --plugin=cloud::flexibleengine::evs::plugin --mode=status --region='eu-west-0'
--filter-serverid='.*' --filter-counters='^active$' --critical-running='10' --verbose

See 'https://docs.prod-cloud-ocb.orange-business.com/en-us/usermanual/evs/evs_01_0040.html' for more informations.

=over 8

=item B<--filter-counters>

Only display some counters (regexp can be used).
Example: --filter-counters='^active$'

=item B<--filter-volume-id>

Filter by volume id (can be a regexp).

=item B<--filter-volume-name>

Filter by volume name(can be a regexp).

=item B<--filter-volume-type>

Filter by volume type(can be a regexp on SATA and SSD).

=item B<--warning-status>

Set warning threshold for status (Default: '').
Can used special variables like: %{status}, %{display}

=item B<--critical-status>

Set critical threshold for status (Default: '').
Can used special variables like: %{status}, %{display}

=item B<--warning-*> B<--critical-*>

Threshold warning.
Can be: creating','available','in-use'','attaching','detaching','error',
        'restoring-backup','backing-up','error_restoring','uploading',
        'downloading','extending','error_extending','deleting',
        'error_deleting','rollbacking','error_rollbacking'

=back

=cut