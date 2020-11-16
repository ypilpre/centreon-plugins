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

package cloud::flexibleengine::css::mode::storage;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;


sub prefix_cssstorage_output {
    my ($self, %options) = @_;
    
    return "CSS Storage '" . $options{instance_value}->{display} . "' ";
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
        { name => 'css_volumes', type => 1, cb_prefix_output => 'prefix_cssstorage_output',
          message_multiple => 'All volumes are ok' },
    ];
    
    $self->{maps_counters}->{css_volumes} = [
        { label => 'storage-usage', set => {
                key_values => [ { name => 'used' }, {name => 'total' }, { name => 'display' } ],
                closure_custom_calc => $self->can('custom_usage_calc'),
                closure_custom_output => $self->can('custom_usage_output'),
                closure_custom_perfdata => $self->can('custom_usage_perfdata'),
                closure_custom_threshold_check => $self->can('custom_usage_threshold') ,
            }
        },
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_nefilter_metricw_perfdata => 1);
    bless $self, $class;
    
    $options{options}->add_options(arguments => {
        "instance-id:s@"	        => { name => 'instance_id' },
        "filter-metric:s"   => { name => 'filter_metric' },
        'filter:s'    => { name => 'filter' },
    });
    
    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::check_options(%options);


    if (!defined($self->{option_results}->{instance_id}) || $self->{option_results}->{instance_id} eq '') {
        $self->{output}->add_option_msg(short_msg => "Need to specify --instance-id option.");
        $self->{output}->option_exit();
    }

    foreach my $instance (@{$self->{option_results}->{instance_id}}) {
        if ($instance ne '') {
            push @{$self->{ces_instance}}, $instance;
        }
    }


    $self->{ces_period} = defined($self->{option_results}->{period}) && $self->{option_results}->{period} ne '' ? $self->{option_results}->{period} : 1;
    $self->{ces_frame} = defined($self->{option_results}->{frame}) && $self->{option_results}->{frame} ne '' ? $self->{option_results}->{frame} :  300;
    
    $self->{ces_filter} = 'average';
    if (defined($self->{option_results}->{filter}) &&  $self->{option_results}->{filter} ne ''){
        $self->{ces_filter} =$self->{option_results}->{filter};
    }

}

sub manage_selection {
    my ($self, %options) = @_;

    my %metric_results;
    foreach my $instance (@{$self->{ces_instance}}) {
        $metric_results{$instance} = $options{custom}->api_cloudeyes_get_metric(
            namespace => 'SYS.ES',
            dimensions => [ { name => 'cluster_id', value => $instance } ],
            metrics => ['total_fs_size','free_fs_size'],
            filter => $self->{ces_filter},
            frame => $self->{ces_frame},
            period => $self->{ces_period},
        );
        $self->{css_volumes}->{$instance} = { 
            display => $instance,
            total => $metric_results{$instance}->{total_fs_size}->{average},
            used =>  $metric_results{$instance}->{total_fs_size}->{average} - $metric_results{$instance}->{free_fs_size}->{average},

        };
    }
    
     if (scalar(%{$self->{css_volumes}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No CSS storage found.");
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check RDS instances Storage metrics.

Example: 
perl centreon_plugins.pl --plugin=cloud::flexibleengine::rds::plugin  --mode=storage --region='eu-west-0'
--type='cluster' --engine='sqlserver' --instance_id='30191908-bf15-44e8-bf5c-ffa121bbd4ea' --filter=average
--critical-storage-utilization=80 --verbose

Default statistic: 'average' / All statistics are valid.

=over 8

=item B<--instance-id>

Set the instance id (Required).

=item B<--engine>

Set the engine (Required)
Possible Value : mysql, postgresql, sqlserver

=item B<--type>

Set the type (Required)
Possible Value : instance, cluster

=item B<--warning-*> B<--critical-*>

Thresholds warning & critical.
Valid input is storage-utilization

=back

=cut
