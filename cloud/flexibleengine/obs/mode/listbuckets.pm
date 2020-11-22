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

package cloud::flexibleengine::obs::mode::listbuckets;

use base qw(centreon::plugins::mode);


use strict;
use warnings;
use XML::Simple;

my %storage_map = (
  'STANDARD' => {'label' => 'Standard'},
  'STANDARD_IA' => {'label' => 'Warm'},
  'GLACIER' => {'label' => 'Cold'},
);
 
sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;
    
    $options{options}->add_options(arguments => {});

    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::init(%options);
}

sub manage_selection {
    my ($self, %options) = @_;
    $self->{buckets_list} = $options{custom}->api_list_obs_buckets();
    foreach  (@{$self->{buckets_list}->{Buckets}->{Bucket}}) {
    (my $storage_class, my $storage_region) = $options{custom}->api_obs_bucket_head(bucket_name=>$_->{Name});
    my $versioning = $options{custom}->api_get_obs_bucket_info(bucket_name=>$_->{Name},action=>'versioning');

        push @{$self->{buckets}} , 
        {name=>$_->{Name},
        storage_class=>$storage_map{$storage_class}->{label},
        storage_region=>$storage_region,
        versioning=>(defined($versioning->{Status}))?$versioning->{Status}:"Disabled",

        }; 
        }
}


sub run {
    my ($self, %options) = @_;

    $self->manage_selection(%options);
    foreach  (@{$self->{buckets}}) {
        $self->{output}->output_add(
            long_msg => sprintf("[name= %s][class= %s][versioning= %s][region= %s]",
         $_->{name},
         $_->{storage_class},
         $_->{versioning},
        $_->{storage_region},

         ));
    }
    $self->{output}->output_add(severity => 'OK',
                                short_msg => 'List buckets:');
    $self->{output}->display(nolabel => 1, force_ignore_perfdata => 1, force_long_output => 1);
    $self->{output}->exit();
}

sub disco_format {
    my ($self, %options) = @_;

    $self->{output}->add_disco_format(elements => ['name', 'storage_class','versioning','region']);
}

sub disco_show {
    my ($self, %options) = @_;

    $self->manage_selection(%options);
    foreach  (@{$self->{buckets}}) {
        $self->{output}->add_disco_entry(
        name => $_->{name},
        class => $_->{storage_class},
        region => $_->{storage_region},
        versioning => $_->{versioning},

        );
    }
}

1;

__END__

=head1 MODE

List OBS Buckets.

=over 8

=back

=cut