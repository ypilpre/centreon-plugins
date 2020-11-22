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

package cloud::flexibleengine::dds::plugin;

use strict;
use warnings;
use base qw(centreon::plugins::script_custom);

sub new {
    my ( $class, %options ) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;

    $self->{version} = '0.1';
    $self->{modes} = {
        'cpu'             => 'cloud::flexibleengine::dds::mode::cpu',
        'memory'          => 'cloud::flexibleengine::dds::mode::memory',
        'discovery'       => 'cloud::flexibleengine::dds::mode::discovery',
        'diskio'          => 'cloud::flexibleengine::dds::mode::diskio',
        'instance-status' => 'cloud::flexibleengine::dds::mode::instancestatus',
        'list-nodes'      => 'cloud::flexibleengine::dds::mode::listnodes',
        'list-instances'  => 'cloud::flexibleengine::dds::mode::listinstances',
        'network'         => 'cloud::flexibleengine::dds::mode::network',
        'health'         => 'cloud::flexibleengine::dds::mode::health',
        'storage'         => 'cloud::flexibleengine::dds::mode::storage',
        'iops'    => 'cloud::flexibleengine::dds::mode::iops',
    };

    $self->{custom_modes}{token} = 'cloud::flexibleengine::custom::token';
    $self->{custom_modes}{aksk} = 'cloud::flexibleengine::custom::aksk';
    return $self;
}

1;

__END__

=head1 PLUGIN DESCRIPTION

Check Flexible Engine Document Database Service (DDS).

=cut
