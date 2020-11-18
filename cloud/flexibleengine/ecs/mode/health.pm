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

package cloud::flexibleengine::ecs::mode::health;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold);

my %state_mapping =(
   '0' => 'pending',
   '1'  => 'running',
   '2' => 'paused',
   '3'  => 'shutown',
   '4' => 'crashed',

);
sub custom_calc {
    my ($self, %options) = @_;
    
    $self->{result_values}->{state} = $options{new_datas}->{$self->{instance} . '_state'};
    $self->{result_values}->{summary} = $options{new_datas}->{$self->{instance} . '_summary'};
    return 0;
}

sub custom_output {
    my ($self, %options) = @_;
    
    return sprintf("state: '%s', Summary: '%s'",
        $self->{result_values}->{state},
        $self->{result_values}->{summary}
    );
}

sub set_counters {
    my ($self, %options) = @_;
    
    $self->{maps_counters_type} = [
        { name => 'health', type => 0 },
    ];

    $self->{maps_counters}->{health} = [
        { label => 'state', threshold => 0, set => {
                key_values => [ { name => 'state' }, { name => 'summary' } ],
                closure_custom_calc => $self->can('custom_calc'),
                closure_custom_output => $self->can('custom_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold,
            }
        },
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;
    
    $options{options}->add_options(arguments => {
        "instance-id:s" => { name => 'instance_id' },
        "critical-state:s"     => { name => 'critical_state', default => '%{state} =~ /^shutdown$/' },
        "unknown-state:s"      => { name => 'unknown_state', default => '' },
        "warning-state:s"      => { name => 'warning_state', default => '' },
        "ok-state:s"           => { name => 'ok_state', default => '%{state} =~ /^running$/' },
    });
    
    return $self;
}


sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::check_options(%options);

    if (!defined($self->{option_results}->{instance_id})) {
    $self->{output}->add_option_msg(short_msg => "Need to specify --instance-id <id>.");
    $self->{output}->option_exit();
    }

        $self->change_macros(macros => ['warning_state', 'critical_state', 'unknown_state', 'ok_state']);


}




sub manage_selection {
    my ($self, %options) = @_;
    my $result = $options{custom}->api_list_ecs_detail(server_id => $self->{option_results}->{instance_id});
    $self->{health} = {
            state => $state_mapping{$result->{server}->{'OS-EXT-STS:power_state'}},
            summary => $result->{server}->{'status'},
        };
        
}

1;

__END__

=head1 MODE

Check ECS servers state.

Example: 
perl centreon_plugins.pl --plugin=cloud::flexibleengine::ecs::health --mode=health --region='eu-west-0'
--instance-id='2ae116a1-c5ed-4b4f-9d10-0bcce7f3425f'

See 'https://docs.prod-cloud-ocb.orange-business.com/api/ecs/en-us_topic_0020212690.html' for more informations.

=over 8

=item B<--instance-id>

Filter by instance id 

=item B<--warning-state>

Set warning threshold for state (Default: '').
Can used special variables like: %{state}, %{summary}
%{state} came from 'OS-EXT-STS:power_state' ECS value mapped to text.
%{summary} came from 'state' ECS.


=item B<--critical-state>

Set critical threshold for state (Default: '%{state} =~ /^crashed$/').
Can used special variables like: %{state}, %{summary}

=item B<--unknown-state>

Set unknown threshold for state (Default: '').
Can used special variables like: %{state}, %{summary}

=item B<--ok-state>

Set ok threshold for state (Default: '%{state} =~ /^running$/').
Can used special variables like: %{state}, %{summary}

=back

=cut