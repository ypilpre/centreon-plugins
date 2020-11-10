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

package cloud::flexibleengine::ecs::mode::cpu;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use Data::Dumper;



sub custom_cpu_perfdata {
    my ($self, %options) = @_;

    $self->{output}->perfdata_add(
        label => $self->{result_values}->{perf_label},
        value => $self->{result_values}->{value},
        warning => $self->{perfdata}->get_perfdata_for_output(label => 'warning-cpu-utilization'),
        critical => $self->{perfdata}->get_perfdata_for_output(label => 'critical-cpu-utilization'),
        );
}

sub custom_cpu_threshold {
    my ($self, %options) = @_;

    my $exit = $self->{perfdata}->threshold_check(
        value => $self->{result_values}->{value},
        threshold => [
            { label => 'critical-cpu-utilization', exit_litteral => 'critical' },
            { label => 'warning-cpu-utilization', exit_litteral => 'warning' }
        ]
    );
    return $exit;
}


sub set_counters {
    my ($self, %options) = @_;
    
 $self->{maps_counters_type} = [
        { name => 'metrics', type => 1, message_multiple => 'All metrics are ok' },
    ];
    

        $self->{maps_counters}->{metrics} = [
        { label =>'cpu-utilization',
             nlabel => 'ecs.cpu.utilization.percentage',set => {
                key_values => [ { name => 'value' }, { name => 'perf_label' }, { name => 'display' } ],
                output_template => 'CPU Utilization. : %.2f',
                 perfdatas => [
                     { value => 'cpu_util' , template => '%.2f', label_extra_instance => 1 }
                 ],
                closure_custom_threshold_check => $self->can('custom_cpu_threshold'),
                closure_custom_perfdata => $self->can('custom_cpu_perfdata'),


            }
        }
    ];    
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;
    
    $options{options}->add_options(arguments => {
        "instance-id:s"	        => { name => 'instance_id' },
        "filter:s"   => { name => 'filter' },
    });
    
    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::check_options(%options);

    if (!defined($self->{option_results}->{instance_id}) || $self->{option_results}->{instance_id} eq '') {
        $self->{output}->add_option_msg(short_msg => "Need to specify --instance_id option.");
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
        namespace => "SYS.ECS",
        dimension => "instance_id,$self->{option_results}->{instance_id}",
        metric => 'cpu_util',
        filter => $self->{option_results}->{filter},
        period => $self->{ces_period},
        frame => $self->{ces_frame},
    );
    $self->{metrics} = {};
    foreach my $label (keys %{$metric_results}) {
        foreach my $stat (('min', 'max', 'average', 'sum','variance')) {
            next if (!defined($metric_results->{$label}->{$stat}));
             $self->{metrics}->  {$label . '_' . $stat} = {
                display =>    $label . '_' . $stat,
                value => $metric_results->{$label}->{$stat},
                perf_label => $label . '_' . $stat,
            };
        }
    }
}

1;

__END__

=head1 MODE

Check ECS instances CPU metrics.

Example: 
perl centreon_plugins.pl --plugin=cloud::aws::ecs::plugin  --mode=cpu --region='eu-west-0'
--type='ecs' --instance_id='30191908-bf15-44e8-bf5c-ffa121bbd4ea' --filter=average
--critical-cpu-usage=80 --verbose

Default statistic: 'average' / All satistics are valid.

=over 8

=item B<--instance_id>

Set the instance id (Required).

=item B<--warning-*> B<--critical-*>

Thresholds warning & critical.
Valid input is cpu-utilization

=back

=cut
