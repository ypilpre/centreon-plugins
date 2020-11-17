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

package cloud::flexibleengine::ecs::mode::instancesflavors;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;

my %family_mapping = (
    'general' => {
        'prefix_output' => 'prefix_general_output',
        'flavors' => [
            't2.micro', 't2.small', 't2.large.2', 't2.xlarge.2', 't2.2xlarge.2', 
            's3.small.1', 's3.medium.2', 's3.medium.4', 's3.large.2', 's3.xlarge.2', 
            's3.2xlarge.2', 's3.4xlarge.2', 's3.8xlarge.2', 's3.large.4', 's3.xlarge.4', 
            's3.2xlarge.4', 's3.4xlarge.4', 's1.medium', 's1.large', 's1.xlarge', 
            's1.2xlarge', 's1.4xlarge', 's1.8xlarge', 'c1.large', 'c1.xlarge', 
            'c1.2xlarge', 'c1.4xlarge'
        ],
    },
    'compute' => {
        'prefix_output' => 'prefix_compute_output',
        'flavors' => [
            'c2.large', 'c2.xlarge', 'c2.2xlarge'
        ],
    },
    'memory' => {
        'prefix_output' => 'prefix_memory_output',
        'flavors' => [
            'm1.large', 'm1.xlarge', 'm1.2xlarge', 
            'm1.4xlarge', 'm2.large.8', 'm2.xlarge.8',
            'm2.2xlarge.8', 'm2.4xlarge.8', 'm2.8xlarge.8'
        ],
    },
    'dedicated' => {
        'prefix_output' => 'prefix_dedicated_general_output',
        'flavors' => [
            'cc3.large.4', 'cc3.xlarge.4', 'cc3.2xlarge.4', 'cc3.4xlarge.4', 
            'cc3.8xlarge.4', 'cc3.18xlarge.4', 'cc3.19xlarge.4', 'c3.large.2', 
            'c3.xlarge.2', 'c3.2xlarge.2', 'c3.4xlarge.2', 'c3.8xlarge.2',
            'c3.15xlarge.2', 
        ],
    },
    'performance' => {
        'prefix_output' => 'prefix_performance_output',
        'flavors' => [
            'h1.large.2', 'h1.xlarge.2', 'h1.2xlarge.2', 
            'h1.4xlarge.2', 'h1.8xlarge.2', 'h1.large.4', 'h1.xlarge.4',
            'h1.2xlarge.4', 'h1.4xlarge.4', 'h1.8xlarge.4'
        ],
    },
    'diskintensive' => {
        'prefix_output' => 'prefix_diskinstensive_output',
        'flavors' => [
            'd1.xlarge', 'd1.2xlarge', 'd1.4xlarge', 'd1.8xlarge', 
            'd2.xlarge.8', 'd2.2xlarge.8', 'd2.4xlarge.8', 'd2.6xlarge.8', 
            'd2.8xlarge.8', 'd2.12xlarge.8', 'd3.xlarge.8', 'd3.2xlarge.8',
            'd3.4xlarge.8', 'd3.6xlarge.8', 'd3.8xlarge.8', 'd3.12xlarge.8', 
            'd3.14xlarge.10'
        ],
    },
    'storage' => {
        'prefix_output' => 'prefix_storage_output',
        'flavors' => [
            'i3.2xlarge.8', 'i3.4xlarge.8', 'i3.8xlarge.8', 'i3.12xlarge.8', 'i3.15xlarge.8'
        ],
    },
    'accelerated' => {
        'prefix_output' => 'prefix_accelerated_output',
        'flavors' => [
            'g1.xlarge', 'g1.2xlarge', 'g1.4xlarge', 'g2.2xlarge ', 
            'p2.2xlarge.8', 'p2.4xlarge.8', 'p2.8xlarge.8', 
            'p2s.2xlarge.8', 'p2s.4xlarge.8', 'p2s.8xlarge.8', 
            'p2s.16xlarge.8'
        ],
    },
);

sub prefix_general_output {
    my ($self, %options) = @_;

    return "'General purpose' instances count ";
}

sub prefix_compute_output {
    my ($self, %options) = @_;

    return "'Compute optimized' instances count ";
}

sub prefix_storage_output {
    my ($self, %options) = @_;

    return "'Storage optimized' instances count ";
}

sub prefix_dedicated_output {
    my ($self, %options) = @_;

    return "'Dedicated General Purpose' instances count ";
}

sub prefix_diskintensive_output {
    my ($self, %options) = @_;

    return "'Disk intensive' instances count ";
}


sub prefix_performance_output {
    my ($self, %options) = @_;

    return "'High Performance' instances count ";
}

sub prefix_accelerated_output {
    my ($self, %options) = @_;

    return "'Accelerated computing' instances count ";
}

