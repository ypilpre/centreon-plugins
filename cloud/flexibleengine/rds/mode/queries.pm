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

package cloud::flexibleengine::rds::mode::queries;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use Data::Dumper::Simple;
my %metrics_mapping = (
    'rds008_qps' => {
        'std_metric' => 'queries_sec',
        'output' => 'Queries per second',
        'label' => 'QPS',
        'nlabel' => 'rds.statements.sec',
        'unit','q/s'
    },
    'rds028_comdml_del_count' => {
        'std_metric' => 'delete_state_sec',
        'output' => 'DELETE Statements per Second',
        'label' => 'state-del-sec',
        'nlabel' => 'rds.statement.delete.sec',
        'unit','q/s'
    },
    'rds029_comdml_ins_count' => {
        'std_metric' => 'insert_state_sec',
        'output' => 'INSERT Statements per Second',
        'label' => 'state-ins-sec',
        'nlabel' => 'rds.statement.insert.sec',
        'unit','q/s'
    },
    'rds030_comdml_ins_sel_count' => {
        'std_metric' => 'insert_select_state_sec',
        'output' => 'INSERT/SELECT Statements per Second',
        'label' => 'state-ins_sel-sec',
        'nlabel' => 'rds.statement.insert_select.sec',
        'unit','q/s'
    },
    'rds031_comdml_rep_count' => {
        'std_metric' => 'replace_state_sec',
        'output' => 'REPLACE Statements per Second',
        'label' => 'state-ins_sel-sec',
        'nlabel' => 'rds.statement.replace.sec',
        'unit','q/s'
    },
    'rds032_comdml_rep_sel_count' => {
        'std_metric' => 'replace_selection_state_sec',
        'output' => 'REPLACE_SELECTION Statements per Second',
        'label' => 'state-rep_sel-sec',
        'nlabel' => 'rds.statement.replace_selection.sec',
        'unit','q/s'
    },
    'rds033_comdml_sel_count' => {
        'std_metric' => 'select_state_sec',
        'output' => 'SELECT Statements per Second',
        'label' => 'state-sel-sec',
        'nlabel' => 'rds.statement.select.sec',
        'unit','q/s'
    },
    'rds034_comdml_upd_count' => {
        'std_metric' => 'update_state_sec',
        'output' => 'UPDATE Statements per Second',
        'label' => 'state-up-sec',
        'nlabel' => 'rds.statement.update.sec',
        'unit','q/s'
    },
);



sub prefix_metric_output {
    my ($self, %options) = @_;
    
    return "RDS '".$options{instance_value}->{type}." ".$options{instance_value}->{display} . "' ";
}

sub prefix_statistics_output {
    my ($self, %options) = @_;
    
    return "Statistic '" . $options{instance_value}->{display} . "' Metrics ";
}

sub long_output {
    my ($self, %options) = @_;

    return "Checking RDS '".$options{instance_value}->{type}." " . $options{instance_value}->{display} . "' ";
}

sub custom_metric_calc {
    my ($self, %options) = @_;
    
    $self->{result_values}->{timeframe} = $options{new_datas}->{$self->{instance} . '_timeframe'};
    $self->{result_values}->{value} = $options{new_datas}->{$self->{instance} . '_' . $options{extra_options}->{metric}};
    $self->{result_values}->{metric} = $options{extra_options}->{metric};
    return 0;
}

sub custom_metric_threshold {
    my ($self, %options) = @_;

    my $exit = $self->{perfdata}->threshold_check(
        value => $self->{result_values}->{value},
        threshold => [ { label => 'critical-' . $metrics_mapping{$self->{result_values}->{metric}}->{label}, exit_litteral => 'critical' },
                       { label => 'warning-' . $metrics_mapping{$self->{result_values}->{metric}}->{label}, exit_litteral => 'warning' } ]);
    return $exit;
}

sub custom_metric_perfdata {
    my ($self, %options) = @_;
    $self->{output}->perfdata_add(
        instances => $self->{instance},
        label => $metrics_mapping{$self->{result_values}->{metric}}->{label},
        nlabel => $metrics_mapping{$self->{result_values}->{metric}}->{nlabel},
        unit => $metrics_mapping{$self->{result_values}->{metric}}->{unit},
        value => sprintf("%.2f", $self->{result_values}->{value}),
        warning => $self->{perfdata}->get_perfdata_for_output(label => 'warning-' . $metrics_mapping{$self->{result_values}->{metric}}->{label}),
        critical => $self->{perfdata}->get_perfdata_for_output(label => 'critical-' . $metrics_mapping{$self->{result_values}->{metric}}->{label}),
    );
}

sub custom_metric_output {
    my ($self, %options) = @_;
    my $msg = "";
        my ($value, $unit) = ($self->{result_values}->{value}, $metrics_mapping{$self->{result_values}->{metric}}->{unit});
        $msg = sprintf("%s: %.2f %s", $metrics_mapping{$self->{result_values}->{metric}}->{output}, $value, $unit);
    
    return $msg;
}


