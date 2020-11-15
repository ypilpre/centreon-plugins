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

package cloud::flexibleengine::rds::mode::connections;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;

my %engine_mapping = (
    'mysql' => {
        'metric' => 'rds007_conn_active_count',
    },
    'postgresql' => {
        'metric' => 'rds042_database_connections',
    },
    'sqlserver' => {
        'metric' => 'rds054_db_connections_in_use',
    },
);



sub prefix_metric_output {
    my ($self, %options) = @_;
    
    return " RDS '" . $options{instance_value}->{display} . "' ";
}

sub prefix_statistics_output {
    my ($self, %options) = @_;
    
    return "Statistic '" . $options{instance_value}->{display} . "' Metrics ";
}

sub long_output {
    my ($self, %options) = @_;

    return "Checking RDS '" . $options{instance_value}->{display} . "' ";
}

sub custom_metric_calc {
    my ($self, %options) = @_;
    
    $self->{result_values}->{timeframe} = $options{new_datas}->{$self->{instance} . '_timeframe'};
    $self->{result_values}->{value} = $options{new_datas}->{$self->{instance} . '_connections'};
    $self->{result_values}->{metric} = 'connections';
    return 0;
}

sub custom_metric_threshold {
    my ($self, %options) = @_;

    my $exit = $self->{perfdata}->threshold_check(
        value => $self->{result_values}->{value},
        threshold => [ { label => 'critical-connections', exit_litteral => 'critical' },
                       { label => 'warning-connections', exit_litteral => 'warning' } ]);
    return $exit;
}

sub custom_metric_perfdata {
    my ($self, %options) = @_;
    $self->{output}->perfdata_add(
        instances => $self->{instance},
        label => 'connections',
        nlabel => 'rds.connections.count',
        unit => '',
        value => sprintf("%.d", $self->{result_values}->{value}),
        warning => $self->{perfdata}->get_perfdata_for_output(label => 'warning-connections'),
        critical => $self->{perfdata}->get_perfdata_for_output(label => 'critical-connections'),
    );
}

sub custom_metric_output {
    my ($self, %options) = @_;
    my $msg = "";

        my ($value, $unit) = ($self->{result_values}->{value}, '');
        $msg = sprintf("%s: %d %s", 'Database Connections in Use', $value, $unit);
    
    return $msg;
}

sub set_counters {
    my ($self, %options) = @_;
    
    $self->{maps_counters_type} = [
        { name => 'metrics', type => 3, cb_prefix_output => 'prefix_metric_output', cb_long_output => 'long_output',
          message_multiple => 'All DB Connections metrics are ok', indent_long_output => '    ',
            group => [
                { name => 'statistics', display_long => 1, cb_prefix_output => 'prefix_statistics_output',
                  message_multiple => 'All metrics are ok', type => 1, skipped_code => { -10 => 1 } },
            ]
        }
    ];

        $self->{maps_counters}->{statistics} = [{
            label => 'connections',nlabel => 'rds.connections.count',
            set => {
                key_values => [ { name => 'connections' }, { name => 'timeframe' }, { name => 'display' } ],
                closure_custom_calc => $self->can('custom_metric_calc'),
                closure_custom_output => $self->can('custom_metric_output'),
                closure_custom_perfdata => $self->can('custom_metric_perfdata'),
                closure_custom_threshold_check => $self->can('custom_metric_threshold'),
            }
            }
        ];
       
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_nefilter_metricw_perfdata => 1);
    bless $self, $class;
    
    $options{options}->add_options(arguments => {
        "instance-id:s@"	        => { name => 'instance_id' },
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


    if (!defined($self->{option_results}->{instance_id}) || $self->{option_results}->{instance_id} eq '') {
        $self->{output}->add_option_msg(short_msg => "Need to specify --instance-id option.");
        $self->{output}->option_exit();
    }

    foreach my $instance (@{$self->{option_results}->{instance_id}}) {
        if ($instance ne '') {
            push @{$self->{ces_instance}}, $instance;
        }
    }

    if (!defined($self->{option_results}->{engine}) || $self->{option_results}->{engine} eq '') {
        $self->{output}->add_option_msg(short_msg => "Need to specify --engine option.");
        $self->{output}->option_exit();
    }

    if (!defined($self->{option_results}->{type}) || $self->{option_results}->{type} eq '') {
        $self->{output}->add_option_msg(short_msg => "Need to specify --type option.");
        $self->{output}->option_exit();
    }

        $self->{dimension_name} = 'rds_'.lc $self->{option_results}->{type}.'_id';



    $self->{ces_period} = defined($self->{option_results}->{period}) ? $self->{option_results}->{period} : 1;
    $self->{ces_frame} = defined($self->{option_results}->{frame}) ? $self->{option_results}->{frame} : 3600;
    
    $self->{ces_filter} = 'average';
    if (defined($self->{option_results}->{filter})) {
        $self->{ces_filter} =$self->{option_results}->{filter};
    }

        foreach my $engine (keys %engine_mapping) {
        next if ($engine ne $self->{option_results}->{engine} );
        push @{$self->{ces_metrics}}, $engine_mapping{$engine}->{metric};
    }


}

sub manage_selection {
    my ($self, %options) = @_;

    my %metric_results;
    foreach my $instance (@{$self->{ces_instance}}) {
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
                $self->{metrics}->{$instance}->{statistics}->{lc($statistic)}->{'connections'} = 
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

Check RDS instances Transaction metrics.

Example: 
perl centreon_plugins.pl --plugin=cloud::flexibleengine::rds::plugin  --mode=cpu --region='eu-west-0'
--type='cluster' --engine='sqlserver' --instance_id='30191908-bf15-44e8-bf5c-ffa121bbd4ea' --filter=average
--critical-cpu-utilization=80 --verbose

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
Valid input is cpu-utilization

=back

=cut