sub set_counters {
    my ($self, %options) = @_;

    foreach my $family (keys %family_mapping) {
        my $counter = { 
            name => $family,
            type => 0,
            cb_prefix_output => $family_mapping{$family}->{prefix_output},
            skipped_code => { -10 => 1 } };
        
        push @{$self->{maps_counters_type}}, $counter;

        $self->{maps_counters}->{$family} = [];
        
        foreach my $flavor (@{$family_mapping{$family}->{flavors}}) {
            my $entry = {
                label => $flavor, nlabel => 'ecs.instances.flavor.' . $family . '.' . $flavor . '.count', set => {
                    key_values => [ { name => $flavor }  ],
                    output_template => $flavor . ": %s",
                    perfdatas => [
                        { value => $flavor , template => '%d', min => 0 },
                    ],
                }
            };

            push @{$self->{maps_counters}->{$family}}, $entry;
        }
    }
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments =>  {
        "filter-family:s"   => { name => 'filter_family' },
        "filter-flavor:s"     => { name => 'filter_flavor' },
        "running"           => { name => 'running' }
    });

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;
    
    foreach my $family (keys %family_mapping) {
        if (defined($self->{option_results}->{filter_family}) && $self->{option_results}->{filter_family} ne '' &&
            $family !~ /$self->{option_results}->{filter_family}/) {
            $self->{output}->output_add(long_msg => sprintf("skipping family '%s'", $family), debug => 1);
            $self->{maps_counters}->{$family} = undef;
        } else {
            foreach my $type (@{$family_mapping{$family}->{flavors}}) {
                if (defined($self->{option_results}->{filter_flavor}) && $self->{option_results}->{filter_flavor} ne '' &&
                    $type !~ /$self->{option_results}->{filter_flavor}/) {
                    next;
                }
                $self->{$family}->{$type} = 0;
            }
        }
    }
    
    my $result = $options{custom}->api_list_ecs();
    foreach my $instance (@{$result->{servers}}) {        
        next if ((defined($self->{option_results}->{running}) && $instance->{status} !~ /ACTIVE/));
        if (defined($self->{option_results}->{filter_flavor}) && $self->{option_results}->{filter_flavor} ne '' &&
            $instance->{flavor}->{id} !~ /$self->{option_results}->{filter_flavor}/) {
            $self->{output}->output_add(long_msg => sprintf("skipping type '%s'", $instance->{flavor}->{id}), debug => 1);
            next;
        }
        foreach my $family (keys %family_mapping) {
            $self->{$family}->{$instance->{flavor}->{id}}++ if (defined($self->{maps_counters}->{$family}) && map(/$instance->{flavor}->{id}/, @{$family_mapping{$family}->{flavors}}));
        }
    }

    if (scalar(keys %{$self->{general}}) <= 0 && scalar(keys %{$self->{performance}}) <= 0  && scalar(keys %{$self->{compute}}) <= 0 && scalar(keys %{$self->{memory}}) <= 0 &&
        scalar(keys %{$self->{storage}}) <= 0 && scalar(keys %{$self->{diskintensive}}) <= 0 && scalar(keys %{$self->{dedicated}}) <= 0 && scalar(keys %{$self->{accelerated}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No result matched with applied filters.");
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check ECS instances Flavors count.

Example: 
perl centreon_plugins.pl --plugin=cloud::flexibleengine::ecs::plugin --mode=instances-flavors --region='eu-west-0'
--filter-family='general' --filter-type='medium' --critical-t2.medium='10' --verbose

See 'https://docs.prod-cloud-ocb.orange-business.com/usermanual/ecs/en-us_topic_0132345719.html' for more informations.

=over 8

=item B<--filter-family>

Filter by instance family (regexp)
(Can be: 'general', 'compute', 'memory', 'dedicated', 'performance', 'diskintensive', 'storage', 'accelerated')

=item B<--filter-flavor>

Filter by instance flavor (regexp)

=item B<--warning-*> B<--critical-*>

Threshold warning.
Can be: 't2.micro', 't2.small', 't2.large.2', 't2.xlarge.2', 't2.2xlarge.2', 
's3.small.1', 's3.medium.2', 's3.medium.4', 's3.large.2', 's3.xlarge.2', 
's3.2xlarge.2', 's3.4xlarge.2', 's3.8xlarge.2', 's3.large.4', 's3.xlarge.4', 
's3.2xlarge.4', 's3.4xlarge.4', 's1.medium', 's1.large', 's1.xlarge', 
's1.2xlarge', 's1.4xlarge', 's1.8xlarge', 'c1.large', 'c1.xlarge', 
'c1.2xlarge', 'c1.4xlarge', 'c2.large', 'c2.xlarge', 'c2.2xlarge',
'cc3.large.4', 'cc3.xlarge.4', 'cc3.2xlarge.4', 'cc3.4xlarge.4', 
'cc3.8xlarge.4', 'cc3.18xlarge.4', 'cc3.19xlarge.4', 'c3.large.2', 
'c3.xlarge.2', 'c3.2xlarge.2', 'c3.4xlarge.2', 'c3.8xlarge.2',
'c3.15xlarge.2', 'h1.large.2', 'h1.xlarge.2', 'h1.2xlarge.2', 
'h1.4xlarge.2', 'h1.8xlarge.2', 'h1.large.4', 'h1.xlarge.4',
'h1.2xlarge.4', 'h1.4xlarge.4', 'h1.8xlarge.4''d1.xlarge',
'd1.2xlarge', 'd1.4xlarge', 'd1.8xlarge', 
'd2.xlarge.8', 'd2.2xlarge.8', 'd2.4xlarge.8', 'd2.6xlarge.8', 
'd2.8xlarge.8', 'd2.12xlarge.8', 'd3.xlarge.8', 'd3.2xlarge.8',
'd3.4xlarge.8', 'd3.6xlarge.8', 'd3.8xlarge.8', 'd3.12xlarge.8', 
'd3.14xlarge.10', 'i3.2xlarge.8', 'i3.4xlarge.8', 'i3.8xlarge.8',
'i3.12xlarge.8', 'i3.15xlarge.8',  'g1.xlarge', 'g1.2xlarge',
'g1.4xlarge', 'g2.2xlarge ', 'p2.2xlarge.8', 'p2.4xlarge.8', 'p2.8xlarge.8', 
'p2s.2xlarge.8', 'p2s.4xlarge.8', 'p2s.8xlarge.8', 'p2s.16xlarge.8'

=item B<--running>

Only check running instances.

=back

=cut
