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

package cloud::flexibleengine::dds::mode::iops;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;

my %metrics_mapping = (
    'mongo036_iops' => {
        'output' => 'I/O per second',
        'label' => 'IOPS',
        'nlabel' => 'dds.io.sec',
        'unit','/s'
    }
);



sub prefix_metric_output {
    my ($self, %options) = @_;
    
    return "DDS Node '".$options{instance_value}->{display} . "' ";
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
          message_multiple => 'All IOPS metrics are ok', indent_long_output => '    ',
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
                key_values => [ { name => $metric} , { name => 'display' } ],
                output_template => $metrics_mapping{$metric}->{output} . ': %.d/s',
                perfdatas => [
                    { value => $metric , unit => '/s', min => 0,  label_extra_instance => 1, instance_use => 'display'}
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
        "node-id:s"	        => { name => 'node_id' },
        "role:s"	        => { name => 'role' },
        "filter-metric:s"   => { name => 'filter_metric' },
        'filter:s'    => { name => 'filter' },
    });
    
    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::check_options(%options);


    if (!defined($self->{option_results}->{node_id}) || $self->{option_results}->{node_id} eq '') {
        $self->{output}->add_option_msg(short_msg => "Need to specify --node-id option.");
        $self->{output}->option_exit();
    }

    if (!defined($self->{option_results}->{role}) || $self->{option_results}->{role} eq '' ) {
        $self->{output}->add_option_msg(short_msg => "Need to specify --role option (primary or secondary).");
        $self->{output}->option_exit();
    }



    $self->{ces_instance} = $self->{option_results}->{node_id};
    
    $self->{dimension_name} = 'mongod_'.lc $self->{option_results}->{role}.'_instance_id';
    


    $self->{ces_period} = defined($self->{option_results}->{period}) && $self->{option_results}->{period} ne '' ? $self->{option_results}->{period} : 1;
    $self->{ces_frame} = defined($self->{option_results}->{frame}) && $self->{option_results}->{frame} ne '' ? $self->{option_results}->{frame} :  14400;
    
    $self->{ces_filter} = 'average';
    if (defined($self->{option_results}->{filter}) &&  $self->{option_results}->{filter} ne ''){
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

        $metric_results{$self->{ces_instance}} = $options{custom}->api_cloudeyes_get_metric(
            namespace => 'SYS.DDS',
            dimensions => [ { name => $self->{dimension_name}, value => $self->{ces_instance} } ],
            metrics => $self->{ces_metrics},
            filter => $self->{ces_filter},
            frame => $self->{ces_frame},
            period => $self->{ces_period},
        );
        foreach my $metric (@{$self->{ces_metrics}}) {
                 my $statistic = $self->{ces_filter};
                next if (!defined($metric_results{$self->{ces_instance}}->{$metric}->{lc($statistic)}) &&
                    !defined($self->{option_results}->{zeroed}));

                $self->{metrics}->{$self->{ces_instance}}->{display} = $self->{ces_instance};
                $self->{metrics}->{$self->{ces_instance}}->{type} = $self->{option_results}->{type};
                $self->{metrics}->{$self->{ces_instance}}->{engine} = $self->{option_results}->{engine};
                $self->{metrics}->{$self->{ces_instance}}->{statistics}->{lc($statistic)}->{display} = $statistic;
                $self->{metrics}->{$self->{ces_instance}}->{statistics}->{lc($statistic)}->{$metric} = 
                    defined($metric_results{$self->{ces_instance}}->{$metric}->{lc($statistic)}) ? 
                    $metric_results{$self->{ces_instance}}->{$metric}->{lc($statistic)} : 0;
        }


    if (scalar(keys %{$self->{metrics}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => 'No metrics. Check your options or use --zeroed option to set 0 on undefined values');
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check DDS instances CPU metrics.

Example: 
perl centreon_plugins.pl --plugin=cloud::flexibleengine::dds::plugin  --mode=cpu --region='eu-west-0'
--type='cluster' --engine='sqlserver' --node-id='30191908-bf15-44e8-bf5c-ffa121bbd4ea' --role=primary --filter=average
--critical-cpu-utilization=80 --verbose

Default statistic: 'average' / All statistics are valid.

=over 8

=item B<--node-id>

Set the DDS node id (Required). Not the MongoDB ID !

=item B<--role>

Set the role of the Node
Possible value : primary, secondary

=item B<--warning-*> B<--critical-*>

Thresholds warning & critical.
Valid input is cpu-utilization

=back

=cut