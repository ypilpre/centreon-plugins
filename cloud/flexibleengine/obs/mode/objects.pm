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

package cloud::flexibleengine::obs::mode::objects;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use Data::Dumper::Simple;
my %metrics_mapping = (
    'ObjectNumber' => {
        'output' => 'Objects Count',
        'label' => 'objects-count',
        'nlabel' => 'obs.objects.count',
        'unit' => ''
    }
);

sub prefix_metric_output {
    my ($self, %options) = @_;
    
    return "obs '" . $options{instance_value}->{display} . "' ";
}

sub prefix_statistics_output {
    my ($self, %options) = @_;
    
    return "Statistic '" . $options{instance_value}->{display} . "' Metrics ";
}

sub long_output {
    my ($self, %options) = @_;

    return "Checking OBS Bucket '" . $options{instance_value}->{display} . "' ";
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
          message_multiple => 'All Objects  are ok', indent_long_output => '    ',
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
                output_template => $metrics_mapping{$metric}->{output} . ': %d',
                perfdatas => [
                    { value => $metric , template => '%d', label_extra_instance => 1 }
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
        "bucket-name:s@"	        => { name => 'bucket_name' },
        "filter-metric:s"   => { name => 'filter_metric' },
        "filter:s"    => { name => 'filter' },
    });

    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::check_options(%options);


    if (!defined($self->{option_results}->{bucket_name}) || $self->{option_results}->{bucket_name} eq '') {
        $self->{output}->add_option_msg(short_msg => "Need to specify --bucket-name option.");
        $self->{output}->option_exit();
    }

    foreach my $instance (@{$self->{option_results}->{bucket_name}}) {
        if ($instance ne '') {
            push @{$self->{ces_instance}}, $instance;
        }
    }

    foreach my $metric (keys %metrics_mapping) {
        next if (defined($self->{option_results}->{filter_metric}) && $self->{option_results}->{filter_metric} ne ''
            && $metric !~ /$self->{option_results}->{filter_metric}/);

        push @{$self->{metrics}}, $metric;
    }
}

sub manage_selection {
    my ($self, %options) = @_;

    my %metric_results;
    foreach my $instance (@{$self->{ces_instance}}) {
       
        my $objects = my $versioning = $options{custom}->api_get_obs_bucket_info(bucket_name=>$instance,action=>'storageinfo');
        print Dumper($objects);
        # foreach my $metric (@{$self->{metrics}}) {
        #         next if !defined($self->{option_results}->{zeroed}));

        #         $self->{metrics}->{$instance}->{display} = $instance;
        #         $self->{metrics}->{$instance}->{statistics}->->{$metric} = 
        #             defined($metric_results{$instance}->{$metric}) ? 
        #             $metric_results{$instance}->{$metric} : 0;
            
        # }
    }
    # if (scalar(keys %{$self->{metrics}}) <= 0) {
    #     $self->{output}->add_option_msg(short_msg => 'No metrics. Check your options or use --zeroed option to set 0 on undefined values');
        $self->{output}->option_exit();
    #}
}

1;

__END__

=head1 MODE

Check OBS Buckets Object Counts.

Example: 
perl centreon_plugins.pl --plugin=cloud::flexibleengine::obs::plugin  --mode=objects --region='eu-west-0'
 --bucket-name='mybucket' --filter-metric='objects-count'
--critical-sobjects-count='10' --verbose

See 'https://docs.prod-cloud-ocb.orange-business.com/sdk-php-api/obs/en-us_topic_0142802652.html' for more informations.

=over 8

=item B<--bucket-name>

Set the bucket name (Required) (Can be multiple).

=item B<--filter-metric>

Filter metrics (Can be 'objects-count')
(Can be a regexp).

=item B<--warning-*> B<--critical-*>

Thresholds warning (Can be 'objects-count').
=back

=cut
