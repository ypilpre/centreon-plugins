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

package cloud::flexibleengine::evs::mode::diskio;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;


my %metrics_mapping = (
    'disk_device_read_bytes_rate' => {
        'output' => 'Disk Read Bytes Rate',
        'label' => 'disk-write-bytes-rate',
        'nlabel' => 'evs.disk.bytes.read.bytespersecond',
        'unit' => 'B/s',
    },
    'disk_device_write_bytes_rate' => {
        'output' => 'Disk Write Bytes Rate',
        'label' => 'disk-write-bytes-rate',
        'nlabel' => 'evs.disk.bytes.write.bytespersecond',
        'unit' => 'B/s',
    },
    'disk_device_read_requests_rate' => {
        'output' => 'Disk Write Ops',
        'label' => 'disk-write-ops',
        'nlabel' => 'evs.disk.ops.write.request.seconds',
        'unit' => 'ops',
    },
    'disk_device_write_requests_rate' => {
        'output' => 'Disk Read Ops',
        'label' => 'disk-read-ops',
        'nlabel' => 'evs.disk.ops.read.request.seconds',
        'unit' => 'ops',
    },
    'disk_device_read_bytes_per_operation' => {
        'output' => 'Avg Disk Bytes Per Write',
        'label' => 'disk-device-read-bytes-per-operation',
        'nlabel' => 'evs.disk.bytes.read.ops.seconds',
        'unit' => 'KB/s',
    },
    'disk_device_read_await' => {
        'output' => 'Disk Write Await',
        'label' => 'disk-device-read-await-per-mseconds',
        'nlabel' => 'evs.disk.ms.wait.read.seconds',
        'unit' => 'KB/s',
    },
    'disk_device_queue_length' => {
        'output' => 'Average Queue Length',
        'label' => 'disk-device-wait-queue-lenth',
        'nlabel' => 'evs.disk.queue.wait.length',
        'unit' => 'req',
    },
    'disk_device_io_util' => {
        'output' => 'Disk I/O Utilization',
        'label' => 'disk-device-io-usage',
        'nlabel' => 'evs.disk.io.usage',
        'unit' => '%',
    },
    'disk_device_io_svctm' => {
        'output' => 'Disk I/O Service Time',
        'label' => 'disk-device-io-service-time',
        'nlabel' => 'evs.disk.io.service.time',
        'unit' => 'ms/op',
    },

);

sub prefix_metric_output {
    my ($self, %options) = @_;
    
    return " evs '" . $options{instance_value}->{display} . "' ";
}

sub prefix_statistics_output {
    my ($self, %options) = @_;
    return "Statistic '" . $options{instance_value}->{display} . "' Metrics ";
}

sub long_output {
    my ($self, %options) = @_;

    return "Checking evs '" . $options{instance_value}->{display} . "' ";
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
        value =>  $self->{result_values}->{value},
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
          message_multiple => 'All volumes metrics are ok', indent_long_output => '    ',
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
        "disk-name:s@"	        => { name => 'name' },
        "filter-metric:s"   => { name => 'filter_metric' },
        "filter:s"    => { name => 'filter' },
    });

    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::check_options(%options);


    if (!defined($self->{option_results}->{name}) || $self->{option_results}->{name} eq '') {
        $self->{output}->add_option_msg(short_msg => "Need to specify --disk-name option.");
        $self->{output}->option_exit();
    }

    foreach my $volume (@{$self->{option_results}->{name}}) {
        if ($volume ne '') {
            push @{$self->{ces_volume}}, $volume;
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
    foreach my $volume (@{$self->{ces_volume}}) {
        $metric_results{$volume} = $options{custom}->api_cloudeyes_get_metric(
            namespace => 'SYS.EVS',
            dimensions => [ { name => 'disk_name', value => $volume } ],
            metrics => $self->{ces_metrics},
            filter => $self->{ces_filter},
            frame => $self->{ces_frame},
            period => $self->{ces_period},
        );
        foreach my $metric (@{$self->{ces_metrics}}) {
                 my $statistic = $self->{ces_filter};
                next if (!defined($metric_results{$volume}->{$metric}->{lc($statistic)}) &&
                    !defined($self->{option_results}->{zeroed}));

                $self->{metrics}->{$volume}->{display} = $volume;
                $self->{metrics}->{$volume}->{statistics}->{lc($statistic)}->{display} = $statistic;
                $self->{metrics}->{$volume}->{statistics}->{lc($statistic)}->{timeframe} = $self->{ces_frame};
                $self->{metrics}->{$volume}->{statistics}->{lc($statistic)}->{$metric} = 
                    defined($metric_results{$volume}->{$metric}->{lc($statistic)}) ? 
                    $metric_results{$volume}->{$metric}->{lc($statistic)} : 0;
            
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

Check EVS volumes disk IO metrics.

Example: 
perl centreon_plugins.pl --plugin=cloud::flexibleengine::evs::plugin --mode=diskio --region='eu-west-0'
--volume-id=7777ad97-95ee-4fdd-8174-c0260699246 --filter-metric='Read' --filter='sum' --disk-read-requests-rate='10'
--verbose

https://docs.prod-cloud-ocb.orange-business.com/en-us/usermanual/evs/evs_01_0044.html

Default statistic: 'average' / All statistics are valid.

=over 8

=item B<--disk-name>

Set the disk-name (Required) (Can be multiple).
It can be obtained with CloudEyes Metrics in SYS.EVS Namespace
=item B<--filter-metric>

Filter metrics (Can be: 'disk_read_bytes_rate', 'disk_write_bytes_rate',
'disk_write_requests_rate', 'disk_read_requests_rate') 
(Can be a regexp).

=item B<--warning-*> B<--critical-*>

Thresholds warning (Can be 'disk-write-bytes-rate', 'disk-write-bytes-rate',
'disk-write-request-rate', 'disk-read-requests-rate').

=back

=cut
