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

package cloud::flexibleengine::rds::mode::cpu;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;

my %metrics_mapping = (
    'rds001_cpu_util' => {
        'std_metric' => 'cpu_util',
        'output' => 'CPU Utilization',
        'label' => 'cpu-utilization',
        'nlabel' => 'rds.cpu.utilization.percentage',
    }
);



sub prefix_metric_output {
    my ($self, %options) = @_;
    
    return "'".$options{instance_value}->{type}." ".$options{instance_value}->{engine} ." ".$options{instance_value}->{display} . "' ";
}

sub prefix_statistics_output {
    my ($self, %options) = @_;
    
    return "Statistic '" . $options{instance_value}->{display} . "' Metric ";
}

sub long_output {
    my ($self, %options) = @_;

    return "Checking '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;
    
    $self->{maps_counters_type} = [
        { name => 'metrics', type => 3, cb_prefix_output => 'prefix_metric_output', cb_long_output => 'long_output',
          message_multiple => 'All CPU metrics are ok', indent_long_output => '    ',
            group => [
                { name => 'statistics', display_long => 1, cb_prefix_output => 'prefix_statistics_output',
                  message_multiple => 'All metrics are ok', type => 1, skipped_code => { -10 => 1 } },
            ]
        }
    ];

    foreach my $metric (keys %metrics_mapping) {
        my $entry = {
            label => $metrics_mapping{$metric}->{label},
            nlabel => $metrics_mapping{$metric}->{nlabel},
            set => {
                key_values => [ { name => $metric} }, { name => 'display' } ],
                output_template => $metrics_mapping{$metric}->{output} . ': %.2f%%',
                perfdatas => [
                    { value => $metric , unit => '%', min => 0, max => 100, label_extra_instance => 1, instance_use => 'display'}
                ],
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

    if (!defined($self->{option_results}->{engine}) || $self->{option_results}->{engine} eq '') {
        $self->{output}->add_option_msg(short_msg => "Need to specify --engine option.");
        $self->{output}->option_exit();
    }

        if (lc $self->{option_results}->{engine} eq 'mysql'){
        $self->{dimension_name} = 'rds_'.$self->{option_results}->{type}.'_id';
    }

    if (lc $self->{option_results}->{engine} eq 'postgresql'){
        $self->{dimension_name} = $self->{option_results}->{engine}.'_'.$self->{option_results}->{type}.'_id';
    }

    if (lc $self->{option_results}->{engine} eq 'sqlserver'){
        $self->{dimension_name} = 'rds_'.$self->{option_results}->{type}.'_'.$self->{option_results}->{engine}.'_id';
    }



    $self->{ces_period} = defined($self->{option_results}->{period}) ? $self->{option_results}->{period} : 1;
    $self->{ces_frame} = defined($self->{option_results}->{frame}) ? $self->{option_results}->{frame} : 14400;
    
    $self->{ces_filter} = 'average';
    if (defined($self->{option_results}->{filter})) {
        $self->{ces_filter} =$self->{option_results}->{filter};
    }

    foreach my $metric (keys %metrics_mapping) {
        next if (defined($self->{option_results}->{filter_metric}) && $self->{option_results}->{filter_metric} ne ''
            && $metrics_mapping{$metric}->{std_metric} !~ /$self->{option_results}->{filter_metric}/);

        push @{$self->{ces_metrics}}, $metric ;
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
                $self->{metrics}->{$instance}->{type} = $self->{option_results}->{type};
                $self->{metrics}->{$instance}->{engine} = $self->{option_results}->{engine};
                $self->{metrics}->{$instance}->{statistics}->{lc($statistic)}->{display} = $statistic;
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

Check RDS instances CPU metrics.

Example: 
perl centreon_plugins.pl --plugin=cloud::flexibleengine::rds::plugin  --mode=cpu --region='eu-west-0'
--type='cluster' --engine='sqlserver' --instance_id='30191908-bf15-44e8-bf5c-ffa121bbd4ea' --filter=average
--critical-cpu-utilization=80 --verbose

Default statistic: 'average' / All satistics are valid.

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
Valid input is cpu-utilization

=back

=cut