sub set_counters {
    my ($self, %options) = @_;
    
    $self->{maps_counters_type} = [
        { name => 'metrics', type => 3, cb_prefix_output => 'prefix_metric_output', cb_long_output => 'long_output',
          message_multiple => 'All queries metrics are ok', indent_long_output => '    ',
            group => [
                { name => 'statistics', display_long => 1, cb_prefix_output => 'prefix_statistics_output',
                  message_multiple => 'All metrics are ok', type => 1, skipped_code => { -10 => 1 } },
            ]
        }
    ];

    foreach my $metric (keys %metrics_mapping) {
        my $entry = {
            label => $metrics_mapping{$metric}->{label},
            set => {
                key_values => [ { name => $metric }, { name => 'timeframe' }, { name => 'display' } ],
                closure_custom_calc => $self->can('custom_metric_calc'),
                closure_custom_calc_extra_options => { metric => $metric},
                closure_custom_output => $self->can('custom_metric_output'),
                closure_custom_perfdata => $self->can('custom_metric_perfdata'),
                closure_custom_threshold_check => $self->can('custom_metric_threshold'),

            }
        };
        push @{$self->{maps_counters}->{statistics}}, $entry;
    }
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_nefilter_metricw_perfdata => 1);
    bless $self, $class;
    
    $options{options}->add_options(arguments => {
        "instance-id:s@"	        => { name => 'name' },
        "engine:s"	        => { name => 'engine' },
        "type:s"	        => { name => 'type' },
        "filter-metric:s"   => { name => 'filter_metric' },
        'filter:s'    => { name => 'filter' },
    });
    
    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::check_options(%options);


    if (!defined($self->{option_results}->{name}) || $self->{option_results}->{name} eq '') {
        $self->{output}->add_option_msg(short_msg => "Need to specify --instance-id option.");
        $self->{output}->option_exit();
    }

    foreach my $instance (@{$self->{option_results}->{name}}) {
        if ($instance ne '') {
            push @{$self->{ces_instance}}, $instance;
        }
    }

    if (!defined($self->{option_results}->{type}) || $self->{option_results}->{type} eq '') {
        $self->{output}->add_option_msg(short_msg => "Need to specify --type option.");
        $self->{output}->option_exit();
    }

    if ($self->{option_results}->{engine} ne lc 'mysql') {
        $self->{output}->add_option_msg(short_msg => "MySQL Engine is only Supported.");
        $self->{output}->option_exit();
    }

        $self->{dimension_name} = 'rds_'.lc $self->{option_results}->{type}.'_id';



    $self->{ces_period} = defined($self->{option_results}->{period}) ? $self->{option_results}->{period} : 1;
    $self->{ces_frame} = defined($self->{option_results}->{frame}) ? $self->{option_results}->{frame} : 14400;
    
    $self->{ces_filter} = 'average';
    if (defined($self->{option_results}->{filter})) {
        $self->{ces_filter} =$self->{option_results}->{filter};
    }

    foreach my $metric (keys %metrics_mapping) {
        next if (defined($self->{option_results}->{filter_metric}) && $self->{option_results}->{filter_metric} ne ''
            && $metrics_mapping{$metric}->{std_metric} !~ /$self->{option_results}->{filter_metric}/);

        push @{$self->{ces_metrics}}, $metric;
    }

}

 sub manage_selection {
    my ($self, %options) = @_;

    my %metric_results;
    foreach my $instance (@{$self->{ces_instance}}) {
                print Dumper($self->{dimension_name});

        $metric_results{$instance} = $options{custom}->api_cloudeyes_get_metric(
            namespace => 'SYS.RDS',
            dimensions => [ { name => $self->{dimension_name}, value => $instance } ],
            metrics => $self->{ces_metrics},
            filter => $self->{ces_filter},
            frame => $self->{ces_frame},
            period => $self->{ces_period},
        );

        foreach my $metric (@{$self->{ces_metrics}}) {
                 my $statistic = $self->{ces_filter};
                next if (!defined($metric_results{$instance}->{$metric}->{lc($statistic)}) &&
                    !defined($self->{option_results}->{zeroed}));

                $self->{metrics}->{$instance}->{display} = $instance;
                $self->{metrics}->{$instance}->{statistics}->{lc($statistic)}->{display} = $statistic;
                $self->{metrics}->{$instance}->{statistics}->{lc($statistic)}->{timeframe} = $self->{ces_frame};
                $self->{metrics}->{$instance}->{statistics}->{lc($statistic)}->{$metric} = 
                    defined($metric_results{$instance}->{$metric}->{lc($statistic)}) ? 
                    $metric_results{$instance}->{$metric}->{lc($statistic)} : 0;
            
        }
    }
    if (scalar(keys %{$self->{metrics}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => 'No metrics. Check your options or use --zeroed option to set 0 on undefined values');
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check RDS instances Queries metrics.

Example: 
perl centreon_plugins.pl --plugin=cloud::flexibleengine::rds::plugin  --mode=queries --region='eu-west-0'
--type='cluster' --engine='sqlserver' --instance_id='30191908-bf15-44e8-bf5c-ffa121bbd4ea' --filter=average
--critical-cpu-utilization=80 --verbose

More doc about these metrics : https://docs.prod-cloud-ocb.orange-business.com/usermanual/rds/rds_06_0001.html

Default statistic: 'average' / All statistics are valid.

MySQL Engine Only !

=over 8

=item B<--instance-id>

Set the instance id (Required).

=item B<--type>

Set the type (Required)
Possible Value : instance, cluster

=item B<--warning-*> B<--critical-*>

Thresholds warning & critical.
Valid input is 

=back

=cut
