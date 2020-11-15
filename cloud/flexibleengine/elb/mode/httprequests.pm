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

package cloud::flexibleengine::elb::mode::httprequests;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;

my %metrics_mapping = (
    'mb_l7_qps' => {
        'output' => 'Layer-7 Query Rate',
        'label' => 'l7-query-rate',
        'nlabel' => 'elb.l7.querypersecond',
        'unit' => 'q/s'
    },
    'mc_l7_http_2xx' => {
        'output' => '2xx Status Codes',
        'label' => 'l7-http-2xx',
        'nlabel' => 'elb.l7.http.2xx.persecond',
        'unit' => 'c/s',
    },
    'md_l7_http_3xx' => {
        'output' => '3xx Status Codes',
        'label' => 'l7-http-3xx',
        'nlabel' => 'elb.l7.http.3xx.persecond',
        'unit' => 'c/s',
    },
    'me_l7_http_4xx' => {
        'output' => '4xx Status Codes',
        'label' => 'l7-http-4xx',
        'nlabel' => 'elb.l7.http.4xx.persecond',
        'unit' => 'c/s',
    },
    'mf_l7_http_5xx' => {
        'output' => '5xx Status Codes',
        'label' => 'l7-http-5xx',
        'nlabel' => 'elb.l7.http.5xx.persecond',
        'unit' => 'c/s',
    },
    'm10_l7_http_other_status' => {
        'output' => 'Other Status Codes',
        'label' => 'l7-http-other',
        'nlabel' => 'elb.l7.http.other.persecond',
        'unit' => 'c/s',
    },
    'm11_l7_http_404' => {
        'output' => '404 Status Codes',
        'label' => 'l7-http-404',
        'nlabel' => 'elb.l7.http.404.persecond',
        'unit' => 'c/s',
    },
    'm12_l7_http_499' => {
        'output' => '499 Status Codes',
        'label' => 'l7-http-499',
        'nlabel' => 'elb.l7.http.499.persecond',
        'unit' => 'c/s',
    },
    'm13_l7_http_502' => {
        'output' => '502 Status Codes',
        'label' => 'l7-http-502',
        'nlabel' => 'elb.l7.http.502.persecond',
        'unit' => 'c/s',
    },
    'm14_l7_rt' => {
        'output' => 'Average Layer-7 Response Time',
        'label' => 'l7-reponse-time',
        'nlabel' => 'elb.l7.reponsetime.ms',
        'unit' => 'ms',
    },

);

sub prefix_metric_output {
    my ($self, %options) = @_;
    
    return "elb '" . $options{instance_value}->{display} . "' ";
}

sub prefix_statistics_output {
    my ($self, %options) = @_;
    
    return "Statistic '" . $options{instance_value}->{display} . "' Metrics ";
}

sub long_output {
    my ($self, %options) = @_;

    return "Checking ELB '" . $options{instance_value}->{display} . "' ";
}

sub custom_metric_calc {
    my ($self, %options) = @_;
    
    $self->{result_values}->{timeframe} = $options{new_datas}->{$self->{instance} . '_timeframe'};
    $self->{result_values}->{value} = $options{new_datas}->{$self->{instance} . '_' . $options{extra_options}->{metric}};
    $self->{result_values}->{value_per_sec} = $self->{result_values}->{value} / $self->{result_values}->{timeframe};
    $self->{result_values}->{metric} = $options{extra_options}->{metric};
    return 0;
}

sub custom_metric_threshold {
    my ($self, %options) = @_;

    my $exit = $self->{perfdata}->threshold_check(
        value => defined($self->{instance_mode}->{option_results}->{per_sec}) ? $self->{result_values}->{value_per_sec} : $self->{result_values}->{value},
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
          message_multiple => 'All L7 metrics are ok', indent_long_output => '    ',
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
                closure_custom_calc_extra_options => { metric => $metric },
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
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;
    
    $options{options}->add_options(arguments => {
        "instance-id:s@"	        => { name => 'instance_id' },
        "listener:s"	        => { name => 'listener' },
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

    $self->{ces_period} = defined($self->{option_results}->{period}) ? $self->{option_results}->{period} : 1;
    $self->{ces_frame} = defined($self->{option_results}->{frame}) ? $self->{option_results}->{frame} : 3600;
    
    $self->{ces_filter} = 'average';
    if (defined($self->{option_results}->{filter})) {
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
            namespace => 'SYS.ELB',
            dimensions => [ { name => 'lbaas_'.(defined($self->{option_results}->{listener})?'listener':'instance').'_id', value => $instance } ],
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

Check ELB instances HTTP Code metrics.

Example: 
perl centreon_plugins.pl --plugin=cloud::flexibleengine::elb::plugin  --mode=traffic --region='eu-west-0'
 --instance-id='28616721-d001-480b-99d0-deccacf414e7' --filter-metric='2xx' --statistic='average'
--critical-network-packets-out='10' --verbose

See 'https://support.huaweicloud.com/intl/en-us/usermanual-elb/elb_ug_jk_0001.html' for more informations.

Default statistic: 'average' / All statistics are valid.

=over 8

=item B<--instance-id>

Set the instance id (Required) (Can be multiple).

=item B<--listenerd>

Set the flag for checking a listener instead of a ELB.
(Cannot be used with an ELB instance-id)

=item B<--filter-metric>

Filter metrics 
(Can be a regexp).

=item B<--warning-*> B<--critical-*>

Thresholds warning 

=back

=cut
