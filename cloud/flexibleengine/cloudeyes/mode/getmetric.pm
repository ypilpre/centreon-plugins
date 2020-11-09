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

package cloud::flexibleengine::cloudeyes::mode::getmetric;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use Data::Dumper;

sub custom_metric_perfdata {
    my ($self, %options) = @_;

    $self->{output}->perfdata_add(
        label => $self->{result_values}->{perf_label},
        value => $self->{result_values}->{value},
        warning => $self->{perfdata}->get_perfdata_for_output(label => 'warning-metric'),
        critical => $self->{perfdata}->get_perfdata_for_output(label => 'critical-metric'),
    );
}

sub custom_metric_threshold {
    my ($self, %options) = @_;

    my $exit = $self->{perfdata}->threshold_check(
        value => $self->{result_values}->{value},
        threshold => [
            { label => 'critical-metric', exit_litteral => 'critical' },
            { label => 'warning-metric', exit_litteral => 'warning' }
        ]
    );
    return $exit;
}


sub custom_metric_output {
    my ($self, %options) = @_;

    my $msg = "Metric '" . $self->{result_values}->{display}  . "' value is " . $self->{result_values}->{value};
    return $msg;
}

sub custom_metric_calc {
    my ($self, %options) = @_;

    $self->{result_values}->{value} = $options{new_datas}->{$self->{instance} . '_value'};
    $self->{result_values}->{perf_label} = $options{new_datas}->{$self->{instance} . '_perf_label'};
    $self->{result_values}->{display} = $options{new_datas}->{$self->{instance} . '_display'};
    return 0;
}


sub set_counters {
    my ($self, %options) = @_;
    
    $self->{maps_counters_type} = [
        { name => 'metrics', type => 1, message_multiple => 'All metrics are ok' },
    ];
    
    $self->{maps_counters}->{metrics} = [
        { label => 'metric', set => {
                key_values => [ { name => 'value' }, { name => 'perf_label' }, { name => 'display' } ],
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
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;

    $options{options}->add_options(arguments => {
        'namespace:s'  => { name => 'namespace' },
        'dimension:s' => { name => 'dimension' },
        'metric:s'    => { name => 'metric' },
        'filter:s'    => { name => 'filter' },
        'period:s'    => { name => 'period' },
        'frame:s'    => { name => 'frame' },

    });

    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::check_options(%options);

    if (!defined($self->{option_results}->{namespace}) || $self->{option_results}->{namespace} eq '') {
        $self->{output}->add_option_msg(short_msg => "Need to specify --namespace option.");
        $self->{output}->option_exit();
    }

    if (!defined($self->{option_results}->{metric})) {
        $self->{output}->add_option_msg(short_msg => "Need to specify --metric option.");
                $self->{output}->option_exit();

    }
    if (!defined($self->{option_results}->{dimension})) {
        $self->{output}->add_option_msg(short_msg => "Need to specify --dimension option.");
        $self->{output}->option_exit();
    }

    $self->{ces_period} = defined($self->{option_results}->{period}) ? $self->{option_results}->{period} : 1;
    $self->{ces_frame} = defined($self->{option_results}->{frame}) ? $self->{option_results}->{frame} : 14400;
  

     if (!defined($self->{option_results}->{filter})) {
        $self->{output}->add_option_msg(short_msg => "Need to specify --filter option.");
        $self->{output}->option_exit();
    }
}

sub manage_selection {
    my ($self, %options) = @_;

    my $metric_results = $options{custom}->api_cloudeyes_get_metric(
        namespace => $self->{option_results}->{namespace},
        dimension => $self->{option_results}->{dimension},
        metric => $self->{option_results}->{metric},
        filter => $self->{option_results}->{filter},
        period => $self->{ces_period},
        frame => $self->{ces_frame},
    );
    $self->{metrics} = {};
    foreach my $label (keys %{$metric_results}) {
        foreach my $stat (('min', 'max', 'average', 'sum','variance')) {
            next if (!defined($metric_results->{$label}->{$stat}));
            
            $self->{metrics}->{$self->{option_results}->{dimension} . '_' . $label . '_' . $stat} = {
                display => $self->{option_results}->{dimension} . '_' . $label . '_' . $stat,
                value => $metric_results->{$label}->{$stat},
                perf_label => $label . '_' . $stat,
            };
        }
    }
}

1;

__END__

=head1 MODE

Check Cloudeyes single metric (single and namespace).

Example: 
perl centreon_plugins.pl --plugin=cloud::flexibleengine::plugin --mode=cloudeyes-get-metric --region=eu-west-1
--namespace=SYS.ECS --dimension=instanceid,i-01622936185e32a45 --metric=cpu_util --filter=average 
--period=60 --timeframe=600 --warning-metric= --critical-metric=

=over 8

=item B<--namespace>

Set cloudeyes namespace (Required).

=item B<--dimension>

Set cloudeyes dimension (Required).
Format : key,value

=item B<--metric>

Set cloudeyes metric (Required).

=item B<--period>

Set cloudeyes period graularity (Default : 1).
Value can be : 1, 300, 1200, 3600, 14400, 86400

=item B<--frame>

Set cloudeyes frame of time graularity in second(Default : 3600).
Must Follow this Notice
https://docs.prod-cloud-ocb.orange-business.com/en-us/api/ces/ces_03_0034.html

=item B<--warning-metric>

Threshold warning.

=item B<--critical-metric>

Threshold critical.

=back

=cut
