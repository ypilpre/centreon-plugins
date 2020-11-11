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

package cloud::flexibleengine::sfs::mode::status;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold);
use Data::Dumper::Simple;


sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;
    
    $options{options}->add_options(arguments => {
        "filter-share-id:s" => { name => 'filter_share_id' },
        "filter-share-name:s" => { name => 'filter_share_name' },
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

    return "Total SFS volumes ";
}

sub prefix_sfsservice_output {
    my ($self, %options) = @_;
    
    return "Volume '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;
    
    $self->{maps_counters_type} = [
        { name => 'global', type => 0, cb_prefix_output => 'prefix_global_output' },
        { name => 'sfs_volumes', type => 1, cb_prefix_output => 'prefix_sfsservice_output',
          message_multiple => 'All volumes are ok' },
    ];

    $self->{maps_counters}->{global} = [
        { label => 'creating', nlabel => 'sfs.volumes.status.creating.count', set => {
                key_values => [ { name => 'creating' }  ],
                output_template => "Creating : %s",
                perfdatas => [
                    { value => 'creating', template => '%d', min => 0 },
                ],
            }
        },
        { label => 'available', nlabel => 'sfs.volumes.status.available.count', set => {
                key_values => [ { name => 'available' }  ],
                output_template => "Available : %s",
                perfdatas => [
                    { value => 'available', template => '%d', min => 0 },
                ],
            }
        },
        { label => 'shrinking', nlabel => 'sfs.volumes.status.shrinking.count', set => {
                key_values => [ { name => 'shrinking' }  ],
                output_template => "Shrinking : %s",
                perfdatas => [
                    { value => 'shrinking', template => '%d', min => 0 },
                ],
            }
        },
        { label => 'extending', nlabel => 'sfs.volumes.status.extending.count', set => {
                key_values => [ { name => 'extending' }  ],
                output_template => "Extending : %s",
                perfdatas => [
                    { value => 'extending', template => '%d', min => 0 },
                ],
            }
        },
        { label => 'shrinking_error', nlabel => 'sfs.volumes.status.shrinking.error.count', set => {
                key_values => [ { name => 'extending' }  ],
                output_template => "Extending : %s",
                perfdatas => [
                    { value => 'extending', template => '%d', min => 0 },
                ],
            }
        },
        ,
        { label => 'shrinking_possible_data_loss_error', nlabel => 'sfs.volumes.status.shrinking.error.possible-data-loss.count', set => {
                key_values => [ { name => 'shrinking_possible_data_loss_error' }  ],
                output_template => "Error Shrinking with Possible Data Loss : %s",
                perfdatas => [
                    { value => 'shrinking_possible_data_loss_error', template => '%d', min => 0 },
                ],
            }
        },
        { label => 'error_extending', nlabel => 'sfs.volumes.status.extending.error.count', set => {
                key_values => [ { name => 'error_extending' }  ],
                output_template => "Error Extending : %s",
                perfdatas => [
                    { value => 'error_extending', template => '%d', min => 0 },
                ],
            }
        },
        { label => 'error', nlabel => 'sfs.volumes.status.error.count', set => {
                key_values => [ { name => 'error' }  ],
                output_template => "Error : %s",
                perfdatas => [
                    { value => 'error', template => '%d', min => 0 },
                ],
            }
        },
        { label => 'error_deleting', nlabel => 'sfs.volumes.status.error_deleting.count', set => {
                key_values => [ { name => 'error_deleting' }  ],
                output_template => "Error Deleting : %s",
                perfdatas => [
                    { value => 'error_deleting', template => '%d', min => 0 },
                ],
            }
        },
        { label => 'deleting', nlabel => 'sfs.volumes.status.deleting.count', set => {
                key_values => [ { name => 'deleting' }  ],
                output_template => "Deleting : %s",
                perfdatas => [
                    { value => 'deleting', template => '%d', min => 0 },
                ],
            }
        },
        { label => 'rollbacking', nlabel => 'sfs.volumes.status.rollbacking.count', set => {
                key_values => [ { name => 'rollbacking' }  ],
                output_template => "Roll Backing : %s",
                perfdatas => [
                    { value => 'rollbacking', template => '%d', min => 0 },
                ],
            }
        },
        { label => 'error_rollbacking', nlabel => 'sfs.volumes.status.error_rollbacking.count', set => {
                key_values => [ { name => 'error_rollbacking' }  ],
                output_template => "Error Rollbacking : %s",
                perfdatas => [
                    { value => 'error_rollbacking', template => '%d', min => 0 },
                ],
            }
        },
    ];
    
    $self->{maps_counters}->{sfs_volume} = [
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
        shrinking =>0, shrinking_error =>0,
        extending => 0, shrinking_possible_data_loss_error =>0,
        'error_extending' => 0,deleting => 0,
        'error_deleting' => 0, rollbacking =>0,
        'error_rollbacking'=>0
    };
    $self->{sfs_volumes} = {};
    my $result = $options{custom}->api_list_sfs();
    foreach  (@{$result->{shares}}) {
        if (defined($self->{option_results}->{filter_share_id}) && $self->{option_results}->{filter_share_id} ne '' &&
            $_->{id} !~ /$self->{option_results}->{filter_share_id}/) {
            $self->{output}->output_add(long_msg => "skipping '" . $_->{id} . "': no matching filter.", debug => 1);
            next;
        };
        if (defined($self->{option_results}->{filter_share_name}) && $self->{option_results}->{filter_share_name} ne '' &&
            $_->{name} !~ /$self->{option_results}->{filter_share_name}/) {
            $self->{output}->output_add(long_msg => "skipping '" . $_->{name} . "': no matching filter.", debug => 1);
            next;
        };
        $self->{sfs_volumes}->{$_->{id}} = { 
            display => $_->{name},
            status => $_->{status},
        };
       
        $self->{global}->{$_->{status}}++;
    }
    if (scalar(%{$self->{sfs_volumes}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No SFS volume found.");
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check SFS Shares status.

Example: 
perl centreon_plugins.pl --plugin=cloud::flexibleengine::sfs::plugin --mode=status --region='eu-west-0'
--filter-share-id='.*' --filter-counters='^active$' --critical-running='10' --verbose

See 'https://docs.prod-cloud-ocb.orange-business.com/en-us/api/sfs/sfs_02_0023.html' for more informations.

=over 8

=item B<--filter-counters>

Only display some counters (regexp can be used).
Example: --filter-counters='^active$'

=item B<--filter-share-id>

Filter by share id (can be a regexp).

=item B<--filter-share-name>

Filter by share name(can be a regexp).

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