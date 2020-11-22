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

package cloud::flexibleengine::css::mode::cpu;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;

my %metrics_mapping = (
    'max_cpu_usage' => {
        'output' => 'Max CPU Usage',
        'label' => 'max-cpu-usage',
        'nlabel' => 'css.cpu.max.usage',
        'unit' => '%'
    }

);

sub prefix_metric_output {
    my ($self, %options) = @_;
    
    return "css '" . $options{instance_value}->{display} . "' ";
}

sub prefix_statistics_output {
    my ($self, %options) = @_;
    
    return "Statistic '" . $options{instance_value}->{display} . "' Metrics ";
}

sub long_output {
    my ($self, %options) = @_;

    return "Checking CSS '" . $options{instance_value}->{display} . "' ";
}


sub custom_metric_output {
    my ($self, %options) = @_;
    my $msg = "";

        my ($value, $unit) = ($self->{result_values}->{value}, $metrics_mapping{$self->{result_values}->{metric}}->{unit});
        $msg = sprintf("%s: %d %s", $metrics_mapping{$self->{result_values}->{metric}}->{output}, $value, $unit);
    
    return $msg;
}


sub set_counters {
    my ($self, %options) = @_;
    
    $self->{maps_counters_type} = [
        { name => 'metrics', type => 3, cb_prefix_output => 'prefix_metric_output', cb_long_output => 'long_output',
          message_multiple => 'All Connections are ok', indent_long_output => '    ',
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
                key_values => [ { name => $metric }, { name => 'display' } ],
                output_template => $metrics_mapping{$metric}->{output} . ': %d'.$metrics_mapping{$metric}->{unit},
                perfdatas => [
                    { value => $metric , unit=> $metrics_mapping{$metric}->{unit},template => '%d', label_extra_instance => 1 }
                ],
            }
        };
        push @{$self->{maps_counters}->{statistics}}, $entry;
    }
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;
    
    $options{options}->add_options(arguments => {
        "instance-id:s@"	        => { name => 'instance_id' },
        "filter-metric:s"   => { name => 'filter_metric' },
        "filter:s"    => { name => 'filter' },
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

    foreach my $metric (keys %metrics_mapping) {
        next if (defined($self->{option_results}->{filter_metric}) && $self->{option_results}->{filter_metric} ne ''
            && $metric !~ /$self->{option_results}->{filter_metric}/);

        push @{$self->{ces_metrics}}, $metric;
    }
}

sub manage_selection {
    my ($self, %options) = @_;

    my %metric_results;
    foreach my $instance (@{$self->{ces_instance}}) {
        $metric_results{$instance} = $options{custom}->api_cloudeyes_get_metric(
            namespace => 'SYS.ES',
            dimensions => [ { name => 'cluster_id', value => $instance } ],
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

Check CSS Clusters instances CPU

Example: 
perl centreon_plugins.pl --plugin=cloud::flexibleengine::css::plugin  --mode=cpu --region='eu-west-0'
 --instance-id='28616721-d001-480b-99d0-deccacf414e7' --filter-metric='Shards' --statistic='average'
--critical-shards-count='10' --verbose

See 'https://support.huaweicloud.com/intl/en-us/usermanual-css/css_01_0042.html' for more informations.

Default statistic: 'average' / All statistics are valid.

=over 8

=item B<--instance-id>

Set the instance id (Required) (Can be multiple).

=item B<--filter-metric>

Filter metrics (Can be 'max-cpu-usage', )
(Can be a regexp).

=item B<--warning-*> B<--critical-*>

Thresholds warning (Can be 'max-cpu-usage')

=back

=cut
