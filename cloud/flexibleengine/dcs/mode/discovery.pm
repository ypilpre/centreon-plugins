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

package cloud::flexibleengine::dcs::mode::discovery;

use base qw(centreon::plugins::mode);

use strict;
use warnings;
use JSON::XS;


sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;
    
    $options{options}->add_options(arguments => {
        "prettify"      => { name => 'prettify' },
    });
    
    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::init(%options);
}

sub run {
    my ($self, %options) = @_;

    my @disco_data;
    my $disco_stats;

    $disco_stats->{start_time} = time();

    my $distributed_caches = $options{custom}->api_list_dcs();
    foreach my $distributed_cache (@{$distributed_caches->{instances}}) {
        next if (!defined($distributed_cache->{instance_id}));
        my $distributed_cache_detail = $options{custom}->api_list_dcs_detail(instance_id=>$distributed_cache->{instance_id});
        my %dcs;
        $dcs{type} = "dcs";
        $dcs{engine} = $distributed_cache->{engine};
        $dcs{id} = $distributed_cache->{instance_id};
        $dcs{name} = $distributed_cache->{name};
        $dcs{version} = $distributed_cache->{engine_version};
        $dcs{status} = $distributed_cache->{status};
        $dcs{mode} = $distributed_cache_detail->{cache_mode};
        $dcs{storage_type} = $distributed_cache_detail->{storage_type};
        $dcs{availabilty_zone} = $distributed_cache_detail->{available_zones};
        $dcs{spec} = $distributed_cache_detail->{spec_code};

        push @disco_data, \%dcs;
    }

    $disco_stats->{end_time} = time();
    $disco_stats->{duration} = $disco_stats->{end_time} - $disco_stats->{start_time};
    $disco_stats->{discovered_items} = @disco_data;
    $disco_stats->{results} = \@disco_data;

    my $encoded_data;
    eval {
        if (defined($self->{option_results}->{prettify})) {
            $encoded_data = JSON::XS->new->utf8->pretty->encode($disco_stats);
        } else {
            $encoded_data = JSON::XS->new->utf8->encode($disco_stats);
        }
    };
    if ($@) {
        $encoded_data = '{"code":"encode_error","message":"Cannot encode discovered data into JSON format"}';
    }
    
    $self->{output}->output_add(short_msg => $encoded_data);
    $self->{output}->display(nolabel => 1, force_ignore_perfdata => 1);
    $self->{output}->exit();
}

1;

__END__

=head1 MODE

dcs discovery.

=over 8

=item B<--prettify>

Prettify JSON output.

=back

=cut
