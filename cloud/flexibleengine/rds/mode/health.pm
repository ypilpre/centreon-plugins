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

package cloud::flexibleengine::rds::mode::health;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold);
use Data::Dumper::Simple;

sub custom_calc {
    my ($self, %options) = @_;
    
    $self->{result_values}->{state} = $options{new_datas}->{$self->{instance} . '_state'};
    return 0;
}

sub custom_output {
    my ($self, %options) = @_;
    
    return sprintf("state: '%s'",
        $self->{result_values}->{state},
    );
}

sub set_counters {
    my ($self, %options) = @_;
    
    $self->{maps_counters_type} = [
        { name => 'health', type => 0 },
    ];

    $self->{maps_counters}->{health} = [
        { label => 'state', threshold => 0, set => {
                key_values => [ { name => 'state' } ],
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
        "critical-state:s"     => { name => 'critical_state', default => '%{state} =~ /^FAILED$/' },
        "unknown-state:s"      => { name => 'unknown_state', default => '' },
        "warning-state:s"      => { name => 'warning_state', default => '' },
        "ok-state:s"           => { name => 'ok_state', default => '%{state} =~ /^ACTIVE$/' },
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
    my $result = $options{custom}->api_list_rds_detail(instance_id => $self->{option_results}->{instance_id});
    $self->{health} = {
            state => $result->{instances}[0]->{status}
    };
        
}

1;

__END__

=head1 MODE

Check RDS instance state.

Example: 
perl centreon_plugins.pl --plugin=cloud::flexibleengine::rds::health --mode=health --region='eu-west-0'
--instance-id='2ae116a1-c5ed-4b4f-9d10-0bcce7f3425f'

See 'https://docs.prod-cloud-ocb.orange-business.com/api/rds/rds_01_0004.html' for more informations.

=over 8

=item B<--instance-id>

Set the RDS instance id 

=item B<--warning-state>

Set warning threshold for state (Default: '').
Can used special variables like: %{state}


=item B<--critical-state>

Set critical threshold for state (Default: '%{state} =~ /^FAILED$/').
Can used special variables like: %{state}

=item B<--unknown-state>

Set unknown threshold for state (Default: '').
Can used special variables like: %{state}

=item B<--ok-state>

Set ok threshold for state (Default: '%{state} =~ /^ACTIVE$/').
Can used special variables like: %{state}

=back

=cut