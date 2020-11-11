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

package cloud::flexibleengine::sfs::mode::sizeusage;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold);


sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;
    
    $options{options}->add_options(arguments => {
        "filter-share-id:s" => { name => 'filter_share_id' },
        "filter-share-name:s" => { name => 'filter_share_name' },
        'units:s'                 => { name => 'units', default => '%' },
        'free'                    => { name => 'free' },
    });
    
    return $self;
}


sub prefix_sfsservice_output {
    my ($self, %options) = @_;
    
    return "Share '" . $options{instance_value}->{display} . "' ";
}



sub custom_usage_perfdata {
    my ($self, %options) = @_;

    my ($label, $nlabel) = ('used', $self->{nlabel});
    my $value_perf = $self->{result_values}->{used};
    if (defined($self->{instance_mode}->{option_results}->{free})) {
        ($label, $nlabel) = ('free', 'storage.space.free.bytes');
        $value_perf = $self->{result_values}->{free};
    }

    my %total_options = ();
    if ($self->{instance_mode}->{option_results}->{units} eq '%') {
        $total_options{total} = $self->{result_values}->{total};
        $total_options{cast_int} = 1;
    }

    $self->{output}->perfdata_add(
        label => $label, unit => 'B',
        instances => $self->use_instances(extra_instance => $options{extra_instance}) ? $self->{result_values}->{display} : undef,
        nlabel => $nlabel,
        value => $value_perf,
        warning => $self->{perfdata}->get_perfdata_for_output(label => 'warning-' . $self->{thlabel}, %total_options),
        critical => $self->{perfdata}->get_perfdata_for_output(label => 'critical-' . $self->{thlabel}, %total_options),
        min => 0, max => $self->{result_values}->{total}
    );
}

sub custom_usage_threshold {
    my ($self, %options) = @_;

    my ($exit, $threshold_value);
    $threshold_value = $self->{result_values}->{used};
    $threshold_value = $self->{result_values}->{free} if (defined($self->{instance_mode}->{option_results}->{free}));
    if ($self->{instance_mode}->{option_results}->{units} eq '%') {
        $threshold_value = $self->{result_values}->{prct_used};
        $threshold_value = $self->{result_values}->{prct_free} if (defined($self->{instance_mode}->{option_results}->{free}));
    }
    $exit = $self->{perfdata}->threshold_check(
        value => $threshold_value,
        threshold => [
            { label => 'critical-' . $self->{thlabel}, exit_litteral => 'critical' },
            { label => 'warning-'. $self->{thlabel}, exit_litteral => 'warning' }
        ]
    );
    return $exit;
}

sub custom_usage_output {
    my ($self, %options) = @_;

    my ($total_size_value, $total_size_unit) = $self->{perfdata}->change_bytes(value => $self->{result_values}->{total});
    my ($total_used_value, $total_used_unit) = $self->{perfdata}->change_bytes(value => $self->{result_values}->{used});
    my ($total_free_value, $total_free_unit) = $self->{perfdata}->change_bytes(value => $self->{result_values}->{free});
    return sprintf(
        'Usage Total: %s Used: %s (%.2f%%) Free: %s (%.2f%%)',
        $total_size_value . " " . $total_size_unit,
        $total_used_value . " " . $total_used_unit, $self->{result_values}->{prct_used},
        $total_free_value . " " . $total_free_unit, $self->{result_values}->{prct_free}
    );
}

sub custom_usage_calc {
    my ($self, %options) = @_;
    $self->{result_values}->{display} = $options{new_datas}->{$self->{instance} . '_display'};
    $self->{result_values}->{total} = $options{new_datas}->{$self->{instance} . '_total'};
    $self->{result_values}->{used} = $options{new_datas}->{$self->{instance} . '_used'} ;
    $self->{result_values}->{free} = $self->{result_values}->{total} - $self->{result_values}->{used} ;
    $self->{result_values}->{prct_used} = $self->{result_values}->{used} * 100 / $self->{result_values}->{total} ;
    $self->{result_values}->{prct_free} = 100 - $self->{result_values}->{prct_used};
    
    if ($self->{result_values}->{prct_used} > 100) {
        $self->{result_values}->{free} = 0;
        $self->{result_values}->{prct_used} = 100;
        $self->{result_values}->{prct_free} = 0;
    }

    return 0;
}



sub set_counters {
    my ($self, %options) = @_;
    
    $self->{maps_counters_type} = [
        { name => 'sfs_volumes', type => 1, cb_prefix_output => 'prefix_sfsservice_output',
          message_multiple => 'All volumes are ok' },
    ];
    
    $self->{maps_counters}->{sfs_volumes} = [
        { label => 'share-usage', set => {
                key_values => [ { name => 'used' }, {name => 'total' }, { name => 'display' } ],
                closure_custom_calc => $self->can('custom_usage_calc'),
                closure_custom_output => $self->can('custom_usage_output'),
                closure_custom_perfdata => $self->can('custom_usage_perfdata'),
                closure_custom_threshold_check => $self->can('custom_usage_threshold') ,
            }
        },
    ];
}

sub manage_selection {
    my ($self, %options) = @_;

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
            total => $_->{size}*1073741824,
            used =>  $_->{metadata}->{share_used},

        };

    }
    if (scalar(%{$self->{sfs_volumes}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No SFS volume found.");
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check SFS Shares Size Usage.

Example: 
perl centreon_plugins.pl --plugin=cloud::flexibleengine::sfs::plugin --mode=sizeusage --region='eu-west-0'
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