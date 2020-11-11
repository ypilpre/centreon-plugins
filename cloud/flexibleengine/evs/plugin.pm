#
# Copyright 2018 Centreon (http://www.centreon.com/)
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

package cloud::flexibleengine::evs::plugin;

use strict;
use warnings;
use base qw(centreon::plugins::script_custom);

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;

    $self->{version} = '1.0';
    %{$self->{modes}} = (
        'list-volume'   => 'cloud::flexibleengine::ecs::mode::listvolume',
        'status' => 'cloud::flexibleengine::evs::mode::status',
        'discovery'      => 'cloud::flexibleengine::evs::mode::discovery',
        'diskio'         => 'cloud::flexibleengine::evs::mode::diskio',
            );
    $self->{custom_modes}{api} = 'cloud::flexibleengine::custom::api';
    return $self;
}

1;


=head1 PLUGIN DESCRIPTION

Check Flexible Engine EVS Resources.

=cut